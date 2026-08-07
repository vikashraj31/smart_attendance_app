import 'package:flutter/material.dart';

class AddClassScreen extends StatefulWidget {
  const AddClassScreen({super.key});

  @override
  State<AddClassScreen> createState() => _AddClassScreenState();
}

class _AddClassScreenState extends State<AddClassScreen> {
  String? selectedDepartment;
  String? selectedYear;
  String? selectedSection;

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
      List.generate(62, (index) => "${index + 1}");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Class"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "Department",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: selectedDepartment,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              hint: const Text("Select Department"),
              items: departments.map((department) {
                return DropdownMenuItem(
                  value: department,
                  child: Text(department),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedDepartment = value;
                });
              },
            ),

            const SizedBox(height: 25),

            const Text(
              "Year",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: selectedYear,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              hint: const Text("Select Year"),
              items: years.map((year) {
                return DropdownMenuItem(
                  value: year,
                  child: Text(year),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedYear = value;
                });
              },
            ),

            const SizedBox(height: 25),

            const Text(
              "Section",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: selectedSection,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              hint: const Text("Select Section"),
              items: sections.map((section) {
                return DropdownMenuItem(
                  value: section,
                  child: Text(section),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedSection = value;
                });
              },
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  if (selectedDepartment == null ||
                      selectedYear == null ||
                      selectedSection == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please select all fields."),
                      ),
                    );
                    return;
                  }

                  // Next Step
                  // Upload Student List Screen
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