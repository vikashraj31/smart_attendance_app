import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/add_class_screen.dart';
import '../screens/class_list_screen.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() =>
      _TeacherDashboardState();
}

class _TeacherDashboardState
    extends State<TeacherDashboard> {
  bool _loading = true;

  List<Map<String, dynamic>> _classes = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  // ============================================================
  // LOAD TEACHER CLASSES
  // ============================================================

  Future<void> _loadClasses() async {
    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception(
          'Teacher is not logged in.',
        );
      }

      final snapshot =
          await FirebaseFirestore.instance
              .collection('teacher_classes')
              .where(
                'teacherId',
                isEqualTo: user.uid,
              )
              .get();

      final loadedClasses =
          snapshot.docs.map((doc) {
        final data = doc.data();

        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _classes = loadedClasses;
        _loading = false;
      });
    } catch (e) {
      debugPrint(
        'Load teacher classes error: $e',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Could not load your classes.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // ADD CLASS
  // ============================================================

  Future<void> _openAddClass() async {
    final result =
        await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const AddClassScreen(),
      ),
    );

    if (result == true) {
      await _loadClasses();
    }
  }

  // ============================================================
  // OPEN DEPARTMENT
  // ============================================================

  Future<void> _openDepartment(
    String department,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ClassListScreen(
          category: department,
        ),
      ),
    );

    await _loadClasses();
  }

  // ============================================================
  // GET DEPARTMENT SUMMARY
  // ============================================================

  List<Map<String, dynamic>>
      get _departments {
    final Map<String, int> counts = {};

    for (final classData in _classes) {
      final department =
          classData['department']
              ?.toString()
              .trim();

      if (department == null ||
          department.isEmpty) {
        continue;
      }

      counts[department] =
          (counts[department] ?? 0) + 1;
    }

    final result =
        counts.entries.map((entry) {
      return {
        'name': entry.key,
        'classCount': entry.value,
      };
    }).toList();

    result.sort(
      (a, b) => a['name']
          .toString()
          .compareTo(
            b['name'].toString(),
          ),
    );

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final departments = _departments;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Teacher Dashboard",
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
            const Text(
              "Your Classes",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "Select a department to view your classes.",
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 25),

            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(),
                    )
                  : departments.isEmpty
                      ? const Center(
                          child: Text(
                            "No classes added yet.\n"
                            "Add your first class below.",
                            textAlign:
                                TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount:
                              departments.length,
                          itemBuilder:
                              (context, index) {
                            final department =
                                departments[index];

                            return _DepartmentCard(
                              name:
                                  department['name'],
                              classCount:
                                  department[
                                      'classCount'],
                              onTap: () {
                                _openDepartment(
                                  department[
                                      'name'],
                                );
                              },
                            );
                          },
                        ),
            ),

            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              height: 58,
              child:
                  ElevatedButton.icon(
                onPressed:
                    _openAddClass,
                icon: const Icon(
                  Icons.add,
                  size: 26,
                ),
                label: const Text(
                  "Add New Class",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
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

// ============================================================
// DEPARTMENT CARD
// ============================================================

class _DepartmentCard
    extends StatelessWidget {
  final String name;
  final int classCount;
  final VoidCallback onTap;

  const _DepartmentCard({
    required this.name,
    required this.classCount,
    required this.onTap,
  });

  IconData get _icon {
    switch (name.toUpperCase()) {
      case 'CSE':
      case 'CSCE':
      case 'CSSE':
        return Icons.computer;

      case 'IT':
        return Icons.laptop;

      case 'ECE':
      case 'EEE':
        return Icons.electrical_services;

      case 'MECHANICAL':
        return Icons.precision_manufacturing;

      case 'CIVIL':
        return Icons.engineering;

      default:
        return Icons.school;
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 15,
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
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration:
                    BoxDecoration(
                  color: Colors.blue
                      .withValues(
                    alpha: 0.12,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  _icon,
                  color: Colors.blue,
                  size: 32,
                ),
              ),

              const SizedBox(
                width: 16,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style:
                          const TextStyle(
                        fontSize: 21,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      classCount == 1
                          ? "1 Class"
                          : "$classCount Classes",
                      style:
                          const TextStyle(
                        fontSize: 15,
                        color:
                            Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}