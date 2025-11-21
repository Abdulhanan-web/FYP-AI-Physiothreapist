import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:math' as math;

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
    await controller!.startImageStream(processCameraImage);

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
          rotation: InputImageRotationValue.fromRawValue(widget.camera.sensorOrientation) ??
              InputImageRotation.rotation0deg,
          format: Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888,
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

    // Camera aspect ratio (width/height)
    final cameraAspectRatio =
        controller!.value.previewSize!.height / controller!.value.previewSize!.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AspectRatio(
          aspectRatio: cameraAspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(controller!),
              CustomPaint(
                painter: LivePosePainter(
                  poses,
                  controller!.value.previewSize!,
                  controller!.description.lensDirection,
                ),
              ),
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
        ),
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
    // ML Kit coordinates are always portrait
    double imageWidth = previewSize.height.toDouble();
    double imageHeight = previewSize.width.toDouble();

    // Scale to fit AspectRatio container without distortion
    double scale = math.min(size.width / imageWidth, size.height / imageHeight);
    double offsetX = (size.width - imageWidth * scale) / 2;
    double offsetY = (size.height - imageHeight * scale) / 2;

    Paint pointPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    Paint linePaint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 3;

    for (Pose pose in poses) {
      // Draw landmarks
      pose.landmarks.forEach((_, lm) {
        double x = lm.x * scale + offsetX;
        double y = lm.y * scale + offsetY;

        if (lensDirection == CameraLensDirection.front) {
          x = size.width - x; // mirror front camera
        }

        canvas.drawCircle(Offset(x, y), 5, pointPaint);
      });

      // Draw skeleton connections
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
