import 'package:flutter/material.dart';

class ManualAttendanceScreen extends StatefulWidget {
  final String className;
  final String subject;
  final List<Map<String, String>> students;

  const ManualAttendanceScreen({
    super.key,
    required this.className,
    required this.subject,
    required this.students,
  });

  @override
  State<ManualAttendanceScreen> createState() =>
      _ManualAttendanceScreenState();
}

class _ManualAttendanceScreenState
    extends State<ManualAttendanceScreen> {
  late List<bool> attendance;

  @override
  void initState() {
    super.initState();

    // Initially every student is ABSENT.
    // Teacher clicks checkbox for students who are present.
    attendance = List<bool>.filled(
      widget.students.length,
      false,
    );
  }

  int get presentCount {
    return attendance.where((present) => present).length;
  }

  int get absentCount {
    return attendance.length - presentCount;
  }

  void _saveAttendance() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Attendance saved: "
          "$presentCount Present, "
          "$absentCount Absent",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manual Attendance"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ====================================================
          // CLASS INFORMATION
          // ====================================================

          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              10,
            ),
            child: Column(
              children: [
                Text(
                  widget.className,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  widget.subject,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          // ====================================================
          // PRESENT / ABSENT COUNT
          // ====================================================

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _CountCard(
                    title: "Present",
                    count: presentCount,
                    color: Colors.green,
                    icon: Icons.check_circle,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _CountCard(
                    title: "Absent",
                    count: absentCount,
                    color: Colors.red,
                    icon: Icons.cancel,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 5),

          // ====================================================
          // TABLE HEADER
          // ====================================================

          Container(
            color: Colors.grey.shade200,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Text(
                    "Roll No",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                Expanded(
                  child: Text(
                    "Name",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                SizedBox(
                  width: 70,
                  child: Center(
                    child: Text(
                      "Present",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ====================================================
          // STUDENT LIST
          // ====================================================

          Expanded(
            child: ListView.builder(
              itemCount: widget.students.length,
              itemBuilder: (context, index) {
                final student = widget.students[index];

                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade300,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        // Roll Number
                        SizedBox(
                          width: 70,
                          child: Text(
                            student["rollNo"] ?? "",
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        // Student Name
                        Expanded(
                          child: Text(
                            student["name"] ?? "",
                            style: const TextStyle(
                              fontSize: 15,
                            ),
                          ),
                        ),

                        // Checkbox
                        SizedBox(
                          width: 70,
                          child: Center(
                            child: Checkbox(
                              value: attendance[index],
                              activeColor: Colors.green,
                              onChanged: (value) {
                                setState(() {
                                  attendance[index] =
                                      value ?? false;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ====================================================
          // SAVE BUTTON
          // ====================================================

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _saveAttendance,
                  icon: const Icon(Icons.save),
                  label: const Text(
                    "Save Attendance",
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// COUNT CARD
// ============================================================

class _CountCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;

  const _CountCard({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 28,
          ),

          const SizedBox(width: 10),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Text(
                "$count",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}