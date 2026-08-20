import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

class UploadStudentListScreen extends StatefulWidget {
  final String department;
  final String year;
  final String section;

  const UploadStudentListScreen({
    super.key,
    required this.department,
    required this.year,
    required this.section,
  });

  @override
  State<UploadStudentListScreen> createState() =>
      _UploadStudentListScreenState();
}

class _UploadStudentListScreenState
    extends State<UploadStudentListScreen> {
  XFile? selectedFile;

  bool isReading = false;
  bool isSaving = false;

  List<Map<String, String>> students = [];

  // ============================================================
  // PICK EXCEL
  // ============================================================

  Future<void> _pickExcelFile() async {
    try {
      const XTypeGroup excelType = XTypeGroup(
        label: 'Excel',
        extensions: ['xlsx'],
      );

      final XFile? file = await openFile(
        acceptedTypeGroups: [excelType],
      );

      if (file == null) {
        return;
      }

      setState(() {
        selectedFile = file;
        students = [];
        isReading = true;
      });

      await _readExcelFile(file);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isReading = false;
        students = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
        ),
      );
    }
  }

  // ============================================================
  // READ EXCEL
  // ============================================================

  Future<void> _readExcelFile(XFile file) async {
    try {
      final bytes = await file.readAsBytes();

      final decoder = SpreadsheetDecoder.decodeBytes(bytes);

      if (decoder.tables.isEmpty) {
        throw Exception("No sheet found in Excel file.");
      }

      final String sheetName =
          decoder.tables.keys.first;

      final table = decoder.tables[sheetName];

      if (table == null) {
        throw Exception("Could not open Excel sheet.");
      }

      final rows = table.rows;

      if (rows.length < 2) {
        throw Exception(
          "Excel file must contain a header and at least one student.",
        );
      }

      final List<Map<String, String>> extractedStudents = [];

      // Row 0:
      // Roll No | Name

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];

        if (row.isEmpty) {
          continue;
        }

        String rollNo = "";
        String name = "";

        if (row.isNotEmpty && row[0] != null) {
          rollNo = row[0].toString().trim();
        }

        if (row.length > 1 && row[1] != null) {
          name = row[1].toString().trim();
        }

        // Skip incomplete rows.
        if (rollNo.isEmpty || name.isEmpty) {
          continue;
        }

        extractedStudents.add({
          "rollNo": rollNo,
          "name": name,
        });
      }

      if (extractedStudents.isEmpty) {
        throw Exception(
          "No valid students found in the Excel file.",
        );
      }

      if (!mounted) return;

      setState(() {
        students = extractedStudents;
        isReading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${extractedStudents.length} students loaded successfully.",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isReading = false;
        students = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Could not read Excel file: $e",
          ),
        ),
      );
    }
  }

  // ============================================================
  // SAVE STUDENT LIST TO FIRESTORE
  // ============================================================

  Future<void> _saveStudentsToFirebase() async {
    if (students.isEmpty) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final firestore =
          FirebaseFirestore.instance;

      // One roster document for this class/section.
      final rosterId =
          "${widget.department}_${widget.year}_${widget.section}"
              .replaceAll(' ', '_')
              .toLowerCase();

      final rosterRef = firestore
          .collection('student_rosters')
          .doc(rosterId);

      // Save class information.
      await rosterRef.set({
        'department': widget.department,
        'year': widget.year,
        'section': widget.section,
        'studentCount': students.length,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ========================================================
      // SAVE EACH STUDENT
      // ========================================================

      final batch = firestore.batch();

      for (final student in students) {
        final rollNo = student["rollNo"]!;
        final name = student["name"]!;

        // Use roll number as document ID.
        final studentRef = rosterRef
            .collection('students')
            .doc(rollNo);

        batch.set(
          studentRef,
          {
            'rollNo': rollNo,
            'name': name,
            'department': widget.department,
            'year': widget.year,
            'section': widget.section,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${students.length} students saved successfully.",
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Go back to previous screen.
      await Future.delayed(
        const Duration(milliseconds: 700),
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Could not save students: $e",
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload Student List"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Center(
              child: Icon(
                Icons.upload_file,
                size: 80,
                color: Colors.blue,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Class Details",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text(
                          "Department",
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(widget.department),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        const Text(
                          "Year",
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(widget.year),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        const Text(
                          "Section",
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(widget.section),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              "Upload Student List",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "Excel format: Roll No | Name",
              style: TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed:
                    isReading || isSaving
                        ? null
                        : _pickExcelFile,
                icon: const Icon(
                  Icons.upload_file,
                ),
                label: Text(
                  isReading
                      ? "Reading Excel..."
                      : "Choose Excel File",
                  style: const TextStyle(
                    fontSize: 18,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            if (selectedFile != null)
              Center(
                child: Text(
                  selectedFile!.name,
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),

            if (isReading) ...[
              const SizedBox(height: 20),
              const Center(
                child:
                    CircularProgressIndicator(),
              ),
            ],

            if (students.isNotEmpty) ...[
              const SizedBox(height: 20),

              Text(
                "Students Found: ${students.length}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: ListView.builder(
                  itemCount: students.length,
                  itemBuilder:
                      (context, index) {
                    final student =
                        students[index];

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            "${index + 1}",
                          ),
                        ),
                        title: Text(
                          student["name"]!,
                        ),
                        subtitle: Text(
                          "Roll No: ${student["rollNo"]}",
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              const Spacer(),
            ],

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed:
                    students.isEmpty ||
                            isSaving
                        ? null
                        : _saveStudentsToFirebase,
                child: isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Continue",
                        style: TextStyle(
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