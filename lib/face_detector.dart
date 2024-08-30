import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:recognition/folders/painters/face_detector_painter.dart';
import 'package:recognition/utils.dart';

class FaceDetectorView extends StatefulWidget {
  const FaceDetectorView({super.key});

  @override
  State<FaceDetectorView> createState() => _FaceDetectorViewState();
}

class _FaceDetectorViewState extends State<FaceDetectorView> {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
    ),
  );
  FaceDetectorPainter? _customPaint;
  // FacePainter? _customPaint;
  Widget? child;
  final bool _isBusy = false;

  File? _image;
  String? _path;
  ImagePicker? _imagePicker;

  @override
  void initState() {
    super.initState();

    _imagePicker = ImagePicker();
  }

  @override
  void dispose() {
    _faceDetector.close();
    _imagePicker = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _image != null
                ? FittedBox(
                    child: SizedBox(
                      height: 400,
                      width: 400,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          Image.file(_image!),
                          if (_customPaint != null)
                            Container(
                              // decoration: BoxDecoration(
                              //   color: Colors.black.withOpacity(0.5),
                              // ),
                              child: CustomPaint(
                                painter: _customPaint!,
                              ),
                            )
                        ],
                      ),
                    ),
                  )
                : const Icon(
                    Icons.image,
                    size: 200,
                  ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: _getImageAsset,
                child: const Text('From Assets'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                child: const Text('From Gallery'),
                onPressed: () => _getImage(ImageSource.gallery),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                child: const Text('Take a picture'),
                onPressed: () => _getImage(ImageSource.camera),
              ),
            ),
            if (_image != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Path $_path'),
                    const SizedBox(
                      height: 48,
                    ),
                    if (child != null) child!,
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  testSetChild(Face face, Map<FaceContourType, FaceContour?> data, Rect rect) {
    data.removeWhere((key, value) =>
        key != FaceContourType.leftEye &&
        key != FaceContourType.rightEye &&
        key != FaceContourType.upperLipTop &&
        key != FaceContourType.upperLipBottom &&
        key != FaceContourType.lowerLipTop &&
        key != FaceContourType.lowerLipBottom &&
        key != FaceContourType.noseBottom &&
        key != FaceContourType.noseBridge);

    child = Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: data.entries.map((e) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              '${e.key}',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 20,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text('${e.value?.points}'),
            ),
          ],
        );
      }).toList(),
    );
    setState(() {});
  }

  Future<void> _processImage(InputImage inputImage) async {
    child = const Center(
      child: CircularProgressIndicator(),
    );
    final List<Face> faces = await _faceDetector.processImage(inputImage);
    if (_isBusy) return;
    if (faces.isEmpty) return;
    final Rect boundingBox = faces.first.boundingBox;
    testSetChild(faces.first, faces.first.contours, boundingBox);
    _customPaint = FaceDetectorPainter(faces, boundingBox.size,
        InputImageRotation.rotation0deg, CameraLensDirection.back);
    // _customPaint = FacePainter(
    //   face: faces.first,
    //   imageSize: inputImage.metadata?.size ?? const Size(300, 300),
    // );
  }

  Future _getImage(ImageSource source) async {
    setState(() {
      _image = null;
      _path = null;
    });
    final pickedFile = await _imagePicker?.pickImage(source: source);
    if (pickedFile != null) {
      _processFile(pickedFile.path);
    }
  }

  Future _getImageAsset() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    final assets = manifestMap.keys
        .where((String key) => key.contains('images/'))
        .where((String key) =>
            key.contains('.jpg') ||
            key.contains('.jpeg') ||
            key.contains('.png') ||
            key.contains('.webp'))
        .toList();
    if (!mounted) return;
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select image',
                    style: TextStyle(fontSize: 20),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.7),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (final path in assets)
                            GestureDetector(
                              onTap: () async {
                                Navigator.of(context).pop();
                                _processFile(await getAssetPath(path));
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Image.asset(path),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel')),
                ],
              ),
            ),
          );
        });
  }

  Future _processFile(String path) async {
    setState(() {
      _image = File(path);
    });
    _path = path;
    final inputImage = InputImage.fromFilePath(path);
    _processImage(inputImage);
  }
}
