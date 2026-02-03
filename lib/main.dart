import 'dart:developer';

import 'package:camera/camera.dart';
import 'package:camera_app/camera_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';

/// _camera stores all the cameras
/// Use of getter: Prevents accidental reassignment
/// Central source of truth
/// Common Flutter camera pattern
List<CameraDescription> get cameraList => _cameraList;
List<CameraDescription> _cameraList = <CameraDescription>[];

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    _cameraList = await availableCameras();
    log("Camera $_cameraList");
  } on CameraException catch (c) {
    log("Error on getting available cameras ${c.code}, ${c.description}");
  }
  runApp(CameraApp());
}

class CameraApp extends StatelessWidget {
  const CameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return OKToast(
      duration: const Duration(seconds: 3),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: CameraHomeScreen(),
      ),
    );
  }
}
