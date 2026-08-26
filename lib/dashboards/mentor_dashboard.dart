import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MentorDashboard extends StatefulWidget {
  const MentorDashboard({super.key});

  @override
  State<MentorDashboard> createState() =>
      _MentorDashboardState();
}

class _MentorDashboardState
    extends State<MentorDashboard> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  bool _loading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _students = [];

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  // ============================================================
  // LOAD MENTOR STUDENTS
  // ============================================================

  Future<void> _loadStudents() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final mentor =
          _auth.currentUser;

      if (mentor == null) {
        throw Exception(
          'Mentor is not logged in.',
        );
      }

      final mentorId = mentor.uid;

      // --------------------------------------------------------
      // GET ALL ROSTERS BELONGING TO THIS MENTOR
      // --------------------------------------------------------

      final rosterSnapshot =
          await _firestore
              .collection('mentor_rosters')
              .where(
                'mentorId',
                isEqualTo: mentorId,
              )
              .get();

      final List<Map<String, dynamic>>
          students = [];

      // --------------------------------------------------------
      // LOAD STUDENTS FROM EACH CATEGORY
      // --------------------------------------------------------

      for (final rosterDoc
          in rosterSnapshot.docs) {
        final rosterData =
            rosterDoc.data();

        final category =
            rosterData['category']
                    ?.toString() ??
                'Unknown';

        final studentSnapshot =
            await _firestore
                .collection(
                  'mentor_rosters',
                )
                .doc(rosterDoc.id)
                .collection('students')
                .get();

        for (final studentDoc
            in studentSnapshot.docs) {
          final studentData =
              studentDoc.data();

          final rollNo =
              studentData['rollNo']
                      ?.toString() ??
                  '';

          final name =
              studentData['name']
                      ?.toString() ??
                  '';

          final email =
              studentData['email']
                      ?.toString() ??
                  '';

          final resetCount =
              (studentData[
                          'faceResetCount']
                      as num?)
                  ?.toInt() ??
              0;

          final studentUid =
              studentData['studentUid']
                      ?.toString() ??
                  studentData['uid']
                      ?.toString() ??
                  '';

          students.add({
            'studentDocId':
                studentDoc.id,
            'rosterId':
                rosterDoc.id,
            'category':
                category,
            'rollNo':
                rollNo,
            'name':
                name,
            'email':
                email,
            'studentUid':
                studentUid,
            'faceResetCount':
                resetCount,
          });
        }
      }

      // --------------------------------------------------------
      // SORT BY ROLL NUMBER
      // --------------------------------------------------------

      students.sort(
        (a, b) {
          final aRoll =
              a['rollNo'].toString();

          final bRoll =
              b['rollNo'].toString();

          return aRoll.compareTo(
            bRoll,
          );
        },
      );

      if (!mounted) return;

      setState(() {
        _students = students;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage =
            e.toString().replaceFirst(
                  'Exception: ',
                  '',
                );
      });
    }
  }

  // ============================================================
  // RESET FACE
  // ============================================================

  Future<void> _resetFace(
    Map<String, dynamic> student,
  ) async {
    final studentUid =
        student['studentUid']
            ?.toString()
            .trim();

    final rollNo =
        student['rollNo']
            ?.toString() ??
            '';

    final name =
        student['name']
            ?.toString() ??
            '';

    if (studentUid == null ||
        studentUid.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Student account UID is missing.',
          ),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // CONFIRMATION
    // ----------------------------------------------------------

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Reset Face Registration?',
          ),
          content: Text(
            'This will remove the current face '
            'registration for:\n\n'
            '$rollNo\n'
            '$name\n\n'
            'The student will be able to register '
            'their face again on a new device.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child:
                  const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child:
                  const Text('Reset Face'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      // --------------------------------------------------------
      // STUDENT FACE DATA
      // --------------------------------------------------------

      final faceRef =
          _firestore
              .collection('face_data')
              .doc(studentUid);

      // --------------------------------------------------------
      // STUDENT USER DATA
      // --------------------------------------------------------

      final userRef =
          _firestore
              .collection('users')
              .doc(studentUid);

      // --------------------------------------------------------
      // CURRENT RESET COUNT
      // --------------------------------------------------------

      final userDoc =
          await userRef.get();

      final userData =
          userDoc.data();

      final oldResetCount =
          (userData?[
                      'faceResetCount']
                  as num?)
              ?.toInt() ??
          (student['faceResetCount']
                  as num?)
              ?.toInt() ??
          0;

      final newResetCount =
          oldResetCount + 1;

      // --------------------------------------------------------
      // DELETE FACE
      // --------------------------------------------------------

      await faceRef.delete();

      // --------------------------------------------------------
      // UPDATE USER
      // --------------------------------------------------------

      await userRef.set(
        {
          'faceRegistered':
              false,
          'faceResetCount':
              newResetCount,
          'lastFaceResetAt':
              FieldValue
                  .serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      // --------------------------------------------------------
      // UPDATE MENTOR ROSTER
      // --------------------------------------------------------

      final rosterId =
          student['rosterId']
              ?.toString();

      final studentDocId =
          student['studentDocId']
              ?.toString();

      if (rosterId != null &&
          rosterId.isNotEmpty &&
          studentDocId != null &&
          studentDocId.isNotEmpty) {
        await _firestore
            .collection(
              'mentor_rosters',
            )
            .doc(rosterId)
            .collection('students')
            .doc(studentDocId)
            .set(
          {
            'faceResetCount':
                newResetCount,
          },
          SetOptions(
            merge: true,
          ),
        );
      }

      // --------------------------------------------------------
      // UPDATE SCREEN
      // --------------------------------------------------------

      if (!mounted) return;

      setState(() {
        student['faceResetCount'] =
            newResetCount;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Face reset successfully. '
            'Reset count: $newResetCount',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not reset face: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // FILTERED STUDENTS
  // ============================================================

  List<Map<String, dynamic>>
      get _filteredStudents {
    if (_searchQuery.trim().isEmpty) {
      return _students;
    }

    final query =
        _searchQuery.trim().toLowerCase();

    return _students.where(
      (student) {
        final rollNo =
            student['rollNo']
                .toString()
                .toLowerCase();

        final name =
            student['name']
                .toString()
                .toLowerCase();

        final category =
            student['category']
                .toString()
                .toLowerCase();

        return rollNo.contains(query) ||
            name.contains(query) ||
            category.contains(query);
      },
    ).toList();
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
        title:
            const Text('Mentor Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loadStudents,
            icon:
                const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red,
              ),

              const SizedBox(
                height: 16,
              ),

              Text(
                _errorMessage!,
                textAlign:
                    TextAlign.center,
              ),

              const SizedBox(
                height: 20,
              ),

              ElevatedButton.icon(
                onPressed:
                    _loadStudents,
                icon:
                    const Icon(Icons.refresh),
                label:
                    const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered =
        _filteredStudents;

    return Column(
      children: [
        // ========================================================
        // SUMMARY
        // ========================================================

        Padding(
          padding:
              const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  icon:
                      Icons.people,
                  title:
                      'Students',
                  value:
                      '${_students.length}',
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: _SummaryCard(
                  icon:
                      Icons.category,
                  title:
                      'Categories',
                  value:
                      '${_students.map(
                    (student) =>
                        student['category'],
                  ).toSet().length}',
                ),
              ),
            ],
          ),
        ),

        // ========================================================
        // SEARCH
        // ========================================================

        Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration:
                InputDecoration(
              hintText:
                  'Search roll no. or student name',
              prefixIcon:
                  const Icon(
                Icons.search,
              ),
              suffixIcon:
                  _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            setState(() {
                              _searchQuery =
                                  '';
                            });
                          },
                          icon:
                              const Icon(
                            Icons.clear,
                          ),
                        )
                      : null,
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        // ========================================================
        // STUDENT LIST
        // ========================================================

        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'No students found.',
                  ),
                )
              : RefreshIndicator(
                  onRefresh:
                      _loadStudents,
                  child:
                      ListView.builder(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 16,
                    ),
                    itemCount:
                        filtered.length,
                    itemBuilder:
                        (context, index) {
                      final student =
                          filtered[index];

                      return _StudentCard(
                        student:
                            student,
                        onReset: () =>
                            _resetFace(
                          student,
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ================================================================
// STUDENT CARD
// ================================================================

class _StudentCard
    extends StatelessWidget {
  final Map<String, dynamic> student;
  final VoidCallback onReset;

  const _StudentCard({
    required this.student,
    required this.onReset,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final rollNo =
        student['rollNo']
            ?.toString() ??
            '';

    final name =
        student['name']
            ?.toString() ??
            '';

    final category =
        student['category']
            ?.toString() ??
            '';

    final resetCount =
        (student['faceResetCount']
                as num?)
            ?.toInt() ??
        0;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Row(
          children: [
            // ====================================================
            // STUDENT ICON
            // ====================================================

            CircleAvatar(
              radius: 25,
              child: Text(
                name.isNotEmpty
                    ? name[0]
                        .toUpperCase()
                    : '?',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            // ====================================================
            // STUDENT DETAILS
            // ====================================================

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    name.isEmpty
                        ? 'Unknown Student'
                        : name,
                    style:
                        const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  Text(
                    'Roll No: $rollNo',
                    style:
                        const TextStyle(
                      color:
                          Colors.grey,
                    ),
                  ),

                  const SizedBox(
                    height: 3,
                  ),

                  Text(
                    category,
                    style:
                        const TextStyle(
                      color:
                          Colors.grey,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  Row(
                    children: [
                      const Icon(
                        Icons
                            .restart_alt,
                        size: 16,
                        color:
                            Colors.orange,
                      ),

                      const SizedBox(
                        width: 4,
                      ),

                      Text(
                        'Face Reset Count: '
                        '$resetCount',
                        style:
                            TextStyle(
                          fontSize: 12,
                          fontWeight:
                              FontWeight
                                  .w600,
                          color: resetCount >
                                  0
                              ? Colors
                                  .orange
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(
              width: 8,
            ),

            // ====================================================
            // RESET BUTTON
            // ====================================================

            OutlinedButton(
              onPressed: onReset,
              child:
                  const Text(
                'Reset Face',
                textAlign:
                    TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// SUMMARY CARD
// ================================================================

class _SummaryCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.blue,
              size: 30,
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    value,
                    style:
                        const TextStyle(
                      fontSize: 22,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  Text(
                    title,
                    style:
                        const TextStyle(
                      color:
                          Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}