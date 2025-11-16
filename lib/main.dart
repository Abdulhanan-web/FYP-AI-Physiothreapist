import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyHomePage());
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
  var image;
  List<Pose> poses = [];

  @override
  void initState() {
    super.initState();
    imagePicker = ImagePicker();
    final options = PoseDetectorOptions(model: PoseDetectionModel.accurate, mode: PoseDetectionMode.single);
    poseDetector = PoseDetector(options: options);
  }

  @override
  void dispose() {
    super.dispose();
  }

  _imgFromGallery() async {
    XFile? pickedFile = await imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      doPoseDetection();
    }
  }

  _imgFromCamera() async {
    XFile? pickedFile = await imagePicker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      doPoseDetection();
    }
  }

  doPoseDetection() async {
    drawPose();
    InputImage inputImage = InputImage.fromFile(_image!);
    poses = await poseDetector.processImage(inputImage);
    setState(() {
      poses;
    });
    for (Pose pose in poses) {
      // to access all landmarks
      pose.landmarks.forEach((_, landmark) {
        final type = landmark.type;
        final x = landmark.x;
        final y = landmark.y;
        print("Landmarks: ${landmark.type.name} ${landmark.x} ${landmark.y}");
      });

      // to access specific landmarks
      final landmark = pose.landmarks[PoseLandmarkType.nose];
    }
  }

  drawPose() async {
    var bytes = await _image!.readAsBytes();
    image = await decodeImageFromList(bytes);
    setState(() {
      image;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 100),
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
                      // Image.file(
                      //   _image!,
                      //   height: MediaQuery.of(context).size.height - 300,
                      // ),
                    )
                  : SizedBox(
                      height: MediaQuery.of(context).size.height - 300,
                      child: Icon(Icons.image, size: 300, color: Colors.white),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  InkWell(
                    onTap: () {
                      _imgFromGallery();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 50,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.image, color: Colors.black, size: 30),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      _imgFromCamera();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 50,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.camera_alt, color: Colors.black, size: 30),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PosePainter extends CustomPainter {
  var image;
  List<Pose> poses;
  PosePainter(this.image, this.poses);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(image, Offset.zero, Paint());

    Paint paint = Paint();
    paint.color = Colors.red;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;

    Paint linepaint = Paint();
    linepaint.color = Colors.yellow;
    linepaint.style = PaintingStyle.stroke;
    linepaint.strokeWidth = 5;

    for (Pose pose in poses) {
      // to access all landmarks
      pose.landmarks.forEach((_, landmark) {
        canvas.drawCircle(Offset(landmark.x, landmark.y), 2, paint);
      });

      void drawCustomLine(PoseLandmarkType start, PoseLandmarkType end, Paint linepaint) {
        PoseLandmark landmarkStart = pose.landmarks[start]!;
        PoseLandmark landmarkEnd = pose.landmarks[end]!;
        canvas.drawLine(Offset(landmarkStart.x, landmarkStart.y),
            Offset(landmarkEnd.x, landmarkEnd.y), linepaint);
      }

      drawCustomLine(PoseLandmarkType.leftWrist, PoseLandmarkType.leftElbow, linepaint);
      drawCustomLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftShoulder, linepaint);
      drawCustomLine(PoseLandmarkType.rightWrist, PoseLandmarkType.rightElbow, linepaint);
      drawCustomLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightShoulder, linepaint);
      drawCustomLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, linepaint);
      drawCustomLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, linepaint);
      drawCustomLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, linepaint);
      drawCustomLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip, linepaint);
      drawCustomLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, linepaint);
      drawCustomLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, linepaint);
      drawCustomLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, linepaint);
      drawCustomLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, linepaint);
      drawCustomLine(PoseLandmarkType.leftAnkle, PoseLandmarkType.leftFootIndex, linepaint);
      drawCustomLine(PoseLandmarkType.rightAnkle, PoseLandmarkType.rightFootIndex, linepaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
