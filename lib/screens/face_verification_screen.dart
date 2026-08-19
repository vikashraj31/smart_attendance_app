import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/face_matching_service.dart';

class FaceVerificationScreen extends StatefulWidget {
  const FaceVerificationScreen({super.key});

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;

  bool _isInitializing = true;
  bool _isProcessingFrame = false;
  bool _isCapturing = false;

  int _faceCount = 0;
  String _status = "Initializing camera...";

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final detector = await FaceDetector.create(
        model: FaceDetectionModel.frontCamera,
      );

      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception("No camera found.");
      }

      CameraDescription? frontCamera;

      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
          break;
        }
      }

      if (frontCamera == null) {
        throw Exception("Front camera not found.");
      }

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        await detector.dispose();
        return;
      }

      _faceDetector = detector;
      _cameraController = controller;

      setState(() {
        _isInitializing = false;
        _status = "Position your face inside the camera";
      });

      await controller.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint("Initialization error: $e");

      if (!mounted) return;

      setState(() {
        _isInitializing = false;
        _status = "Camera initialization failed";
      });
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessingFrame || _isCapturing) {
      return;
    }

    final detector = _faceDetector;

    if (detector == null) {
      return;
    }

    _isProcessingFrame = true;

    try {
      final faces = await detector.detectFacesFromCameraImage(
        image,
        mode: FaceDetectionMode.fast,
        maxDim: 640,
      );

      if (!mounted) return;

      setState(() {
        _faceCount = faces.length;

        if (faces.isEmpty) {
          _status = "No face detected";
        } else if (faces.length == 1) {
          _status = "Face detected";
        } else {
          _status = "Only one face is allowed";
        }
      });
    } catch (e) {
      debugPrint("Face detection error: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _generateFaceEmbedding() async {
  final controller = _cameraController;
  final detector = _faceDetector;

  if (controller == null || detector == null) {
    return;
  }

  if (_faceCount != 1 || _isCapturing) {
    return;
  }

  setState(() {
    _isCapturing = true;
    _status = "Capturing face...";
  });

  try {
    // Stop live camera stream before taking photo.
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }

    final XFile photo = await controller.takePicture();

    final Uint8List imageBytes = await photo.readAsBytes();

    if (!mounted) return;

    setState(() {
      _status = "Analyzing face...";
    });

    // Detect face again from captured image.
    final faces = await detector.detectFacesFromBytes(
      imageBytes,
      mode: FaceDetectionMode.full,
    );

    if (faces.length != 1) {
      if (!mounted) return;

      setState(() {
        _isCapturing = false;
        _faceCount = faces.length;

        if (faces.isEmpty) {
          _status = "No face found in captured image";
        } else {
          _status = "Only one face is allowed";
        }
      });

      await controller.startImageStream(_processCameraImage);
      return;
    }

    if (!mounted) return;

    setState(() {
      _status = "Generating face embedding...";
    });

    // Generate current face's 192-dimensional embedding.
    final embedding = await detector.getFaceEmbedding(
      faces.first,
      imageBytes,
    );

    final List<double> capturedEmbedding = embedding
        .map((value) => value.toDouble())
        .toList();

    debugPrint(
      "Captured embedding length: ${capturedEmbedding.length}",
    );

    // Get registered face embedding from Firebase.
    if (!mounted) return;

    setState(() {
      _status = "Loading registered face...";
    });

    final registeredEmbedding =
        await AuthService.instance.getRegisteredFaceEmbedding();

    if (registeredEmbedding == null) {
      if (!mounted) return;

      setState(() {
        _isCapturing = false;
        _status = "No registered face found";
      });

      await controller.startImageStream(_processCameraImage);
      return;
    }

    debugPrint(
      "Registered embedding length: ${registeredEmbedding.length}",
    );

    // Compare both embeddings.
    if (!mounted) return;

    setState(() {
      _status = "Verifying face...";
    });

    final similarity = FaceMatchingService.cosineSimilarity(
      registeredEmbedding,
      capturedEmbedding,
    );

    debugPrint(
      "Face similarity: $similarity",
    );

    final isMatch = FaceMatchingService.isMatch(
      registeredEmbedding,
      capturedEmbedding,
      threshold: 0.70,
    );

    if (!mounted) return;

    if (isMatch) {
      setState(() {
        _isCapturing = false;
        _status =
            "Face verified successfully (${similarity.toStringAsFixed(3)})";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Face verified successfully. Similarity: ${similarity.toStringAsFixed(3)}",
          ),
        ),
      );
    } else {
      setState(() {
        _isCapturing = false;
        _status =
            "Face not recognized (${similarity.toStringAsFixed(3)})";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Face verification failed. Similarity: ${similarity.toStringAsFixed(3)}",
          ),
        ),
      );
    }

    await controller.startImageStream(_processCameraImage);
  } catch (e) {
    debugPrint("Face verification error: $e");

    if (!mounted) return;

    setState(() {
      _isCapturing = false;
      _status = "Could not verify face";
    });

    try {
      if (!controller.value.isStreamingImages) {
        await controller.startImageStream(
          _processCameraImage,
        );
      }
    } catch (streamError) {
      debugPrint(
        "Could not restart camera stream: $streamError",
      );
    }
  }
}

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Face Verification"), centerTitle: true),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }

    final controller = _cameraController;

    if (controller == null || !controller.value.isInitialized) {
      return Center(child: Text(_status));
    }

    final canCapture = _faceCount == 1 && !_isCapturing;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: CameraPreview(controller),
            ),
          ),
        ),

        const SizedBox(height: 16),

        Text(
          _status,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _faceCount == 1
                ? Colors.green
                : _faceCount > 1
                ? Colors.red
                : Colors.orange,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          "Faces detected: $_faceCount",
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),

        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: canCapture ? _generateFaceEmbedding : null,
              icon: const Icon(Icons.face),
              label: Text(
                _isCapturing ? "Processing..." : "Capture & Verify Face",
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
