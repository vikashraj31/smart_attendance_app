import 'package:flutter/material.dart';
import '../screens/add_class_screen.dart';
import '../screens/class_list_screen.dart';

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  // Temporary data.
  // Firebase integration baad me karenge.
  final List<Map<String, dynamic>> categories = const [
    {
      "name": "CSE",
      "classCount": 4,
      "icon": Icons.computer,
      "color": Colors.blue,
    },
    {
      "name": "IT",
      "classCount": 1,
      "icon": Icons.laptop,
      "color": Colors.green,
    },
    {
      "name": "Civil",
      "classCount": 2,
      "icon": Icons.engineering,
      "color": Colors.orange,
    },
  ];

  void _openAddClass(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddClassScreen()),
    );
  }

  void _openCategory(BuildContext context, String category, int classCount) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClassListScreen(category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Dashboard"), centerTitle: true),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              "Your Classes",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            const Text(
              "Select a department to view your classes.",
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),

            const SizedBox(height: 25),

            // ==================================================
            // CATEGORY LIST
            // ==================================================
            Expanded(
              child: ListView.builder(
                itemCount: categories.length,

                itemBuilder: (context, index) {
                  final category = categories[index];

                  return _CategoryCard(
                    name: category["name"],
                    classCount: category["classCount"],
                    icon: category["icon"],
                    color: category["color"],

                    onTap: () {
                      _openCategory(
                        context,
                        category["name"],
                        category["classCount"],
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 15),

            // ==================================================
            // ADD NEW CLASS
            // ==================================================
            SizedBox(
              width: double.infinity,
              height: 58,

              child: ElevatedButton.icon(
                onPressed: () {
                  _openAddClass(context);
                },

                icon: const Icon(Icons.add, size: 26),

                label: const Text(
                  "Add New Class",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
// CATEGORY CARD
// ============================================================

class _CategoryCard extends StatelessWidget {
  final String name;
  final int classCount;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.name,
    required this.classCount,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),

      elevation: 3,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,

        child: Padding(
          padding: const EdgeInsets.all(18),

          child: Row(
            children: [
              // =================================================
              // ICON
              // =================================================
              Container(
                width: 60,
                height: 60,

                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),

                child: Icon(icon, color: color, size: 32),
              ),

              const SizedBox(width: 16),

              // =================================================
              // TEXT
              // =================================================
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      classCount == 1 ? "1 Class" : "$classCount Classes",

                      style: const TextStyle(fontSize: 15, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              // =================================================
              // ARROW
              // =================================================
              const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
