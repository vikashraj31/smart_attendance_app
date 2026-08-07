import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

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

  Future<void> _pickExcelFile() async {
    try {
      const XTypeGroup excelType = XTypeGroup(
        label: 'Excel',
        extensions: ['xlsx'],
      );

      final XFile? file = await openFile(
        acceptedTypeGroups: [excelType],
      );

      if (file != null) {
        setState(() {
          selectedFile = file;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
        ),
      );
    }
  }

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
          crossAxisAlignment: CrossAxisAlignment.start,
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
                          style: TextStyle(fontWeight: FontWeight.bold),
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
                          style: TextStyle(fontWeight: FontWeight.bold),
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
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(widget.section),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              "Upload Student List",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "Supported format: .xlsx",
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _pickExcelFile,
                icon: const Icon(Icons.upload_file),
                label: const Text(
                  "Choose Excel File",
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Center(
              child: Text(
                selectedFile == null
                    ? "No file selected"
                    : selectedFile!.name,
                style: TextStyle(
                  color: selectedFile == null
                      ? Colors.grey
                      : Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: selectedFile == null
                    ? null
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "${selectedFile!.name} selected successfully.",
                            ),
                          ),
                        );
                      },
                child: const Text(
                  "Continue",
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}