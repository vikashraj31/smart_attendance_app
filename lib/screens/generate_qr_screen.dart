import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class GenerateQrScreen extends StatefulWidget {
  final String className;
  final int students;
  final String subject;

  const GenerateQrScreen({
    super.key,
    required this.className,
    required this.students,
    required this.subject,
  });

  @override
  State<GenerateQrScreen> createState() => _GenerateQrScreenState();
}

class _GenerateQrScreenState extends State<GenerateQrScreen> {
  String? _sessionId;
  bool _isCreatingSession = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _createAttendanceSession();
  }

  Future<void> _createAttendanceSession() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception("Teacher is not logged in.");
      }

      // Generate a unique Firestore document ID.
      final sessionRef = FirebaseFirestore.instance
          .collection('attendance_sessions')
          .doc();

      await sessionRef.set({
        'teacherId': user.uid,
        'className': widget.className,
        'subject': widget.subject,
        'studentCount': widget.students,
        'createdAt': FieldValue.serverTimestamp(),
        'active': true,
      });

      if (!mounted) return;

      setState(() {
        _sessionId = sessionRef.id;
        _isCreatingSession = false;
      });

      debugPrint("Attendance session created: ${sessionRef.id}");
    } catch (e) {
      debugPrint("Session creation error: $e");

      if (!mounted) return;

      setState(() {
        _isCreatingSession = false;
        _error = "Could not create attendance session.";
      });
    }
  }

  Future<void> _generateNewQr() async {
    setState(() {
      _isCreatingSession = true;
      _sessionId = null;
      _error = null;
    });

    await _createAttendanceSession();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Generate QR"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),

            Text(
              widget.className,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              widget.subject,
              style: const TextStyle(
                fontSize: 17,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 25),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _InfoItem(
                      icon: Icons.people,
                      value: "${widget.students}",
                      label: "Students",
                    ),
                    _InfoItem(
                      icon: Icons.menu_book,
                      value: widget.subject,
                      label: "Subject",
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              "Scan QR to Mark Attendance",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            const Text(
              "Students can scan this QR code to mark their attendance.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 15,
              ),
            ),

            const SizedBox(height: 25),

            if (_isCreatingSession)
              const Padding(
                padding: EdgeInsets.all(60),
                child: CircularProgressIndicator(),
              )
            else if (_error != null)
              Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 60,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _generateNewQr,
                    child: const Text("Try Again"),
                  ),
                ],
              )
            else if (_sessionId != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _sessionId!,
                  version: QrVersions.auto,
                  size: 260,
                  backgroundColor: Colors.white,
                ),
              ),

            const SizedBox(height: 25),

            if (_sessionId != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.30),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Attendance session is active.",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 25),

            if (_sessionId != null)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _generateNewQr,
                  icon: const Icon(Icons.refresh),
                  label: const Text(
                    "Generate New QR",
                    style: TextStyle(fontSize: 18),
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

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _InfoItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
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
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}