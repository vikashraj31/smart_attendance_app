import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class AttendanceService {
  AttendanceService._();

  static final AttendanceService instance = AttendanceService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> markAttendance({
    required String sessionId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    // ============================================================
    // GET ATTENDANCE SESSION
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
    // CHECK SESSION ACTIVE
    // ============================================================

    final active = sessionData['active'] as bool? ?? false;

    if (!active) {
      throw Exception(
        'This attendance session is no longer active.',
      );
    }

    // ============================================================
    // GET TEACHER LOCATION
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
    // GET STUDENT LOCATION
    // ============================================================

    final studentPosition = await _getStudentLocation();

    // ============================================================
    // CALCULATE DISTANCE
    // ============================================================

    final distance = Geolocator.distanceBetween(
      teacherLatitude,
      teacherLongitude,
      studentPosition.latitude,
      studentPosition.longitude,
    );

    final distanceInMeters = distance.round();

    // ============================================================
    // CHECK DISTANCE
    // ============================================================

    final isWithinRange = distance <= maxDistance;

    // ============================================================
    // ATTENDANCE DOCUMENT
    // ============================================================

    final studentUid = user.uid;

    final attendanceRef = _firestore
        .collection('attendance_sessions')
        .doc(sessionId)
        .collection('attendance')
        .doc(studentUid);

    // ============================================================
    // PREVENT DUPLICATE ATTENDANCE
    // ============================================================

    final existingAttendance = await attendanceRef.get();

    if (existingAttendance.exists) {
      throw Exception(
        'Attendance already marked.',
      );
    }

    // ============================================================
    // SAVE ATTENDANCE
    // ============================================================

    await attendanceRef.set({
      'studentId': studentUid,
      'studentEmail': user.email,
      'studentName': user.displayName ?? '',
      'status': 'present',

      // Integer distance in meters.
      'distance': distanceInMeters,

      // Whether student is inside allowed range.
      'withinDistance': isWithinRange,

      // Student location.
      'studentLatitude': studentPosition.latitude,
      'studentLongitude': studentPosition.longitude,

      'markedAt': FieldValue.serverTimestamp(),
    });

    // ============================================================
    // DISTANCE WARNING
    // ============================================================

    if (!isWithinRange) {
      throw Exception(
        'Attendance marked, but you are '
        '$distanceInMeters m away from the teacher. '
        'Allowed distance is ${maxDistance.round()} m.',
      );
    }
  }

  // ============================================================
  // GET STUDENT LOCATION
  // ============================================================

  Future<Position> _getStudentLocation() async {
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        'Location service is turned off. Please turn on GPS.',
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
        'Location permission was denied.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. '
        'Please enable location permission from settings.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }
}