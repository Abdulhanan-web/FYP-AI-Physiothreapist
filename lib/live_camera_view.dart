import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class LiveCameraView extends StatefulWidget {
  final CameraDescription camera;
  const LiveCameraView({super.key, required this.camera});

  @override
  State<LiveCameraView> createState() => _LiveCameraViewState();
}

class _LiveCameraViewState extends State<LiveCameraView> {
  CameraController? controller;
  late PoseDetector poseDetector;
  bool isBusy = false;
  List<Pose> poses = [];

  @override
  void initState() {
    super.initState();
    poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.accurate,
        mode: PoseDetectionMode.stream,
      ),
    );
    initCamera();
  }

  Future<void> initCamera() async {
    controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup:
      Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    await controller!.initialize();
    controller!.startImageStream(processCameraImage);
    if (mounted) setState(() {});
  }

  Future<void> processCameraImage(CameraImage image) async {
    if (isBusy) return;
    isBusy = true;

    try {
      final inputImage = InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotationValue.fromRawValue(
              widget.camera.sensorOrientation) ??
              InputImageRotation.rotation0deg,
          format:
          Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      poses = await poseDetector.processImage(inputImage);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Pose detection error: $e");
    }

    isBusy = false;
  }

  @override
  void dispose() {
    controller?.dispose();
    poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fullscreen camera preview
          SizedBox.expand(
            child: CameraPreview(controller!),
          ),
          // Fullscreen pose overlay
          SizedBox.expand(
            child: CustomPaint(
              painter: LivePosePainter(
                poses,
                controller!.value.previewSize!,
                controller!.description.lensDirection,
              ),
            ),
          ),
          // Back button
          Positioned(
            top: 40,
            left: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.black,
              onPressed: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class LivePosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size previewSize;
  final CameraLensDirection lensDirection;

  LivePosePainter(this.poses, this.previewSize, this.lensDirection);

  @override
  void paint(Canvas canvas, Size size) {
    // MLKit gives portrait coordinates (height > width)
    final double imageW = previewSize.height;  // 720
    final double imageH = previewSize.width;   // 1280

    // Scaling
    double scaleW = size.width / imageW;
    double scaleH = size.height / imageH;
    double scale = math.min(scaleW, scaleH);

    // Centering
    double offsetX = (size.width  - imageW * scale) / 2;
    double offsetY = (size.height - imageH * scale) / 2;

    Paint pointPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill
      ..strokeWidth = 4;

    Paint linePaint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 3;

    for (Pose pose in poses) {
      pose.landmarks.forEach((_, lm) {
        // Use pixel values directly
        double x = lm.x * scale + offsetX;
        double y = lm.y * scale + offsetY;

        // Mirror for selfie camera
        if (lensDirection == CameraLensDirection.front) {
          x = size.width - x;
        }

        canvas.drawCircle(Offset(x, y), 5, pointPaint);
      });

      void draw(PoseLandmarkType a, PoseLandmarkType b) {
        final p1 = pose.landmarks[a];
        final p2 = pose.landmarks[b];
        if (p1 == null || p2 == null) return;

        double x1 = p1.x * scale + offsetX;
        double y1 = p1.y * scale + offsetY;

        double x2 = p2.x * scale + offsetX;
        double y2 = p2.y * scale + offsetY;

        if (lensDirection == CameraLensDirection.front) {
          x1 = size.width - x1;
          x2 = size.width - x2;
        }

        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);
      }

      draw(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
      draw(PoseLandmarkType.leftElbow, PoseLandmarkType.leftShoulder);
      draw(PoseLandmarkType.rightElbow, PoseLandmarkType.rightShoulder);
      draw(PoseLandmarkType.leftWrist, PoseLandmarkType.leftElbow);
      draw(PoseLandmarkType.rightWrist, PoseLandmarkType.rightElbow);

      draw(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
      draw(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
      draw(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

      draw(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
      draw(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
      draw(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
      draw(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
