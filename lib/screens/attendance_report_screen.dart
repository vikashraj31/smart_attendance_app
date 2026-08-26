import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class AttendanceReportScreen extends StatefulWidget {
  final String sessionId;
  final String department;
  final String year;
  final String section;
  final String className;
  final String subject;
  final int maxDistance;

  const AttendanceReportScreen({
    super.key,
    required this.sessionId,
    required this.department,
    required this.year,
    required this.section,
    required this.className,
    required this.subject,
    required this.maxDistance,
  });

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _exporting = false;

  String? _error;

  List<Map<String, dynamic>> students = [];

  String get rosterId {
    return '${widget.department}_${widget.year}_${widget.section}'
        .replaceAll(' ', '_')
        .toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    loadReport();
  }

  // ============================================================
  // LOAD REPORT
  // ============================================================

  Future<void> loadReport() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final firestore = FirebaseFirestore.instance;

      // ----------------------------------------------------------
      // LOAD ROSTER
      // ----------------------------------------------------------

      final rosterSnapshot = await firestore
          .collection('student_rosters')
          .doc(rosterId)
          .collection('students')
          .get();

      // ----------------------------------------------------------
      // LOAD ATTENDANCE
      // ----------------------------------------------------------

      final attendanceSnapshot = await firestore
          .collection('attendance_sessions')
          .doc(widget.sessionId)
          .collection('attendance')
          .get();

      final Map<String, Map<String, dynamic>> attendanceMap = {};

      for (final doc in attendanceSnapshot.docs) {
        attendanceMap[doc.id] = doc.data();
      }

      // ----------------------------------------------------------
      // BUILD STUDENT LIST
      // ----------------------------------------------------------

      final List<Map<String, dynamic>> result = [];

      for (final studentDoc in rosterSnapshot.docs) {
        final student = studentDoc.data();

        final rollNo = student['rollNo']?.toString() ?? '';

        final name = student['name']?.toString() ?? '';

        final email = student['email']?.toString() ?? '';

        Map<String, dynamic>? attendance;
        String? attendanceDocId;

        // --------------------------------------------------------
        // MATCH BY ROLL NUMBER
        // --------------------------------------------------------

        if (rollNo.isNotEmpty && attendanceMap.containsKey(rollNo)) {
          attendance = attendanceMap[rollNo];
          attendanceDocId = rollNo;
        }

        // --------------------------------------------------------
        // OLD DOCUMENT ID
        // --------------------------------------------------------

        if (attendance == null && attendanceMap.containsKey(studentDoc.id)) {
          attendance = attendanceMap[studentDoc.id];
          attendanceDocId = studentDoc.id;
        }

        // --------------------------------------------------------
        // FALLBACK MATCH
        // --------------------------------------------------------

        if (attendance == null) {
          for (final entry in attendanceMap.entries) {
            final data = entry.value;

            final attendanceRoll = data['rollNo']?.toString() ?? '';

            final attendanceEmail = data['studentEmail']?.toString() ?? '';

            final attendanceName = data['studentName']?.toString() ?? '';

            if (rollNo.isNotEmpty && attendanceRoll == rollNo) {
              attendance = data;
              attendanceDocId = entry.key;
              break;
            }

            if (email.isNotEmpty && attendanceEmail == email) {
              attendance = data;
              attendanceDocId = entry.key;
              break;
            }

            if (name.isNotEmpty && attendanceName == name) {
              attendance = data;
              attendanceDocId = entry.key;
              break;
            }
          }
        }

        // --------------------------------------------------------
        // AUTOMATIC PRESENT
        // --------------------------------------------------------

        final autoPresent =
            attendance != null &&
            (attendance['present'] == true ||
                attendance['status']?.toString().toLowerCase() == 'present');

        // --------------------------------------------------------
        // DISTANCE
        // --------------------------------------------------------

        int? distance;

        final distanceValue = attendance?['distance'];

        if (distanceValue is num) {
          distance = distanceValue.round();
        }

        // --------------------------------------------------------
        // RULE BREAK
        // --------------------------------------------------------

        final ruleBreak = distance != null && distance > widget.maxDistance;

        // --------------------------------------------------------
        // INITIAL PRESENT STATUS
        // --------------------------------------------------------

        final initialPresent = ruleBreak ? false : autoPresent;

        result.add({
          'studentDocId': studentDoc.id,
          'rollNo': rollNo,
          'name': name,
          'email': email,

          'present': initialPresent,

          'autoPresent': autoPresent,

          'manualPresent': false,

          'distance': distance,

          'ruleBreak': ruleBreak,

          'attendanceData': attendance,

          'attendanceDocId': attendanceDocId,
        });
      }

      // ----------------------------------------------------------
      // SORT BY ROLL NUMBER
      // ----------------------------------------------------------

      result.sort((a, b) {
        final aRoll = a['rollNo'].toString();

        final bRoll = b['rollNo'].toString();

        final aNumber = int.tryParse(aRoll);

        final bNumber = int.tryParse(bRoll);

        if (aNumber != null && bNumber != null) {
          return aNumber.compareTo(bNumber);
        }

        return aRoll.compareTo(bRoll);
      });

      if (!mounted) return;

      setState(() {
        students = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // ============================================================
  // TOGGLE ATTENDANCE
  // ============================================================

  void toggleAttendance(int index) {
    final student = students[index];

    final current = student['present'] == true;

    final newValue = !current;

    setState(() {
      student['present'] = newValue;
      student['manualPresent'] = true;
    });
  }

  // ============================================================
  // SAVE ATTENDANCE
  // ============================================================

  Future<void> saveAttendance() async {
    if (_saving) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Save Attendance'),
          content: const Text(
            'Present students will be saved as Present.\n'
            'Students left Absent will remain Absent.\n\n'
            'After saving, this attendance session will end.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _saving = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      final attendanceCollection = firestore
          .collection('attendance_sessions')
          .doc(widget.sessionId)
          .collection('attendance');

      final batch = firestore.batch();

      for (final student in students) {
        final rollNo = student['rollNo'].toString();

        if (rollNo.isEmpty) continue;

        final present = student['present'] == true;

        final docRef = attendanceCollection.doc(rollNo);

        final oldData = student['attendanceData'];

        // ========================================================
        // PRESENT
        // ========================================================

        if (present) {
          final data = <String, dynamic>{
            'rollNo': rollNo,

            'studentName': student['name'].toString(),

            'studentEmail': student['email'].toString(),

            'present': true,

            'status': 'present',

            'manuallyMarked': student['manualPresent'] == true,

            'updatedAt': FieldValue.serverTimestamp(),
          };

          // ------------------------------------------------------
          // PRESERVE OLD ATTENDANCE DATA
          // ------------------------------------------------------

          if (oldData is Map<String, dynamic>) {
            const keys = [
              'studentId',
              'distance',
              'withinDistance',
              'ruleBreak',
              'ruleBreakReason',
              'studentLatitude',
              'studentLongitude',
              'markedAt',
              'autoPresent',
            ];

            for (final key in keys) {
              if (oldData[key] != null) {
                data[key] = oldData[key];
              }
            }
          }

          // ------------------------------------------------------
          // MANUAL OVERRIDE
          // ------------------------------------------------------

          if (student['manualPresent'] == true) {
            data['manuallyMarked'] = true;

            data['manualOverride'] = true;
          }

          batch.set(docRef, data, SetOptions(merge: true));

          // ------------------------------------------------------
          // DELETE OLD DOCUMENT ID
          // ------------------------------------------------------

          final oldDocId = student['attendanceDocId'];

          if (oldDocId != null &&
              oldDocId.toString().isNotEmpty &&
              oldDocId.toString() != rollNo) {
            batch.delete(attendanceCollection.doc(oldDocId.toString()));
          }
        }
        // ========================================================
        // ABSENT
        // ========================================================
        else {
          batch.delete(docRef);

          final oldDocId = student['attendanceDocId'];

          if (oldDocId != null &&
              oldDocId.toString().isNotEmpty &&
              oldDocId.toString() != rollNo) {
            batch.delete(attendanceCollection.doc(oldDocId.toString()));
          }
        }
      }

      // ==========================================================
      // FINALIZE SESSION
      // ==========================================================

      final sessionRef = firestore
          .collection('attendance_sessions')
          .doc(widget.sessionId);

      final finalPresentCount = students
          .where((student) => student['present'] == true)
          .length;

      final finalAbsentCount = students.length - finalPresentCount;

      batch.set(sessionRef, {
        'active': false,
        'attendanceFinalized': true,
        'totalStudents': students.length,
        'presentCount': finalPresentCount,
        'absentCount': finalAbsentCount,
        'finalizedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance saved successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save attendance: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // EXPORT EXCEL
  // ============================================================

  Future<void> exportExcel() async {
    if (_exporting || students.isEmpty) {
      return;
    }

    setState(() {
      _exporting = true;
    });

    try {
      final excel = Excel.createExcel();

      final sheet = excel['Attendance'];

      // ==========================================================
      // DATE
      // ==========================================================

      final now = DateTime.now();

      final date =
          '${now.day.toString().padLeft(2, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.year}';

      // ==========================================================
      // HEADER
      // ==========================================================

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .value = TextCellValue(
        'Roll No.',
      );

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
          .value = TextCellValue(
        'Student Name',
      );

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0))
          .value = TextCellValue(
        date,
      );

      // ==========================================================
      // STUDENTS
      // ==========================================================

      for (int i = 0; i < students.length; i++) {
        final student = students[i];

        final row = i + 1;

        final rollNo = student['rollNo']?.toString() ?? '';

        final name = student['name']?.toString() ?? '';

        final present = student['present'] == true;

        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = TextCellValue(
          rollNo,
        );

        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .value = TextCellValue(
          name,
        );

        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
            .value = TextCellValue(
          present ? 'Present' : 'Absent',
        );
      }

      // ==========================================================
      // COLUMN WIDTH
      // ==========================================================

      sheet.setColumnWidth(0, 18);
      sheet.setColumnWidth(1, 30);
      sheet.setColumnWidth(2, 18);

      // ==========================================================
      // REMOVE DEFAULT SHEET
      // ==========================================================

      if (excel.sheets.containsKey('Sheet1') && excel.sheets.length > 1) {
        excel.delete('Sheet1');
      }

      // ==========================================================
      // ENCODE
      // ==========================================================

      final encoded = excel.encode();

      if (encoded == null) {
        throw Exception('Could not create Excel file.');
      }

      // List<int> -> Uint8List
      final fileBytes = Uint8List.fromList(encoded);

      // ==========================================================
      // FILE NAME
      // ==========================================================

      final fileName =
          'Attendance_${widget.className.replaceAll(' ', '_')}_$date.xlsx';

      // ==========================================================
      // SHARE / SAVE
      // ==========================================================

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              fileBytes,
              name: fileName,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
          ],
          subject: 'Attendance - $date',
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Excel attendance file is ready.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not create Excel file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  // ============================================================
  // COUNTS
  // ============================================================

  int get presentCount {
    return students.where((student) => student['present'] == true).length;
  }

  int get absentCount {
    return students.length - presentCount;
  }

  int get ruleBreakCount {
    return students.where((student) {
      final distance = student['distance'];

      return distance != null && distance > widget.maxDistance;
    }).length;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Report'), centerTitle: true),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),

              const SizedBox(height: 15),

              const Text(
                'Could not load attendance report',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              Text(_error!, textAlign: TextAlign.center),

              const SizedBox(height: 20),

              ElevatedButton(onPressed: loadReport, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // ========================================================
        // CLASS HEADER
        // ========================================================
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                widget.className,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                widget.subject,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),

              const SizedBox(height: 4),

              Text(
                '${widget.department} • '
                '${widget.year} • '
                'Section ${widget.section}',
                style: const TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 15),

              // ==================================================
              // SUMMARY
              // ==================================================
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Present',
                      value: '$presentCount',
                      color: Colors.green,
                      icon: Icons.check_circle,
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: _SummaryCard(
                      title: 'Absent',
                      value: '$absentCount',
                      color: Colors.red,
                      icon: Icons.cancel,
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: _SummaryCard(
                      title: 'Rule Break',
                      value: '$ruleBreakCount',
                      color: Colors.orange,
                      icon: Icons.warning,
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: _SummaryCard(
                      title: 'Total',
                      value: '${students.length}',
                      color: Colors.blue,
                      icon: Icons.people,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ========================================================
        // STUDENT LIST
        // ========================================================
        Expanded(
          child: students.isEmpty
              ? const Center(child: Text('No students found.'))
              : RefreshIndicator(
                  onRefresh: loadReport,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];

                      final present = student['present'] == true;

                      final distance = student['distance'];

                      final ruleBreak =
                          distance != null && distance > widget.maxDistance;

                      final manual = student['manualPresent'] == true;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        color: ruleBreak
                            ? Colors.orange.withValues(alpha: 0.08)
                            : null,
                        child: InkWell(
                          onTap: () => toggleAttendance(index),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                // ==========================================
                                // ROLL NUMBER
                                // ==========================================
                                Container(
                                  width: 50,
                                  height: 50,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: present
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    student['rollNo'].toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // ==========================================
                                // NAME + DETAILS
                                // ==========================================
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        student['name'].toString(),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(height: 5),

                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          if (distance != null)
                                            Text(
                                              '$distance m',
                                              style: TextStyle(
                                                color: ruleBreak
                                                    ? Colors.red
                                                    : Colors.grey,
                                                fontSize: 12,
                                                fontWeight: ruleBreak
                                                    ? FontWeight.bold
                                                    : null,
                                              ),
                                            ),

                                          Text(
                                            'Allowed ${widget.maxDistance} m',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 11,
                                            ),
                                          ),

                                          if (ruleBreak)
                                            const Text(
                                              'RULE BREAK',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),

                                          if (manual)
                                            const Text(
                                              'MANUAL',
                                              style: TextStyle(
                                                color: Colors.blue,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // ==========================================
                                // STATUS
                                // ==========================================
                                Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: present
                                            ? Colors.green.withValues(
                                                alpha: 0.1,
                                              )
                                            : Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        present ? 'Present' : 'Absent',
                                        style: TextStyle(
                                          color: present
                                              ? Colors.green
                                              : Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 4),

                                    const Text(
                                      'Tap to change',
                                      style: TextStyle(
                                        fontSize: 9,
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
                    },
                  ),
                ),
        ),

        // ========================================================
        // BUTTONS
        // ========================================================
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                // ==================================================
                // SAVE ATTENDANCE
                // ==================================================
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : saveAttendance,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _saving ? 'Saving...' : 'Save Attendance',
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ==================================================
                // DOWNLOAD EXCEL
                // ==================================================
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    onPressed: (_exporting || students.isEmpty)
                        ? null
                        : exportExcel,
                    icon: _exporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.table_chart),
                    label: Text(
                      _exporting ? 'Creating Excel...' : 'Download Excel',
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// SUMMARY CARD
// ================================================================

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),

            const SizedBox(height: 4),

            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            Text(
              title,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
