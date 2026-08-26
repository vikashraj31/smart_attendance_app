import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../dashboards/mentor_dashboard.dart';
import '../dashboards/student_dashboard.dart';
import '../dashboards/teacher_dashboard.dart';
import '../services/auth_service.dart';
import 'role_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  // ============================================================
  // GOOGLE SIGN-IN
  // ============================================================

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCredential =
          await AuthService.instance.signInWithGoogle();

      final user = userCredential?.user;

      if (user == null) {
        _fail(
          'Sign-in failed. Please try again.',
        );
        return;
      }

      // ========================================================
      // GET EXISTING ROLE
      // ========================================================

      final role =
          await AuthService.instance.getUserRole();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

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

      // ========================================================
      // MENTOR
      // ========================================================

      if (role == 'mentor') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                const MentorDashboard(),
          ),
        );
        return;
      }

      // ========================================================
      // NEW ACCOUNT / NO ROLE
      // ========================================================

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              const RoleSelectionScreen(),
        ),
      );
    } on GoogleSignInException catch (e) {
      if (e.code ==
          GoogleSignInExceptionCode.canceled) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      _fail(
        'Google Sign-In error: '
        '${e.description ?? e.code}',
      );
    } on FirebaseAuthException catch (e) {
      _fail(
        e.message ??
            'Authentication error. Please try again.',
      );
    } catch (e) {
      _fail(
        'Something went wrong. '
        'Please try again.\n$e',
      );
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _fail(String message) {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  // ============================================================
  // UI
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
                Icons.school,
                size: 90,
                color: Colors.blue,
              ),

              const SizedBox(height: 20),

              const Text(
                'Smart Attendance',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Login to continue',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 40),

              // ==================================================
              // ERROR MESSAGE
              // ==================================================

              if (_errorMessage != null) ...[
                Container(
                  padding:
                      const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius:
                        BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color:
                            Colors.red.shade400,
                        size: 20,
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color:
                                Colors.red.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],

              // ==================================================
              // LOGIN BUTTON
              // ==================================================

              SizedBox(
                width: double.infinity,
                height: 55,
                child: _isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(),
                      )
                    : ElevatedButton.icon(
                        onPressed:
                            _handleGoogleSignIn,
                        icon:
                            const Icon(Icons.login),
                        label: const Text(
                          'Login with Google',
                          style: TextStyle(
                            fontSize: 18,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}