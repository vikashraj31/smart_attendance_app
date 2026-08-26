import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'generate_qr_screen.dart';
import 'manual_attendance_screen.dart';

class ClassListScreen extends StatefulWidget {
  final String category;

  const ClassListScreen({
    super.key,
    required this.category,
  });

  @override
  State<ClassListScreen> createState() =>
      _ClassListScreenState();
}

class _ClassListScreenState
    extends State<ClassListScreen> {
  bool _loading = true;

  List<Map<String, dynamic>> _classes = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  // ============================================================
  // LOAD ONLY CURRENT TEACHER'S CLASSES
  // ============================================================

  Future<void> _loadClasses() async {
    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception(
          "Teacher is not logged in.",
        );
      }

      final snapshot =
          await FirebaseFirestore.instance
              .collection('teacher_classes')
              .where(
                'teacherId',
                isEqualTo: user.uid,
              )
              .where(
                'department',
                isEqualTo: widget.category,
              )
              .get();

      final loadedClasses =
          snapshot.docs.map((doc) {
        final data = doc.data();

        return {
          'id': doc.id,
          'className':
              data['className'] ??
              '${data['department']} ${data['section']}',
          'students':
              (data['studentCount'] as num?)
                  ?.toInt() ??
              0,
          'subject':
              data['subject']?.toString() ??
              '',
          'year':
              data['year']?.toString() ??
              '',
          'section':
              data['section']?.toString() ??
              '',
          'department':
              data['department']?.toString() ??
              widget.category,
          'rosterId':
              data['rosterId']?.toString() ??
              '',
        };
      }).toList();

      loadedClasses.sort(
        (a, b) => a['section']
            .toString()
            .compareTo(
              b['section'].toString(),
            ),
      );

      if (!mounted) return;

      setState(() {
        _classes = loadedClasses;
        _loading = false;
      });
    } catch (e) {
      debugPrint(
        "Load classes error: $e",
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "Could not load classes: $e",
          ),
        ),
      );
    }
  }

  // ============================================================
  // CLASS TYPE SELECTION
  // ============================================================

  void _showClassTypeOptions(
    BuildContext context,
    Map<String, dynamic> classData,
  ) {
    showModalBottomSheet(
      context: context,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Padding(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            30,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Container(
                width: 45,
                height: 5,
                decoration:
                    BoxDecoration(
                  color:
                      Colors.grey.shade400,
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              Text(
                classData['className'],
                style:
                    const TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 5,
              ),

              Text(
                "${classData['students']} Students • "
                "${classData['subject']}",
                style:
                    const TextStyle(
                  color: Colors.grey,
                  fontSize: 15,
                ),
              ),

              const SizedBox(
                height: 25,
              ),

              const Align(
                alignment:
                    Alignment.centerLeft,
                child: Text(
                  "Select Class Type",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(
                height: 15,
              ),

              // ==================================================
              // NORMAL CLASS
              // ==================================================

              SizedBox(
                width:
                    double.infinity,
                child: Card(
                  elevation: 2,
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                    onTap: () {
                      Navigator.pop(
                        context,
                      );

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              GenerateQrScreen(
                            className:
                                classData[
                                    'className'],
                            students:
                                classData[
                                    'students'],
                            subject:
                                classData[
                                    'subject'],
                            classType:
                                "normal",
                            maxDistance:
                                30,
                            department:
                                classData[
                                    'department'],
                            year:
                                classData[
                                    'year'],
                            section:
                                classData[
                                    'section'],
                            rosterId:
                                classData[
                                    'rosterId'],
                          ),
                        ),
                      );
                    },
                    child: const Padding(
                      padding:
                          EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Icon(
                            Icons.school,
                            size: 32,
                            color:
                                Colors.blue,
                          ),

                          SizedBox(
                            width: 16,
                          ),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  "Normal Class",
                                  style:
                                      TextStyle(
                                    fontSize:
                                        18,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                                SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  "Standard attendance distance • 30 m",
                                  style:
                                      TextStyle(
                                    color:
                                        Colors
                                            .grey,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Icon(
                            Icons
                                .arrow_forward_ios,
                            size: 17,
                            color:
                                Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              // ==================================================
              // AUDITORIUM
              // ==================================================

              SizedBox(
                width:
                    double.infinity,
                child: Card(
                  elevation: 2,
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                    onTap: () {
                      Navigator.pop(
                        context,
                      );

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              GenerateQrScreen(
                            className:
                                classData[
                                    'className'],
                            students:
                                classData[
                                    'students'],
                            subject:
                                classData[
                                    'subject'],
                            classType:
                                "auditorium",
                            maxDistance:
                                60,
                            department:
                                classData[
                                    'department'],
                            year:
                                classData[
                                    'year'],
                            section:
                                classData[
                                    'section'],
                            rosterId:
                                classData[
                                    'rosterId'],
                          ),
                        ),
                      );
                    },
                    child: const Padding(
                      padding:
                          EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Icon(
                            Icons
                                .account_balance,
                            size: 32,
                            color:
                                Colors.orange,
                          ),

                          SizedBox(
                            width: 16,
                          ),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  "Auditorium",
                                  style:
                                      TextStyle(
                                    fontSize:
                                        18,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                                SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  "Higher attendance distance • 60 m",
                                  style:
                                      TextStyle(
                                    color:
                                        Colors
                                            .grey,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Icon(
                            Icons
                                .arrow_forward_ios,
                            size: 17,
                            color:
                                Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 10,
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // ATTENDANCE METHOD
  // ============================================================

  void _showAttendanceOptions(
    BuildContext context,
    Map<String, dynamic> classData,
  ) {
    showModalBottomSheet(
      context: context,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Padding(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            30,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Container(
                width: 45,
                height: 5,
                decoration:
                    BoxDecoration(
                  color:
                      Colors.grey.shade400,
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              Text(
                classData['className'],
                style:
                    const TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 5,
              ),

              Text(
                "${classData['students']} Students • "
                "${classData['subject']}",
                style:
                    const TextStyle(
                  color: Colors.grey,
                  fontSize: 15,
                ),
              ),

              const SizedBox(
                height: 25,
              ),

              const Align(
                alignment:
                    Alignment.centerLeft,
                child: Text(
                  "Select Attendance Method",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(
                height: 15,
              ),

              // ==================================================
              // GENERATE QR
              // ==================================================

              SizedBox(
                width:
                    double.infinity,
                child: Card(
                  elevation: 2,
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                    onTap: () {
                      Navigator.pop(
                        context,
                      );

                      _showClassTypeOptions(
                        context,
                        classData,
                      );
                    },
                    child: const Padding(
                      padding:
                          EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Icon(
                            Icons.qr_code_2,
                            size: 32,
                            color:
                                Colors.blue,
                          ),

                          SizedBox(
                            width: 16,
                          ),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  "Generate QR",
                                  style:
                                      TextStyle(
                                    fontSize:
                                        18,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                                SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  "Take attendance using QR code",
                                  style:
                                      TextStyle(
                                    color:
                                        Colors
                                            .grey,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Icon(
                            Icons
                                .arrow_forward_ios,
                            size: 17,
                            color:
                                Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              // ==================================================
              // MANUAL ATTENDANCE
              // ==================================================

              SizedBox(
                width:
                    double.infinity,
                child: Card(
                  elevation: 2,
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                    onTap: () {
                      Navigator.pop(
                        context,
                      );

                      final students =
                          List.generate(
                        classData[
                            "students"],
                        (index) => {
                          "rollNo":
                              "2405${(index + 1).toString().padLeft(3, '0')}",
                          "name":
                              "Student ${index + 1}",
                        },
                      );

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ManualAttendanceScreen(
                            className:
                                classData[
                                    "className"],
                            subject:
                                classData[
                                    "subject"],
                            students:
                                students,
                          ),
                        ),
                      );
                    },
                    child: const Padding(
                      padding:
                          EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_note,
                            size: 32,
                            color:
                                Colors.green,
                          ),

                          SizedBox(
                            width: 16,
                          ),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  "Manual Attendance",
                                  style:
                                      TextStyle(
                                    fontSize:
                                        18,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                                SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  "Mark students manually",
                                  style:
                                      TextStyle(
                                    color:
                                        Colors
                                            .grey,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Icon(
                            Icons
                                .arrow_forward_ios,
                            size: 17,
                            color:
                                Colors.grey,
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
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${widget.category} Classes",
        ),
        centerTitle: true,
      ),

      body: Padding(
        padding:
            const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            Text(
              "${widget.category} Classes",
              style: const TextStyle(
                fontSize: 26,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            const Text(
              "Select a class to take attendance.",
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
            ),

            const SizedBox(
              height: 25,
            ),

            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(),
                    )
                  : _classes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize:
                                MainAxisSize.min,
                            children: [
                              Icon(
                                Icons
                                    .class_outlined,
                                size: 60,
                                color:
                                    Colors
                                        .grey
                                        .shade400,
                              ),

                              const SizedBox(
                                height: 15,
                              ),

                              Text(
                                "No ${widget.category} classes added.",
                                style:
                                    const TextStyle(
                                  fontSize:
                                      17,
                                  color:
                                      Colors
                                          .grey,
                                ),
                                textAlign:
                                    TextAlign
                                        .center,
                              ),

                              const SizedBox(
                                height: 6,
                              ),

                              const Text(
                                "Add a class from the Teacher Dashboard.",
                                style:
                                    TextStyle(
                                  color:
                                      Colors
                                          .grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh:
                              _loadClasses,
                          child:
                              ListView.builder(
                            itemCount:
                                _classes.length,
                            itemBuilder:
                                (context,
                                    index) {
                              final classData =
                                  _classes[
                                      index];

                              return _ClassCard(
                                className:
                                    classData[
                                        "className"],
                                students:
                                    classData[
                                        "students"],
                                subject:
                                    classData[
                                        "subject"],
                                year:
                                    classData[
                                        "year"],
                                section:
                                    classData[
                                        "section"],
                                onTap: () {
                                  _showAttendanceOptions(
                                    context,
                                    classData,
                                  );
                                },
                              );
                            },
                          ),
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

class _ClassCard
    extends StatelessWidget {
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
  Widget build(
    BuildContext context,
  ) {
    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 16,
      ),
      elevation: 3,
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration:
                        BoxDecoration(
                      color: Colors.blue
                          .withValues(
                        alpha: 0.12,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                    child: const Icon(
                      Icons.groups,
                      color:
                          Colors.blue,
                      size: 28,
                    ),
                  ),

                  const SizedBox(
                    width: 14,
                  ),

                  Expanded(
                    child: Text(
                      className,
                      style:
                          const TextStyle(
                        fontSize: 21,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),

                  const Icon(
                    Icons
                        .arrow_forward_ios,
                    size: 18,
                    color:
                        Colors.grey,
                  ),
                ],
              ),

              const SizedBox(
                height: 18,
              ),

              Row(
                children: [
                  const Icon(
                    Icons.people,
                    size: 20,
                    color:
                        Colors.grey,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Text(
                    "$students Students",
                  ),
                ],
              ),

              const SizedBox(
                height: 8,
              ),

              Row(
                children: [
                  const Icon(
                    Icons.menu_book,
                    size: 20,
                    color:
                        Colors.grey,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Expanded(
                    child:
                        Text(subject),
                  ),
                ],
              ),

              const SizedBox(
                height: 8,
              ),

              Row(
                children: [
                  const Icon(
                    Icons.school,
                    size: 20,
                    color:
                        Colors.grey,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Text(
                    "$year • Section $section",
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