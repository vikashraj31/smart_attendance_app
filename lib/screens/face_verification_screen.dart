import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/material.dart';

import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/face_matching_service.dart';

class FaceVerificationScreen extends StatefulWidget {
  final String? sessionId;

  const FaceVerificationScreen({
    super.key,
    this.sessionId,
  });

  @override
  State<FaceVerificationScreen> createState() =>
      _FaceVerificationScreenState();
}

class _FaceVerificationScreenState
    extends State<FaceVerificationScreen> {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;

  bool _isInitializing = true;
  bool _isProcessingFrame = false;
  bool _isCapturing = false;

  bool _isRegistrationMode = false;
  bool _faceAlreadyRegistered = false;
  bool _registeredOnAnotherDevice = false;

  int _faceCount = 0;

  String _status = "Initializing camera...";

  @override
  void initState() {
    super.initState();

    _isRegistrationMode =
        widget.sessionId == null ||
        widget.sessionId!.isEmpty;

    _initialize();
  }

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> _initialize() async {
    try {
      // ----------------------------------------------------------
      // REGISTRATION MODE
      // ----------------------------------------------------------

      if (_isRegistrationMode) {
        await _checkRegistrationStatus();

        if (_registeredOnAnotherDevice ||
            _faceAlreadyRegistered) {
          if (mounted) {
            setState(() {
              _isInitializing = false;
            });
          }

          return;
        }
      }

      // ----------------------------------------------------------
      // CAMERA + DETECTOR
      // ----------------------------------------------------------

      final detector = await FaceDetector.create(
        model: FaceDetectionModel.frontCamera,
      );

      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception("No camera found.");
      }

      CameraDescription? frontCamera;

      for (final camera in cameras) {
        if (camera.lensDirection ==
            CameraLensDirection.front) {
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

        if (_isRegistrationMode) {
          _status =
              "Position your face inside the camera";
        } else {
          _status =
              "Position your face inside the camera";
        }
      });

      await controller.startImageStream(
        _processCameraImage,
      );
    } catch (e) {
      debugPrint("Initialization error: $e");

      if (!mounted) return;

      setState(() {
        _isInitializing = false;
        _status =
            "Camera initialization failed";
      });
    }
  }

  // ============================================================
  // CHECK FACE REGISTRATION STATUS
  // ============================================================

  Future<void> _checkRegistrationStatus() async {
    try {
      final isRegistered =
          await AuthService.instance.isFaceRegistered();

      if (!isRegistered) {
        if (!mounted) return;

        setState(() {
          _faceAlreadyRegistered = false;
          _registeredOnAnotherDevice = false;
          _status =
              "No face registered. You can register now.";
        });

        return;
      }

      final currentDeviceRegistered =
          await AuthService.instance
              .isCurrentDeviceRegistered();

      if (!mounted) return;

      if (currentDeviceRegistered) {
        setState(() {
          _faceAlreadyRegistered = true;
          _registeredOnAnotherDevice = false;
          _status =
              "Your face is already registered on this device.";
        });
      } else {
        setState(() {
          _faceAlreadyRegistered = false;
          _registeredOnAnotherDevice = true;
          _status =
              "Your face is already registered on another device.";
        });
      }
    } catch (e) {
      debugPrint(
        "Registration status error: $e",
      );

      if (!mounted) return;

      setState(() {
        _status =
            "Could not check face registration.";
      });
    }
  }

  // ============================================================
  // LIVE FACE DETECTION
  // ============================================================

  Future<void> _processCameraImage(
    CameraImage image,
  ) async {
    if (_isProcessingFrame ||
        _isCapturing) {
      return;
    }

    // Do not allow camera processing when
    // registration is blocked.
    if (_isRegistrationMode &&
        (_faceAlreadyRegistered ||
            _registeredOnAnotherDevice)) {
      return;
    }

    final detector = _faceDetector;

    if (detector == null) {
      return;
    }

    _isProcessingFrame = true;

    try {
      final faces =
          await detector.detectFacesFromCameraImage(
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
          if (_isRegistrationMode) {
            _status =
                "Face detected. Ready to register.";
          } else {
            _status =
                "Face detected. Ready to verify.";
          }
        } else {
          _status =
              "Only one face is allowed";
        }
      });
    } catch (e) {
      debugPrint(
        "Face detection error: $e",
      );
    } finally {
      _isProcessingFrame = false;
    }
  }

  // ============================================================
  // CAPTURE + REGISTER / VERIFY
  // ============================================================

  Future<void> _generateFaceEmbedding() async {
    final controller = _cameraController;
    final detector = _faceDetector;

    if (controller == null ||
        detector == null) {
      return;
    }

    if (_faceCount != 1 ||
        _isCapturing) {
      return;
    }

    if (_isRegistrationMode &&
        (_faceAlreadyRegistered ||
            _registeredOnAnotherDevice)) {
      return;
    }

    setState(() {
      _isCapturing = true;

      if (_isRegistrationMode) {
        _status = "Capturing face...";
      } else {
        _status = "Capturing face...";
      }
    });

    try {
      // ----------------------------------------------------------
      // STOP LIVE STREAM
      // ----------------------------------------------------------

      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }

      // ----------------------------------------------------------
      // TAKE PHOTO
      // ----------------------------------------------------------

      final XFile photo =
          await controller.takePicture();

      final Uint8List imageBytes =
          await photo.readAsBytes();

      if (!mounted) return;

      setState(() {
        _status = "Analyzing face...";
      });

      // ----------------------------------------------------------
      // DETECT FACE FROM CAPTURED IMAGE
      // ----------------------------------------------------------

      final faces =
          await detector.detectFacesFromBytes(
        imageBytes,
        mode: FaceDetectionMode.full,
      );

      if (faces.length != 1) {
        if (!mounted) return;

        setState(() {
          _isCapturing = false;
          _faceCount = faces.length;

          if (faces.isEmpty) {
            _status =
                "No face found in captured image";
          } else {
            _status =
                "Only one face is allowed";
          }
        });

        await controller.startImageStream(
          _processCameraImage,
        );

        return;
      }

      // ----------------------------------------------------------
      // GENERATE EMBEDDING
      // ----------------------------------------------------------

      if (!mounted) return;

      setState(() {
        _status =
            "Generating face embedding...";
      });

      final embedding =
          await detector.getFaceEmbedding(
        faces.first,
        imageBytes,
      );

      final List<double> capturedEmbedding =
          embedding
              .map(
                (value) => value.toDouble(),
              )
              .toList();

      debugPrint(
        "Captured embedding length: "
        "${capturedEmbedding.length}",
      );

      // ==========================================================
      // REGISTRATION MODE
      // ==========================================================

      if (_isRegistrationMode) {
        await _registerFace(
          capturedEmbedding,
          controller,
        );

        return;
      }

      // ==========================================================
      // ATTENDANCE VERIFICATION MODE
      // ==========================================================

      await _verifyAndMarkAttendance(
        capturedEmbedding,
        controller,
      );
    } catch (e) {
      debugPrint(
        "Face operation error: $e",
      );

      if (!mounted) return;

      setState(() {
        _isCapturing = false;
        _status =
            "Could not complete face verification";
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "Operation failed: $e",
          ),
        ),
      );

      try {
        if (!controller.value.isStreamingImages) {
          await controller.startImageStream(
            _processCameraImage,
          );
        }
      } catch (streamError) {
        debugPrint(
          "Could not restart camera stream: "
          "$streamError",
        );
      }
    }
  }

  // ============================================================
  // REGISTER NEW FACE
  // ============================================================

  Future<void> _registerFace(
    List<double> capturedEmbedding,
    CameraController controller,
  ) async {
    if (!mounted) return;

    setState(() {
      _status =
          "Checking device registration...";
    });

    // ----------------------------------------------------------
    // DOUBLE CHECK BEFORE SAVING
    // ----------------------------------------------------------

    final alreadyRegistered =
        await AuthService.instance
            .isFaceRegistered();

    if (alreadyRegistered) {
      final sameDevice =
          await AuthService.instance
              .isCurrentDeviceRegistered();

      if (!mounted) return;

      setState(() {
        _isCapturing = false;

        if (sameDevice) {
          _faceAlreadyRegistered = true;
          _registeredOnAnotherDevice = false;
          _status =
              "Face is already registered on this device.";
        } else {
          _faceAlreadyRegistered = false;
          _registeredOnAnotherDevice = true;
          _status =
              "Face is already registered on another device.";
        }
      });

      return;
    }

    // ----------------------------------------------------------
    // SAVE FACE + DEVICE ID
    // ----------------------------------------------------------

    if (!mounted) return;

    setState(() {
      _status =
          "Registering your face...";
    });

    await AuthService.instance
        .saveFaceEmbedding(
      capturedEmbedding,
    );

    if (!mounted) return;

    setState(() {
      _isCapturing = false;
      _faceAlreadyRegistered = true;
      _registeredOnAnotherDevice = false;
      _status =
          "Face registered successfully.";
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          "Face registered successfully on this device.",
        ),
      ),
    );

    await Future.delayed(
      const Duration(seconds: 1),
    );

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  // ============================================================
  // VERIFY FACE + MARK ATTENDANCE
  // ============================================================

  Future<void> _verifyAndMarkAttendance(
    List<double> capturedEmbedding,
    CameraController controller,
  ) async {
    if (!mounted) return;

    setState(() {
      _status =
          "Loading registered face...";
    });

    final registeredEmbedding =
        await AuthService.instance
            .getRegisteredFaceEmbedding();

    // ----------------------------------------------------------
    // NO REGISTERED FACE
    // ----------------------------------------------------------

    if (registeredEmbedding == null) {
      if (!mounted) return;

      setState(() {
        _isCapturing = false;
        _status =
            "No registered face found. Please register your face first.";
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "Please register your face before marking attendance.",
          ),
        ),
      );

      await controller.startImageStream(
        _processCameraImage,
      );

      return;
    }

    debugPrint(
      "Registered embedding length: "
      "${registeredEmbedding.length}",
    );

    // ----------------------------------------------------------
    // COMPARE FACE
    // ----------------------------------------------------------

    if (!mounted) return;

    setState(() {
      _status =
          "Verifying face...";
    });

    final similarity =
        FaceMatchingService.cosineSimilarity(
      registeredEmbedding,
      capturedEmbedding,
    );

    debugPrint(
      "Face similarity: $similarity",
    );

    final isMatch =
        FaceMatchingService.isMatch(
      registeredEmbedding,
      capturedEmbedding,
      threshold: 0.70,
    );

    // ----------------------------------------------------------
    // FACE FAILED
    // ----------------------------------------------------------

    if (!isMatch) {
      if (!mounted) return;

      setState(() {
        _isCapturing = false;
        _status =
            "Face not recognized "
            "(${similarity.toStringAsFixed(3)})";
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "Face verification failed. "
            "Similarity: "
            "${similarity.toStringAsFixed(3)}",
          ),
        ),
      );

      await controller.startImageStream(
        _processCameraImage,
      );

      return;
    }

    // ----------------------------------------------------------
    // FACE SUCCESS
    // ----------------------------------------------------------

    if (!mounted) return;

    setState(() {
      _status =
          "Face verified "
          "(${similarity.toStringAsFixed(3)}). "
          "Marking attendance...";
    });

    final sessionId = widget.sessionId;

    debugPrint(
      "FACE SCREEN SESSION ID: $sessionId",
    );

    if (sessionId == null ||
        sessionId.isEmpty) {
      if (!mounted) return;

      setState(() {
        _isCapturing = false;
        _status =
            "Face verified successfully "
            "(${similarity.toStringAsFixed(3)})";
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "Face verified successfully. "
            "Similarity: "
            "${similarity.toStringAsFixed(3)}",
          ),
        ),
      );

      await controller.startImageStream(
        _processCameraImage,
      );

      return;
    }

    // ==========================================================
    // MARK ATTENDANCE
    // ==========================================================

    await AttendanceService.instance
        .markAttendance(
      sessionId: sessionId,
    );

    if (!mounted) return;

    setState(() {
      _isCapturing = false;
      _status =
          "Attendance marked successfully";
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          "Face verified and attendance marked successfully.",
        ),
      ),
    );

    await Future.delayed(
      const Duration(seconds: 1),
    );

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector?.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isRegistrationMode
              ? "Face Registration"
              : "Face Verification",
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    // ----------------------------------------------------------
    // INITIALIZING
    // ----------------------------------------------------------

    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // ----------------------------------------------------------
    // DIFFERENT DEVICE
    // ----------------------------------------------------------

    if (_isRegistrationMode &&
        _registeredOnAnotherDevice) {
      return _buildBlockedScreen(
        icon: Icons.phonelink_lock,
        title:
            "Face Already Registered",
        message:
            "Your face is already registered on another device.\n\n"
            "You cannot register the same account on this phone.",
      );
    }

    // ----------------------------------------------------------
    // SAME DEVICE ALREADY REGISTERED
    // ----------------------------------------------------------

    if (_isRegistrationMode &&
        _faceAlreadyRegistered) {
      return _buildBlockedScreen(
        icon: Icons.verified_user,
        title:
            "Face Already Registered",
        message:
            "Your face is already registered on this device.",
      );
    }

    // ----------------------------------------------------------
    // CAMERA ERROR
    // ----------------------------------------------------------

    final controller = _cameraController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _status,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final canCapture =
        _faceCount == 1 &&
        !_isCapturing;

    return Column(
      children: [
        // --------------------------------------------------------
        // MODE INFORMATION
        // --------------------------------------------------------

        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            0,
          ),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(
              alpha: 0.08,
            ),
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                _isRegistrationMode
                    ? Icons.face
                    : Icons.verified_user,
                color: Colors.blue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isRegistrationMode
                      ? "Register your face once on this device."
                      : "Verify your face to mark attendance.",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // --------------------------------------------------------
        // CAMERA
        // --------------------------------------------------------

        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio:
                  controller.value.aspectRatio,
              child: CameraPreview(
                controller,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // --------------------------------------------------------
        // STATUS
        // --------------------------------------------------------

        Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 20,
          ),
          child: Text(
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
        ),

        const SizedBox(height: 8),

        // --------------------------------------------------------
        // FACE COUNT
        // --------------------------------------------------------

        Text(
          "Faces detected: $_faceCount",
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),

        const SizedBox(height: 20),

        // --------------------------------------------------------
        // CAPTURE BUTTON
        // --------------------------------------------------------

        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            24,
            0,
            24,
            24,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed:
                  canCapture
                      ? _generateFaceEmbedding
                      : null,
              icon: const Icon(Icons.face),
              label: Text(
                _isCapturing
                    ? "Processing..."
                    : _isRegistrationMode
                        ? "Register My Face"
                        : "Capture & Verify Face",
                style:
                    const TextStyle(
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BLOCKED / ALREADY REGISTERED SCREEN
  // ============================================================

  Widget _buildBlockedScreen({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.blue,
            ),

            const SizedBox(height: 24),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  "Go Back",
                  style: TextStyle(
                    fontSize: 17,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}