import 'package:flutter/material.dart';

import '../screens/face_verification_screen.dart';
import 'qr_scanner_screen.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Smart Attendance"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 30),

            const Icon(Icons.school_rounded, size: 90, color: Colors.blue),

            const SizedBox(height: 20),

            const Text(
              "Student Dashboard",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            const Text(
              "Manage your attendance",
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),

            const SizedBox(height: 40),

            // Face Verification
            SizedBox(
              width: double.infinity,
              child: Card(
                elevation: 2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const FaceVerificationScreen(),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(Icons.face, size: 42, color: Colors.blue),

                        SizedBox(width: 18),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Face Verification",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              SizedBox(height: 5),

                              Text(
                                "Set up your face for secure attendance",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),

                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Scan QR
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final sessionId = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (context) => const QRScannerScreen(),
                    ),
                  );

                  if (!context.mounted) return;

                  if (sessionId == null || sessionId.isEmpty) {
                    return;
                  }

                  debugPrint("QR SESSION ID RECEIVED: $sessionId");

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          FaceVerificationScreen(sessionId: sessionId),
                    ),
                  );
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text("Scan QR", style: TextStyle(fontSize: 18)),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "You must complete face verification before marking attendance.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
