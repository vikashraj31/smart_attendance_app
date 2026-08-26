import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class AttendanceService {
  AttendanceService._();

  static final AttendanceService instance = AttendanceService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================
  // MARK ATTENDANCE
  // ============================================================

  Future<void> markAttendance({
    required String sessionId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    // ============================================================
    // 1. GET ATTENDANCE SESSION
    // ============================================================

    final sessionDoc = await _firestore
        .collection('attendance_sessions')
        .doc(sessionId)
        .get();

    if (!sessionDoc.exists) {
      throw Exception('Attendance session not found.');
    }

    final sessionData = sessionDoc.data();

    if (sessionData == null) {
      throw Exception('Invalid attendance session.');
    }

    // ============================================================
    // 2. CHECK SESSION ACTIVE
    // ============================================================

    final active = sessionData['active'] as bool? ?? false;

    if (!active) {
      throw Exception(
        'This attendance session is no longer active.',
      );
    }

    // ============================================================
    // 3. CLASS INFORMATION
    // ============================================================

    final department =
        sessionData['department']?.toString() ?? '';

    final year =
        sessionData['year']?.toString() ?? '';

    final section =
        sessionData['section']?.toString() ?? '';

    if (department.isEmpty ||
        year.isEmpty ||
        section.isEmpty) {
      throw Exception(
        'Attendance session class information is missing.',
      );
    }

    // ============================================================
    // 4. TEACHER LOCATION
    // ============================================================

    final teacherLatitude =
        (sessionData['teacherLatitude'] as num?)?.toDouble();

    final teacherLongitude =
        (sessionData['teacherLongitude'] as num?)?.toDouble();

    final maxDistance =
        (sessionData['maxDistance'] as num?)?.toDouble();

    if (teacherLatitude == null ||
        teacherLongitude == null ||
        maxDistance == null) {
      throw Exception(
        'Attendance session location data is missing.',
      );
    }

    // ============================================================
    // 5. ROSTER ID
    // ============================================================

    String? rosterId =
        sessionData['rosterId']?.toString();

    if (rosterId == null || rosterId.isEmpty) {
      rosterId =
          '${department}_${year}_${section}'
              .replaceAll(' ', '_')
              .toLowerCase();
    }

    debugPrint('Attendance roster ID: $rosterId');

    // ============================================================
    // 6. STUDENT ROLL NUMBER
    // ============================================================

    final email = user.email;

    if (email == null || email.trim().isEmpty) {
      throw Exception(
        'Your Google account email could not be determined.',
      );
    }

    final emailParts = email.trim().split('@');

    if (emailParts.isEmpty ||
        emailParts.first.trim().isEmpty) {
      throw Exception(
        'Could not determine your roll number from your KIIT email.',
      );
    }

    final rollNo = emailParts.first.trim();

    debugPrint('Attendance student roll: $rollNo');

    // ============================================================
    // 7. CHECK STUDENT IN ROSTER
    // ============================================================

    final studentQuery = await _firestore
        .collection('student_rosters')
        .doc(rosterId)
        .collection('students')
        .where(
          'rollNo',
          isEqualTo: rollNo,
        )
        .limit(1)
        .get();

    if (studentQuery.docs.isEmpty) {
      throw Exception(
        'You do not belong to this class.\n'
        'Roll No: $rollNo',
      );
    }

    final studentDoc = studentQuery.docs.first;
    final studentData = studentDoc.data();

    final studentName =
        studentData['name']?.toString() ??
        user.displayName ??
        '';

    if (studentName.isEmpty) {
      throw Exception(
        'Student name is missing from the class roster.',
      );
    }

    debugPrint('Roster student found: $studentName');

    // ============================================================
    // 8. GET STUDENT LOCATION
    // ============================================================

    final studentPosition = await _getStudentLocation();

    debugPrint(
      'Student latitude: ${studentPosition.latitude}',
    );

    debugPrint(
      'Student longitude: ${studentPosition.longitude}',
    );

    // ============================================================
    // 9. CALCULATE DISTANCE
    // ============================================================

    final distance = Geolocator.distanceBetween(
      teacherLatitude,
      teacherLongitude,
      studentPosition.latitude,
      studentPosition.longitude,
    );

    final distanceInMeters = distance.round();

    final isWithinRange = distance <= maxDistance;

    debugPrint(
      'Distance from teacher: ${distanceInMeters}m',
    );

    debugPrint(
      'Allowed distance: ${maxDistance.round()}m',
    );

    // ============================================================
    // 10. ATTENDANCE DOCUMENT
    // ============================================================

    final attendanceRef = _firestore
        .collection('attendance_sessions')
        .doc(sessionId)
        .collection('attendance')
        .doc(rollNo);

    // ============================================================
    // 11. DUPLICATE CHECK
    // ============================================================

    final existingAttendance =
        await attendanceRef.get();

    if (existingAttendance.exists) {
      throw Exception(
        'Attendance attempt already recorded.',
      );
    }

    // ============================================================
    // 12. SAVE ATTENDANCE
    //
    // WITHIN RANGE:
    //     Present
    //
    // OUTSIDE RANGE:
    //     Absent + Rule Break
    // ============================================================

    await attendanceRef.set({
      'studentId': user.uid,
      'rollNo': rollNo,
      'studentEmail': user.email,
      'studentName': studentName,

      // Final automatic status.
      'status': isWithinRange ? 'present' : 'absent',
      'present': isWithinRange,

      // Distance information.
      'distance': distanceInMeters,
      'withinDistance': isWithinRange,

      // Rule violation information.
      'ruleBreak': !isWithinRange,
      'ruleBreakReason':
          !isWithinRange
              ? 'Student was outside the allowed distance.'
              : null,

      // Student location.
      'studentLatitude': studentPosition.latitude,
      'studentLongitude': studentPosition.longitude,

      // This was generated by QR + face/location verification.
      'autoPresent': isWithinRange,
      'manuallyMarked': false,

      'markedAt': FieldValue.serverTimestamp(),
    });

    debugPrint(
      'Attendance attempt saved successfully for $rollNo',
    );

    // ============================================================
    // 13. RESULT
    // ============================================================

    if (!isWithinRange) {
      throw Exception(
        'You are ${distanceInMeters} m away from the teacher.\n'
        'Maximum allowed distance is ${maxDistance.round()} m.\n\n'
        'Attendance was not marked because you are outside '
        'the allowed range.',
      );
    }
  }

  // ============================================================
  // GET STUDENT LOCATION
  // ============================================================

  Future<Position> _getStudentLocation() async {
    // ------------------------------------------------------------
    // 1. GPS CHECK
    // ------------------------------------------------------------

    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        'Location/GPS is OFF.\n'
        'Please turn on Location to mark attendance.',
      );
    }

    // ------------------------------------------------------------
    // 2. CURRENT PERMISSION
    // ------------------------------------------------------------

    LocationPermission permission =
        await Geolocator.checkPermission();

    debugPrint(
      'Current location permission: $permission',
    );

    // ------------------------------------------------------------
    // 3. REQUEST PERMISSION
    // ------------------------------------------------------------

    if (permission == LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();

      debugPrint(
        'Location permission after request: $permission',
      );
    }

    // ------------------------------------------------------------
    // 4. DENIED
    // ------------------------------------------------------------

    if (permission == LocationPermission.denied) {
      throw Exception(
        'Location permission is required to mark attendance.\n'
        'Please allow Location permission and try again.',
      );
    }

    // ------------------------------------------------------------
    // 5. PERMANENTLY DENIED
    // ------------------------------------------------------------

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied.\n'
        'Please enable Location permission from App Settings '
        'and try again.',
      );
    }

    // ------------------------------------------------------------
    // 6. GET LOCATION
    // ------------------------------------------------------------

    try {
      final position =
          await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      debugPrint(
        'Location obtained successfully.',
      );

      return position;
    } catch (e) {
      debugPrint(
        'Location error: $e',
      );

      throw Exception(
        'Could not get your current location.\n'
        'Please make sure GPS is ON and try again.',
      );
    }
  }
}