import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

    final studentUid = user.uid;

    // Get attendance session
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

    // Check whether session is active
    final active = sessionData['active'] as bool? ?? false;

    if (!active) {
      throw Exception('This attendance session is no longer active.');
    }

    // Attendance document for this student
    final attendanceRef = _firestore
        .collection('attendance_sessions')
        .doc(sessionId)
        .collection('attendance')
        .doc(studentUid);

    // Prevent duplicate attendance
    final existingAttendance = await attendanceRef.get();

    if (existingAttendance.exists) {
      throw Exception('Attendance already marked.');
    }

    // Save attendance
    await attendanceRef.set({
      'studentId': studentUid,
      'studentEmail': user.email,
      'studentName': user.displayName ?? '',
      'status': 'present',
      'markedAt': FieldValue.serverTimestamp(),
    });
  }
}