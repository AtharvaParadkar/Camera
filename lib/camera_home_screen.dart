import 'dart:developer';

import 'package:camera/camera.dart';
import 'package:camera_app/main.dart';
import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraHomeScreen extends StatefulWidget {
  const CameraHomeScreen({super.key});

  @override
  State<CameraHomeScreen> createState() => _CameraHomeScreenState();
}

class _CameraHomeScreenState extends State<CameraHomeScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;

  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentScale = 1.0;
  double _baseScale = 1.0;

  // Counting pointers(number of user fingers on screen)
  int _pointers = 0;

  late List<CameraDescription> _cameras;
  CameraDescription? _currentCamera;

  final List<String> _cameraModes = [
    'NIGHT',
    'VIDEO',
    'PHOTO',
    'PORTRAIT',
    'MORE',
  ];

  @override
  void initState() {
    super.initState();

    /// Add observer to recheck teh permission given
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  Future<void> _onAppResumed() async {
    final status = await Permission.camera.status;

    if (status.isGranted &&
        (_controller == null || !_controller!.value.isInitialized)) {
      _initializeCamera();
    }
  }

  Future<bool> _requestPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;

    final result = await Permission.camera.request();
    if (result.isGranted) {
      return true;
    }
    if (result.isDenied || result.isLimited || result.isPermanentlyDenied) {
      return false;
    } else {
      showToast("Camera Permission Denied");
    }
    return false;
  }

  Future<void> _initializeCamera({CameraDescription? camera}) async {
    final granted = await _requestPermission();
    if (!granted) return;
    try {
      _cameras = cameraList;
      _currentCamera ??= camera ?? _cameras.first;

      // 🔥 Dispose previous controller if any
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }

      _controller = CameraController(
        _currentCamera!,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      // If the controller is updated then update the UI.
      _controller!.addListener(() {
        if (!mounted) return;

        if (_controller!.value.hasError) {
          showToast('Camera error ${_controller!.value.errorDescription}');
        }
      });

      await _controller!.initialize();

      _minAvailableZoom = await _controller!.getMinZoomLevel();
      _maxAvailableZoom = await _controller!.getMaxZoomLevel();
      _currentScale = 1.0;

      if (mounted) setState(() {});
    } on CameraException catch (c) {
      switch (c.code) {
        case 'CameraAccessDenied':
          showToast('You have denied camera access.');
          break;
        case 'CameraAccessDeniedWithoutPrompt':
          // iOS only
          showToast('Please go to Settings app to enable camera access.');
          break;
        case 'CameraAccessRestricted':
          // iOS only
          showToast('Camera access is restricted.');
          break;
        case 'AudioAccessDenied':
          showToast('You have denied audio access.');
          break;
        case 'AudioAccessDeniedWithoutPrompt':
          // iOS only
          showToast('Please go to Settings app to enable audio access.');
          break;
        case 'AudioAccessRestricted':
          // iOS only
          showToast('Audio access is restricted.');
          break;
        default:
          log("Error on getting available cameras ${c.code}, ${c.description}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Color(0xff000000),
        body: Column(
          children: [
            Container(height: 50, color: Colors.black),
            Expanded(child: cameraPreviewWidget()),
            cameraModesRow(),
            imgCapturePreviewCamSwitchRow(),
          ],
        ),
      ),
    );
  }

  /// ================================  CAMERA PREVIEW ================================
  Widget cameraPreviewWidget() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Center(
        child: GestureDetector(
          onTap: () async {
            final status = await Permission.camera.status;
            if (!status.isGranted) {
              await openAppSettings();
            }
          },
          child: Text(
            "Camera permission denied! \n Click to give permission",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    } else {
      return AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: Listener(
          onPointerDown: (_) => _pointers++,
          onPointerUp: (_) => _pointers--,
          child: CameraPreview(
            _controller!,
            child: LayoutBuilder(
              builder: (BuildContext ctx, BoxConstraints cons) {
                return GestureDetector(
                  behavior: .opaque,
                  onScaleStart: _handleScaleStart, // Fingers placed
                  onScaleUpdate: _handleScaleUpdate, // Fingers moved
                );
              },
            ),
          ),
        ),
      );
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    // When pinch starts: store base zoom
    _baseScale = _currentScale;
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    // When there are not exactly 2 fingers on the screen don't scale ie zoom
    if (_controller == null || _pointers != 2) {
      return;
    }
    // When fingers move: calculate zoom
    _currentScale = (_baseScale * details.scale).clamp(
      _minAvailableZoom,
      _maxAvailableZoom,
    );
    await _controller!.setZoomLevel(_currentScale);
  }

  /// ================================ CAMERA MODES ================================
  Widget cameraModesRow() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        itemCount: _cameraModes.length,
        scrollDirection: .horizontal,
        itemBuilder: (BuildContext ctx, i) {
          return Padding(
            padding: .symmetric(horizontal: 20, vertical: 15),
            child: Text(
              _cameraModes[i],
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: .w600,
              ),
              textAlign: .center,
            ),
          );
        },
      ),
    );
  }

  /// ================================ IMAGE CAPTURE, PREVIEW & CAMERA SWITCH ================================
  Widget imgCapturePreviewCamSwitchRow() {
    return SizedBox(
      height: 130,
      child: Row(
        mainAxisAlignment: .spaceEvenly,
        children: [
          Padding(
            padding: .symmetric(horizontal: 25, vertical: 20),
            child: SizedBox(height: 30, width: 40),
          ),
          Padding(
            padding: .symmetric(horizontal: 25, vertical: 20),
            child: Image.asset(
              "assets/images/camera_shutter.png",
              height: 70,
              width: 70,
            ),
          ),
          Padding(
            padding: .symmetric(horizontal: 25, vertical: 20),
            child: InkWell(
              onTap: _switchCamera,
              child: Container(
                decoration: BoxDecoration(
                  color: Color(0x70959595),
                  shape: BoxShape.circle,
                ),
                padding: .all(3),
                child: Image.asset(
                  "assets/images/camera_switch.png",
                  height: 40,
                  width: 40,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) {
      showToast("No secondary camera available");
      return;
    }

    final isBackCam = _currentCamera!.lensDirection == CameraLensDirection.back;

    _currentCamera = _cameras.firstWhere(
      (cam) =>
          cam.lensDirection ==
          (isBackCam ? CameraLensDirection.front : CameraLensDirection.back),
    );

    await _initializeCamera(camera: _currentCamera);
  }
}
