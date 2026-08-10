import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class GenerateQrScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // Temporary QR data.
    // Later this will contain a unique attendance session ID.
    final String qrData =
        "attendance|$className|$subject";

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

            // --------------------------------------------------
            // CLASS NAME
            // --------------------------------------------------

            Text(
              className,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              subject,
              style: const TextStyle(
                fontSize: 17,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 25),

            // --------------------------------------------------
            // CLASS INFORMATION
            // --------------------------------------------------

            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceAround,
                  children: [
                    _InfoItem(
                      icon: Icons.people,
                      value: "$students",
                      label: "Students",
                    ),
                    _InfoItem(
                      icon: Icons.menu_book,
                      value: subject,
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

            // --------------------------------------------------
            // QR CODE
            // --------------------------------------------------

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
                data: qrData,
                version: QrVersions.auto,
                size: 260,
                backgroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 25),

            // --------------------------------------------------
            // STATUS
            // --------------------------------------------------

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

            // --------------------------------------------------
            // GENERATE NEW QR
            // --------------------------------------------------

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "New QR session will be generated here.",
                      ),
                    ),
                  );
                },
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

// ============================================================
// INFORMATION ITEM
// ============================================================

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