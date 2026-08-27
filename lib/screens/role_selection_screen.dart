import 'package:flutter/material.dart';

import '../dashboards/student_dashboard.dart';
import '../dashboards/teacher_dashboard.dart';
import '../services/auth_service.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState
    extends State<RoleSelectionScreen> {
  bool _isSaving = false;

  // ============================================================
  // SELECT ROLE
  // ============================================================

  Future<void> _selectRole(String role) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await AuthService.instance.saveUserRole(role);

      if (!mounted) return;

      // ========================================================
      // STUDENT
      // ========================================================

      if (role == 'student') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                const StudentDashboard(),
          ),
        );
        return;
      }

      // ========================================================
      // TEACHER
      // ========================================================

      if (role == 'teacher') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                const TeacherDashboard(),
          ),
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save role. Please try again.',
          ),
        ),
      );

      debugPrint(
        'Role save error: $e',
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person_search_rounded,
                size: 80,
                color: Colors.blue,
              ),

              const SizedBox(height: 20),

              const Text(
                'Who are you?',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Choose your role to continue',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 40),

              // ==================================================
              // STUDENT
              // ==================================================

              _RoleCard(
                icon: Icons.school,
                label: "I'm a Student",
                onTap: _isSaving
                    ? null
                    : () => _selectRole('student'),
              ),

              const SizedBox(height: 14),

              // ==================================================
              // TEACHER
              // ==================================================

              _RoleCard(
                icon: Icons.person,
                label: "I'm a Teacher",
                onTap: _isSaving
                    ? null
                    : () => _selectRole('teacher'),
              ),

              if (_isSaving) ...[
                const SizedBox(height: 30),
                const CircularProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// ROLE CARD
// ================================================================

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 20,
              horizontal: 20,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: Colors.blue,
                ),

                const SizedBox(width: 16),

                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const Spacer(),

                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}