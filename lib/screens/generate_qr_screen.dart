import 'dart:async';
import 'attendance_report_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qr_flutter/qr_flutter.dart';

class GenerateQrScreen extends StatefulWidget {
  final String className;
  final int students;
  final String subject;

  // normal / auditorium
  final String classType;

  // Maximum allowed distance in meters
  final int maxDistance;

  // Class/roster information
  final String department;
  final String year;
  final String section;

  // Uploaded student-list document ID
  final String rosterId;

  const GenerateQrScreen({
    super.key,
    required this.className,
    required this.students,
    required this.subject,
    required this.classType,
    required this.maxDistance,
    required this.department,
    required this.year,
    required this.section,
    required this.rosterId,
  });

  @override
  State<GenerateQrScreen> createState() =>
      _GenerateQrScreenState();
}

class _GenerateQrScreenState
    extends State<GenerateQrScreen> {
  String? _sessionId;

  Timer? _countdownTimer;

  int _remainingSeconds = 180;

  bool _sessionExpired = false;
  bool _isCreatingSession = true;
  bool _isEndingSession = false;

  String? _error;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _createAttendanceSession();
  }

  // ============================================================
  // GET TEACHER LOCATION
  // ============================================================

  Future<Position> _getTeacherLocation() async {
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        "Location service is turned off. Please turn on GPS.",
      );
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception(
        "Location permission was denied.",
      );
    }

    if (permission ==
        LocationPermission.deniedForever) {
      throw Exception(
        "Location permission is permanently denied. "
        "Please enable it from app settings.",
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  // ============================================================
  // CREATE ATTENDANCE SESSION
  // ============================================================

  Future<void> _createAttendanceSession() async {
    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception(
          "Teacher is not logged in.",
        );
      }

      if (mounted) {
        setState(() {
          _isCreatingSession = true;
          _error = null;
          _sessionExpired = false;
          _isEndingSession = false;
        });
      }

      // Get teacher location.
      final position =
          await _getTeacherLocation();

      debugPrint(
        "Teacher latitude: ${position.latitude}",
      );

      debugPrint(
        "Teacher longitude: ${position.longitude}",
      );

      // Create unique Firestore session.
      final sessionRef =
          FirebaseFirestore.instance
              .collection('attendance_sessions')
              .doc();

      await sessionRef.set({
        'teacherId': user.uid,

        'className': widget.className,
        'subject': widget.subject,
        'studentCount': widget.students,

        'classType': widget.classType,
        'maxDistance': widget.maxDistance,

        'department': widget.department,
        'year': widget.year,
        'section': widget.section,

        // IMPORTANT:
        // This connects the QR session with
        // the uploaded student roster.
        'rosterId': widget.rosterId,

        'teacherLatitude':
            position.latitude,
        'teacherLongitude':
            position.longitude,

        'createdAt':
            FieldValue.serverTimestamp(),

        'active': true,

        // Useful for report/finalization.
        'endedManually': false,
      });

      if (!mounted) return;

      setState(() {
        _sessionId = sessionRef.id;
        _isCreatingSession = false;
        _remainingSeconds = 180;
        _sessionExpired = false;
        _isEndingSession = false;
      });

      _startCountdown();

      debugPrint(
        "Attendance session created: ${sessionRef.id}",
      );

      debugPrint(
        "Roster ID: ${widget.rosterId}",
      );

      debugPrint(
        "Class type: ${widget.classType}",
      );

      debugPrint(
        "Maximum distance: ${widget.maxDistance} meters",
      );
    } catch (e) {
      debugPrint(
        "Session creation error: $e",
      );

      if (!mounted) return;

      setState(() {
        _isCreatingSession = false;
        _error = e
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  // ============================================================
  // START 3-MINUTE COUNTDOWN
  // ============================================================

  void _startCountdown() {
    _countdownTimer?.cancel();

    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_remainingSeconds > 1) {
          setState(() {
            _remainingSeconds--;
          });

          return;
        }

        timer.cancel();

        final sessionId = _sessionId;

        if (sessionId == null) {
          return;
        }

        setState(() {
          _remainingSeconds = 0;
          _sessionExpired = true;
        });

        await _finishSession(
          sessionId,
          endedManually: false,
        );
      },
    );
  }

  // ============================================================
  // END ATTENDANCE MANUALLY
  // ============================================================

  Future<void> _endAttendanceManually() async {
    final sessionId = _sessionId;

    if (sessionId == null ||
        _isEndingSession ||
        _sessionExpired) {
      return;
    }

    final shouldEnd =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text(
                "End Attendance?",
              ),
              content: const Text(
                "Students will no longer be able to "
                "mark attendance using this QR code.\n\n"
                "The attendance report will open next.",
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(
                    context,
                    false,
                  ),
                  child:
                      const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(
                    context,
                    true,
                  ),
                  child:
                      const Text("End Attendance"),
                ),
              ],
            );
          },
        );

    if (shouldEnd != true) {
      return;
    }

    setState(() {
      _isEndingSession = true;
    });

    _countdownTimer?.cancel();

    await _finishSession(
      sessionId,
      endedManually: true,
    );
  }

  // ============================================================
  // FINISH SESSION + OPEN REPORT
  // ============================================================

  Future<void> _finishSession(
    String sessionId, {
    required bool endedManually,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('attendance_sessions')
          .doc(sessionId)
          .update({
        'active': false,
        'endedManually': endedManually,
        'endedAt':
            FieldValue.serverTimestamp(),
      });

      debugPrint(
        "Attendance session ended: $sessionId",
      );

      if (!mounted) return;

      setState(() {
        _sessionExpired = true;
        _isEndingSession = false;
      });

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              AttendanceReportScreen(
            sessionId: sessionId,
            department:
                widget.department,
            year: widget.year,
            section:
                widget.section,
            className:
                widget.className,
            subject:
                widget.subject,
            maxDistance:
                widget.maxDistance,
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        "Could not end attendance session: $e",
      );

      if (!mounted) return;

      setState(() {
        _isEndingSession = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "Could not end attendance: $e",
          ),
        ),
      );
    }
  }

  // ============================================================
  // GENERATE NEW QR
  // ============================================================

  Future<void> _generateNewQr() async {
    _countdownTimer?.cancel();

    setState(() {
      _isCreatingSession = true;
      _sessionId = null;
      _error = null;
      _remainingSeconds = 180;
      _sessionExpired = false;
      _isEndingSession = false;
    });

    await _createAttendanceSession();
  }

  // ============================================================
  // FORMAT COUNTDOWN
  // ============================================================

  String get _formattedTime {
    final minutes =
        _remainingSeconds ~/ 60;

    final seconds =
        _remainingSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text("Generate QR"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // ==================================================
            // CLASS NAME
            // ==================================================

            Text(
              widget.className,
              style: const TextStyle(
                fontSize: 28,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // ==================================================
            // SUBJECT
            // ==================================================

            Text(
              widget.subject,
              style: const TextStyle(
                fontSize: 17,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 8),

            // ==================================================
            // CLASS TYPE + DISTANCE
            // ==================================================

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration:
                  BoxDecoration(
                color:
                    widget.classType ==
                            "auditorium"
                        ? Colors.orange
                            .withValues(
                            alpha: 0.12,
                          )
                        : Colors.blue
                            .withValues(
                            alpha: 0.12,
                          ),
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
              child: Text(
                widget.classType ==
                        "auditorium"
                    ? "Auditorium • ${widget.maxDistance} m"
                    : "Normal Class • ${widget.maxDistance} m",
                style: TextStyle(
                  color:
                      widget.classType ==
                              "auditorium"
                          ? Colors.orange
                              .shade800
                          : Colors.blue
                              .shade800,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 25),

            // ==================================================
            // CLASS INFORMATION
            // ==================================================

            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  18,
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceAround,
                  children: [
                    _InfoItem(
                      icon:
                          Icons.people,
                      value:
                          "${widget.students}",
                      label:
                          "Students",
                    ),
                    _InfoItem(
                      icon:
                          Icons.menu_book,
                      value:
                          widget.subject,
                      label:
                          "Subject",
                    ),
                    _InfoItem(
                      icon:
                          Icons.location_on,
                      value:
                          "${widget.maxDistance} m",
                      label:
                          "Distance",
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ==================================================
            // TITLE
            // ==================================================

            const Text(
              "Scan QR to Mark Attendance",
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
              textAlign:
                  TextAlign.center,
            ),

            const SizedBox(height: 8),

            const Text(
              "Students can scan this QR code "
              "to mark their attendance.",
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 15,
              ),
            ),

            const SizedBox(height: 25),

            // ==================================================
            // LOADING
            // ==================================================

            if (_isCreatingSession)
              const Padding(
                padding:
                    EdgeInsets.all(60),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text(
                      "Getting teacher location...",
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              )

            // ==================================================
            // ERROR
            // ==================================================

            else if (_error != null)
              Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 60,
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  Text(
                    _error!,
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  ElevatedButton(
                    onPressed:
                        _generateNewQr,
                    child:
                        const Text(
                      "Try Again",
                    ),
                  ),
                ],
              )

            // ==================================================
            // QR CODE
            // ==================================================

            else if (_sessionId != null)
              Container(
                padding:
                    const EdgeInsets.all(
                  20,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(
                        alpha: 0.10,
                      ),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _sessionId!,
                  version:
                      QrVersions.auto,
                  size: 260,
                  backgroundColor:
                      Colors.white,
                ),
              ),

            const SizedBox(height: 25),

            // ==================================================
            // COUNTDOWN
            // ==================================================

            if (_sessionId != null)
              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration:
                    BoxDecoration(
                  color: _sessionExpired
                      ? Colors.red
                          .withValues(
                          alpha: 0.10,
                        )
                      : Colors.blue
                          .withValues(
                          alpha: 0.10,
                        ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                  border: Border.all(
                    color:
                        _sessionExpired
                            ? Colors.red
                                .withValues(
                                alpha:
                                    0.30,
                              )
                            : Colors.blue
                                .withValues(
                                alpha:
                                    0.30,
                              ),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _sessionExpired
                          ? "Attendance Session Ended"
                          : "Time Remaining",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w600,
                        color:
                            _sessionExpired
                                ? Colors.red
                                : Colors.blue,
                      ),
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    Text(
                      _formattedTime,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            _sessionExpired
                                ? Colors.red
                                : Colors.blue,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      _sessionExpired
                          ? "Students can no longer mark attendance."
                          : "Students must complete attendance within this time.",
                      textAlign:
                          TextAlign.center,
                      style:
                          const TextStyle(
                        fontSize: 13,
                        color:
                            Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // ==================================================
            // END ATTENDANCE BUTTON
            // ==================================================

            if (_sessionId != null &&
                !_sessionExpired)
              SizedBox(
                width:
                    double.infinity,
                height: 55,
                child:
                    ElevatedButton.icon(
                  onPressed:
                      _isEndingSession
                          ? null
                          : _endAttendanceManually,
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.red,
                    foregroundColor:
                        Colors.white,
                  ),
                  icon: _isEndingSession
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.stop_circle,
                        ),
                  label: Text(
                    _isEndingSession
                        ? "Ending Attendance..."
                        : "End Attendance",
                    style:
                        const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // ==================================================
            // SESSION STATUS
            // ==================================================

            if (_sessionId != null)
              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      _sessionExpired
                          ? Colors.red
                              .withValues(
                              alpha:
                                  0.10,
                            )
                          : Colors.green
                              .withValues(
                              alpha:
                                  0.10,
                            ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                  border: Border.all(
                    color:
                        _sessionExpired
                            ? Colors.red
                                .withValues(
                                alpha:
                                    0.30,
                              )
                            : Colors.green
                                .withValues(
                                alpha:
                                    0.30,
                              ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _sessionExpired
                          ? Icons.cancel
                          : Icons
                              .check_circle,
                      color:
                          _sessionExpired
                              ? Colors.red
                              : Colors.green,
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child: Text(
                        _sessionExpired
                            ? "Attendance session has ended."
                            : "Attendance session is active.",
                        style: TextStyle(
                          color:
                              _sessionExpired
                                  ? Colors.red
                                  : Colors.green,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 25),

            // ==================================================
            // GENERATE NEW QR
            // ==================================================

            if (_sessionId != null &&
                _sessionExpired)
              SizedBox(
                width:
                    double.infinity,
                height: 55,
                child:
                    ElevatedButton.icon(
                  onPressed:
                      _generateNewQr,
                  icon: const Icon(
                    Icons.refresh,
                  ),
                  label:
                      const Text(
                    "Generate New QR",
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// INFORMATION ITEM
// ============================================================

class _InfoItem
    extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _InfoItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.blue,
          size: 28,
        ),

        const SizedBox(height: 6),

        Text(
          value,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
            fontSize: 16,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          label,
          style:
              const TextStyle(
            color: Colors.grey,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}