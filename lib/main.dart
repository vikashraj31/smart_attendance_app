import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'dashboards/student_dashboard.dart';
import 'dashboards/teacher_dashboard.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Required by google_sign_in v7.
  await AuthService.instance.initialize();

  runApp(const SmartAttendanceApp());
}

class SmartAttendanceApp extends StatelessWidget {
  const SmartAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const AuthGate(),
    );
  }
}

// ============================================================
// AUTH GATE
// ============================================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        // ------------------------------------------------------
        // Firebase is checking login state
        // ------------------------------------------------------

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // ------------------------------------------------------
        // User is NOT logged in
        // ------------------------------------------------------

        if (!snapshot.hasData ||
            snapshot.data == null) {
          return const LoginScreen();
        }

        // ------------------------------------------------------
        // User IS logged in
        // ------------------------------------------------------

        return const RoleBasedHome();
      },
    );
  }
}

// ============================================================
// ROLE BASED HOME
// ============================================================

class RoleBasedHome extends StatefulWidget {
  const RoleBasedHome({super.key});

  @override
  State<RoleBasedHome> createState() =>
      _RoleBasedHomeState();
}

class _RoleBasedHomeState
    extends State<RoleBasedHome> {
  late Future<String?> _roleFuture;

  @override
  void initState() {
    super.initState();

    _roleFuture =
        AuthService.instance.getUserRole();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _roleFuture,
      builder: (context, snapshot) {
        // ------------------------------------------------------
        // Loading role
        // ------------------------------------------------------

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // ------------------------------------------------------
        // Error
        // ------------------------------------------------------

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
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

                    const Text(
                      'Could not load your account.',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _roleFuture =
                              AuthService
                                  .instance
                                  .getUserRole();
                        });
                      },
                      child:
                          const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final role = snapshot.data;

        // ------------------------------------------------------
        // No role assigned yet
        // ------------------------------------------------------

        if (role == null ||
            role.isEmpty) {
          return const LoginScreen();
        }

        // ------------------------------------------------------
        // STUDENT
        // ------------------------------------------------------

        if (role == 'student') {
          return const StudentDashboard();
        }

        // ------------------------------------------------------
        // TEACHER
        // ------------------------------------------------------

        if (role == 'teacher') {
          return const TeacherDashboard();
        }

        // ------------------------------------------------------
        // UNKNOWN ROLE
        // ------------------------------------------------------

        return Scaffold(
          body: Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(24),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 60,
                    color: Colors.orange,
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  Text(
                    'Unknown account role: $role',
                    textAlign:
                        TextAlign.center,
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  ElevatedButton(
                    onPressed: () async {
                      await AuthService
                          .instance
                          .signOut();
                    },
                    child:
                        const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}