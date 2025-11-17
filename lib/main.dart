import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'live_camera_view.dart';
import 'package:camera/camera.dart'; // Ensure this is present

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras(); // Fetch cameras before app starts
  runApp(const MaterialApp(home: MyHomePage()));
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _image;
  late ImagePicker imagePicker;
  late PoseDetector poseDetector;
  List<Pose> poses = [];
  dynamic image;

  @override
  void initState() {
    super.initState();
    imagePicker = ImagePicker();
    final options = PoseDetectorOptions(
      model: PoseDetectionModel.accurate,
      mode: PoseDetectionMode.single,
    );
    poseDetector = PoseDetector(options: options);
  }

  @override
  void dispose() {
    poseDetector.close();
    super.dispose();
  }

  Future<void> pickFromGallery() async {
    XFile? pickedFile = await imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
      doPoseDetection();
    }
  }

  Future<void> pickFromCamera() async {
    XFile? pickedFile = await imagePicker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
      doPoseDetection();
    }
  }

  Future<void> doPoseDetection() async {
    await loadImage();
    final inputImage = InputImage.fromFile(_image!);
    final detectedPoses = await poseDetector.processImage(inputImage);
    setState(() => poses = detectedPoses);
  }

  Future<void> loadImage() async {
    final bytes = await _image!.readAsBytes();
    final decoded = await decodeImageFromList(bytes);
    setState(() => image = decoded);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Pose Detection", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            onPressed: () {
              // Ensure there is a camera available before pushing
              if (cameras.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LiveCameraView(camera: cameras[0]),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No cameras available')),
                );
              }
            },
            icon: const Icon(Icons.videocam, color: Colors.white),
          )
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 50),
            child: image != null
                ? Center(
              child: FittedBox(
                child: SizedBox(
                  width: image.width.toDouble(),
                  height: image.height.toDouble(),
                  child: CustomPaint(
                    painter: PosePainter(image, poses),
                  ),
                ),
              ),
            )
                : const Icon(Icons.image, size: 250, color: Colors.white),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                bottomButton(Icons.image, pickFromGallery),
                bottomButton(Icons.camera_alt, pickFromCamera),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget bottomButton(IconData icon, Function() onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Icon(icon, size: 30, color: Colors.black),
      ),
    );
  }
}

class PosePainter extends CustomPainter {
  final dynamic image;
  final List<Pose> poses;

  PosePainter(this.image, this.poses);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(image, Offset.zero, Paint());

    Paint pointPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    Paint linePaint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 4;

    for (Pose pose in poses) {
      pose.landmarks.forEach((_, lm) {
        canvas.drawCircle(Offset(lm.x, lm.y), 4, pointPaint);
      });

      void draw(PoseLandmarkType a, PoseLandmarkType b) {
        final p1 = pose.landmarks[a];
        final p2 = pose.landmarks[b];
        if (p1 == null || p2 == null) return;
        canvas.drawLine(Offset(p1.x, p1.y), Offset(p2.x, p2.y), linePaint);
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