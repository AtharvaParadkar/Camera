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

  Future<void> _initializeCamera() async {
    final granted = await _requestPermission();
    if (!granted) return;
    try {
      // 🔥 Dispose previous controller if any
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }

      _controller = CameraController(
        camera.last,
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
      await Future.wait(<Future<Object?>>[
        /// Camera tells how far can you zoom
        _controller!.getMaxZoomLevel().then(
          (double onValue) => _maxAvailableZoom = onValue,
        ),
        _controller!.getMinZoomLevel().then(
          (onValue) => _minAvailableZoom = onValue,
        ),
      ]);
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
            Container(height: 50, color: Colors.lightBlueAccent),
            Expanded(child: cameraPreviewWidget()),
            Container(height: 50, color: Colors.yellowAccent),
            Container(height: 100, color: Colors.pink),
          ],
        ),
      ),
    );
  }

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
                  onScaleStart: _handleScaleStart,    // Fingers placed
                  onScaleUpdate: _handleScaleUpdate,  // Fingers moved
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
}
