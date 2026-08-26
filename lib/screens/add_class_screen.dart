import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'upload_student_list_screen.dart';

class AddClassScreen extends StatefulWidget {
  const AddClassScreen({super.key});

  @override
  State<AddClassScreen> createState() =>
      _AddClassScreenState();
}

class _AddClassScreenState
    extends State<AddClassScreen> {
  String? selectedDepartment;
  String? selectedYear;
  String? selectedSection;

  final TextEditingController
      _subjectController =
      TextEditingController();

  final List<String> departments = [
    "CSE",
    "IT",
    "CSCE",
    "CSSE",
    "ECE",
    "EEE",
    "Mechanical",
    "Civil",
  ];

  final List<String> years = [
    "1st Year",
    "2nd Year",
    "3rd Year",
    "4th Year",
  ];

  final List<String> sections =
      List.generate(
    62,
    (index) => "${index + 1}",
  );

  bool _savingClass = false;

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  // ============================================================
  // CONTINUE
  // ============================================================

  Future<void> _continue() async {
    if (_savingClass) return;

    if (selectedDepartment == null ||
        selectedYear == null ||
        selectedSection == null ||
        _subjectController.text
            .trim()
            .isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "Please fill all fields.",
          ),
        ),
      );

      return;
    }

    final result =
        await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            UploadStudentListScreen(
          department:
              selectedDepartment!,
          year: selectedYear!,
          section:
              selectedSection!,
        ),
      ),
    );

    if (result != true) {
      return;
    }

    await _saveTeacherClass();
  }

  // ============================================================
  // SAVE TEACHER CLASS
  // ============================================================

  Future<void> _saveTeacherClass() async {
    try {
      setState(() {
        _savingClass = true;
      });

      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception(
          "Teacher is not logged in.",
        );
      }

      final firestore =
          FirebaseFirestore.instance;

      final department =
          selectedDepartment!;

      final year =
          selectedYear!;

      final section =
          selectedSection!;

      final subject =
          _subjectController.text.trim();

      final rosterId =
          "${department}_${year}_${section}"
              .replaceAll(' ', '_')
              .toLowerCase();

      // ----------------------------------------------------------
      // GET ROSTER
      // ----------------------------------------------------------

      final rosterDoc =
          await firestore
              .collection('student_rosters')
              .doc(rosterId)
              .get();

      if (!rosterDoc.exists) {
        throw Exception(
          "Student list was not found.",
        );
      }

      final rosterData =
          rosterDoc.data();

      final studentCount =
          (rosterData?['studentCount']
                  as num?)
              ?.toInt() ??
          0;

      // ----------------------------------------------------------
      // DETERMINISTIC CLASS ID
      // ----------------------------------------------------------

      final classId =
          "${user.uid}_${department}_${year}_${section}"
              .replaceAll(' ', '_')
              .toLowerCase();

      final classRef =
          firestore
              .collection('teacher_classes')
              .doc(classId);

      await classRef.set(
        {
          'teacherId': user.uid,
          'department': department,
          'year': year,
          'section': section,
          'className':
              '$department $section',
          'subject': subject,
          'studentCount': studentCount,
          'rosterId': rosterId,
          'createdAt':
              FieldValue.serverTimestamp(),
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _savingClass = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "Class added successfully.",
          ),
          backgroundColor:
              Colors.green,
        ),
      );

      await Future.delayed(
        const Duration(
          milliseconds: 500,
        ),
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint(
        "Save teacher class error: $e",
      );

      if (!mounted) return;

      setState(() {
        _savingClass = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "Could not add class: $e",
          ),
          backgroundColor:
              Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text("Add Class"),
        centerTitle: true,
      ),

      body: Padding(
        padding:
            const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            const Text(
              "Department",
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            DropdownButtonFormField<
                String>(
              initialValue:
                  selectedDepartment,
              decoration:
                  const InputDecoration(
                border:
                    OutlineInputBorder(),
              ),
              hint: const Text(
                "Select Department",
              ),
              items:
                  departments.map(
                (department) {
                  return DropdownMenuItem(
                    value: department,
                    child:
                        Text(department),
                  );
                },
              ).toList(),
              onChanged: (value) {
                setState(() {
                  selectedDepartment =
                      value;
                });
              },
            ),

            const SizedBox(
              height: 20,
            ),

            const Text(
              "Year",
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            DropdownButtonFormField<
                String>(
              initialValue:
                  selectedYear,
              decoration:
                  const InputDecoration(
                border:
                    OutlineInputBorder(),
              ),
              hint: const Text(
                "Select Year",
              ),
              items:
                  years.map((year) {
                return DropdownMenuItem(
                  value: year,
                  child: Text(year),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedYear =
                      value;
                });
              },
            ),

            const SizedBox(
              height: 20,
            ),

            const Text(
              "Section",
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            DropdownButtonFormField<
                String>(
              initialValue:
                  selectedSection,
              decoration:
                  const InputDecoration(
                border:
                    OutlineInputBorder(),
              ),
              hint: const Text(
                "Select Section",
              ),
              items:
                  sections.map(
                (section) {
                  return DropdownMenuItem(
                    value: section,
                    child:
                        Text(section),
                  );
                },
              ).toList(),
              onChanged: (value) {
                setState(() {
                  selectedSection =
                      value;
                });
              },
            ),

            const SizedBox(
              height: 20,
            ),

            const Text(
              "Subject",
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            TextField(
              controller:
                  _subjectController,
              decoration:
                  const InputDecoration(
                border:
                    OutlineInputBorder(),
                hintText:
                    "Enter subject",
              ),
            ),

            const Spacer(),

            SizedBox(
              width:
                  double.infinity,
              height: 55,
              child:
                  ElevatedButton(
                onPressed:
                    _savingClass
                        ? null
                        : _continue,
                child:
                    _savingClass
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Upload Student List",
                            style:
                                TextStyle(
                              fontSize: 18,
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}