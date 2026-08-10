import 'package:flutter/material.dart';

class ClassListScreen extends StatelessWidget {
  final String category;

  const ClassListScreen({
    super.key,
    required this.category,
  });

  // Temporary class data.
  // Baad me Firebase Firestore se aayega.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$category Classes"),
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              "$category Classes",
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "Select a class to take attendance.",
              style: const TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
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

  const _ClassCard({
    required this.className,
    required this.students,
    required this.subject,
    required this.year,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),

      child: InkWell(
        borderRadius: BorderRadius.circular(16),

        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "$className selected",
              ),
            ),
          );
        },

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
                  const Icon(
                    Icons.people,
                    size: 20,
                    color: Colors.grey,
                  ),

                  const SizedBox(width: 8),

                  Text(
                    "$students Students",
                    style: const TextStyle(
                      fontSize: 15,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  const Icon(
                    Icons.menu_book,
                    size: 20,
                    color: Colors.grey,
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      subject,
                      style: const TextStyle(
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  const Icon(
                    Icons.school,
                    size: 20,
                    color: Colors.grey,
                  ),

                  const SizedBox(width: 8),

                  Text(
                    "$year • Section $section",
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}