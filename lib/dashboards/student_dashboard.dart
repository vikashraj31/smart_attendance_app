import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../screens/face_verification_screen.dart';
import '../services/auth_service.dart';
import 'qr_scanner_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  bool _checkingClass = false;

  Future<void> _showMessage(
    String message, {
    bool isError = true,
  }) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _scanAttendanceQr() async {
    if (_checkingClass) return;

    // ============================================================
    // OPEN QR SCANNER
    // ============================================================

    final sessionId =
        await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) =>
            const QRScannerScreen(),
      ),
    );

    if (!mounted) return;

    if (sessionId == null ||
        sessionId.trim().isEmpty) {
      return;
    }

    setState(() {
      _checkingClass = true;
    });

    try {
      final firestore =
          FirebaseFirestore.instance;

      // ========================================================
      // 1. GET ATTENDANCE SESSION
      // ========================================================

      final sessionDoc = await firestore
          .collection('attendance_sessions')
          .doc(sessionId)
          .get();

      if (!sessionDoc.exists) {
        throw Exception(
          'Attendance session not found.',
        );
      }

      final sessionData =
          sessionDoc.data();

      if (sessionData == null) {
        throw Exception(
          'Invalid attendance session.',
        );
      }

      // ========================================================
      // 2. CHECK SESSION ACTIVE
      // ========================================================

      final active =
          sessionData['active'] as bool? ??
              false;

      if (!active) {
        throw Exception(
          'This attendance session is no longer active.',
        );
      }

      // ========================================================
      // 3. GET ROSTER ID
      // ========================================================

      String? rosterId =
          sessionData['rosterId']
              ?.toString();

      // --------------------------------------------------------
      // FALLBACK FOR OLD SESSIONS
      // --------------------------------------------------------

      if (rosterId == null ||
          rosterId.isEmpty) {
        final department =
            sessionData['department']
                ?.toString();

        final year =
            sessionData['year']
                ?.toString();

        final section =
            sessionData['section']
                ?.toString();

        if (department == null ||
            year == null ||
            section == null) {
          throw Exception(
            'This QR does not contain class information.',
          );
        }

        rosterId =
            '${department.toLowerCase()}_'
            '${year.toLowerCase().replaceAll(' ', '_')}_'
            '${section.toLowerCase()}';
      }

      debugPrint(
        'Attendance Roster ID: $rosterId',
      );

      // ========================================================
      // 4. GET LOGGED-IN STUDENT ROLL NUMBER
      // ========================================================

      final rollNo =
          await AuthService.instance
              .getStudentRollNo();

      if (rollNo == null ||
          rollNo.trim().isEmpty) {
        throw Exception(
          'Could not determine your roll number.',
        );
      }

      final cleanRollNo =
          rollNo.trim();

      debugPrint(
        'Student Roll No: $cleanRollNo',
      );

      // ========================================================
      // 5. CHECK STUDENT IN CLASS ROSTER
      //
      // IMPORTANT:
      // Search by rollNo FIELD instead of assuming
      // that document ID is the roll number.
      // ========================================================

      final studentsQuery =
          await firestore
              .collection('student_rosters')
              .doc(rosterId)
              .collection('students')
              .where(
                'rollNo',
                isEqualTo: cleanRollNo,
              )
              .limit(1)
              .get();

      if (studentsQuery.docs.isEmpty) {
        throw Exception(
          'You do not belong to this class.\n'
          'Roll No: $cleanRollNo',
        );
      }

      final studentDoc =
          studentsQuery.docs.first;

      final studentData =
          studentDoc.data();

      final studentName =
          studentData['name']
              ?.toString() ??
          cleanRollNo;

      debugPrint(
        'Student belongs to class: '
        '$studentName',
      );

      // ========================================================
      // 6. CLASS VERIFIED
      // ========================================================

      await _showMessage(
        'Class verified. Starting face verification...',
        isError: false,
      );

      await Future.delayed(
        const Duration(
          milliseconds: 500,
        ),
      );

      if (!mounted) return;

      // ========================================================
      // 7. OPEN FACE VERIFICATION
      // ========================================================

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              FaceVerificationScreen(
            sessionId: sessionId,
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'Class verification error: $e',
      );

      if (!mounted) return;

      await _showMessage(
        e
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _checkingClass = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Smart Attendance',
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 30),

            const Icon(
              Icons.school_rounded,
              size: 90,
              color: Colors.blue,
            ),

            const SizedBox(height: 20),

            const Text(
              'Student Dashboard',
              style: TextStyle(
                fontSize: 26,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Manage your attendance',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 40),

            // ==================================================
            // FACE VERIFICATION
            // ==================================================

            SizedBox(
              width: double.infinity,
              child: Card(
                elevation: 2,
                child: InkWell(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                  onTap: () {
                    Navigator.of(
                      context,
                    ).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const FaceVerificationScreen(),
                      ),
                    );
                  },
                  child: const Padding(
                    padding:
                        EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.face,
                          size: 42,
                          color: Colors.blue,
                        ),

                        SizedBox(width: 18),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                'Face Verification',
                                style:
                                    TextStyle(
                                  fontSize: 18,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),

                              SizedBox(height: 5),

                              Text(
                                'Set up your face for secure attendance',
                                style:
                                    TextStyle(
                                  color:
                                      Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Icon(
                          Icons
                              .arrow_forward_ios,
                          size: 16,
                          color:
                              Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // SCAN QR
            // ==================================================

            SizedBox(
              width: double.infinity,
              height: 56,
              child:
                  ElevatedButton.icon(
                onPressed:
                    _checkingClass
                        ? null
                        : _scanAttendanceQr,
                icon: _checkingClass
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons
                            .qr_code_scanner,
                      ),
                label: Text(
                  _checkingClass
                      ? 'Checking Class...'
                      : 'Scan QR',
                  style:
                      const TextStyle(
                    fontSize: 18,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Scan your teacher's QR code. "
              'Your class membership will be verified '
              'before face verification.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}