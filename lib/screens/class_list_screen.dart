import 'generate_qr_screen.dart';
import 'package:flutter/material.dart';

class ClassListScreen extends StatelessWidget {
  final String category;

  const ClassListScreen({super.key, required this.category});

  // Temporary testing data.
  // Baad me Firestore se actual classes aayengi.
  List<Map<String, dynamic>> get classes {
    if (category == "CSE") {
      return const [
        {
          "className": "CSE 58",
          "students": 62,
          "subject": "DBMS",
          "year": "2nd Year",
          "section": "58",
        },
        {
          "className": "CSE 59",
          "students": 61,
          "subject": "Computer Networks",
          "year": "2nd Year",
          "section": "59",
        },
        {
          "className": "CSE 60",
          "students": 63,
          "subject": "Operating System",
          "year": "2nd Year",
          "section": "60",
        },
        {
          "className": "CSE 61",
          "students": 60,
          "subject": "Data Structures",
          "year": "2nd Year",
          "section": "61",
        },
      ];
    }

    if (category == "IT") {
      return const [
        {
          "className": "IT 01",
          "students": 60,
          "subject": "Database Management",
          "year": "2nd Year",
          "section": "01",
        },
      ];
    }

    if (category == "Civil") {
      return const [
        {
          "className": "Civil 01",
          "students": 58,
          "subject": "Structural Engineering",
          "year": "2nd Year",
          "section": "01",
        },
        {
          "className": "Civil 02",
          "students": 61,
          "subject": "Construction Technology",
          "year": "2nd Year",
          "section": "02",
        },
      ];
    }

    return [];
  }

  // ============================================================
  // ATTENDANCE METHOD POPUP
  // ============================================================

  void _showAttendanceOptions(
    BuildContext context,
    Map<String, dynamic> classData,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ==================================================
              // HANDLE
              // ==================================================
              Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // CLASS NAME
              // ==================================================
              Text(
                classData["className"],
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                "${classData["students"]} Students • "
                "${classData["subject"]}",
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),

              const SizedBox(height: 25),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Select Attendance Method",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 15),

              // ==================================================
              // GENERATE QR
              // ==================================================
              SizedBox(
                width: double.infinity,
                child: Card(
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.pop(context);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GenerateQrScreen(
                            className: classData["className"],
                            students: classData["students"],
                            subject: classData["subject"],
                          ),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Icon(Icons.qr_code_2, size: 32, color: Colors.blue),

                          SizedBox(width: 16),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Generate QR",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                SizedBox(height: 4),

                                Text(
                                  "Take attendance using QR code",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),

                          Icon(
                            Icons.arrow_forward_ios,
                            size: 17,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ==================================================
              // MANUAL ATTENDANCE
              // ==================================================
              SizedBox(
                width: double.infinity,
                child: Card(
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Manual Attendance selected."),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Icon(Icons.edit_note, size: 32, color: Colors.green),

                          SizedBox(width: 16),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Manual Attendance",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                SizedBox(height: 4),

                                Text(
                                  "Mark students manually",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),

                          Icon(
                            Icons.arrow_forward_ios,
                            size: 17,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("$category Classes"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$category Classes",
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            const Text(
              "Select a class to take attendance.",
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),

            const SizedBox(height: 25),

            Expanded(
              child: ListView.builder(
                itemCount: classes.length,
                itemBuilder: (context, index) {
                  final classData = classes[index];

                  return _ClassCard(
                    className: classData["className"],
                    students: classData["students"],
                    subject: classData["subject"],
                    year: classData["year"],
                    section: classData["section"],
                    onTap: () {
                      _showAttendanceOptions(context, classData);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CLASS CARD
// ============================================================

class _ClassCard extends StatelessWidget {
  final String className;
  final int students;
  final String subject;
  final String year;
  final String section;
  final VoidCallback onTap;

  const _ClassCard({
    required this.className,
    required this.students,
    required this.subject,
    required this.year,
    required this.section,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.groups,
                      color: Colors.blue,
                      size: 28,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Text(
                      className,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 18,
                    color: Colors.grey,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  const Icon(Icons.people, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text("$students Students"),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  const Icon(Icons.menu_book, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(child: Text(subject)),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  const Icon(Icons.school, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text("$year • Section $section"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
