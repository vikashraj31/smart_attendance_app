import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FirebaseAuth get auth => _auth;

  /// Must be called once at app startup, before any sign-in attempt.
  Future<void> initialize() async {
    await _googleSignIn.initialize(
      serverClientId:
          '382821611392-2qt7c3iqe8ek6tcfdm2gm3f89ff0h0f2.apps.googleusercontent.com',
    );
  }

  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount account =
        await _googleSignIn.authenticate();

    final GoogleSignInAuthentication googleAuth =
        account.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get user's role from Firestore
  Future<String?> getUserRole() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      return null;
    }

    return doc.data()?['role'] as String?;
  }

  // Save user's role to Firestore
  Future<void> saveUserRole(String role) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(
      {
        'email': user.email,
        'name': user.displayName ?? '',
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}