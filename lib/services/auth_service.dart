import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  FirebaseAuth get auth => _auth;

  /// Must be called once at app startup, before any sign-in attempt.
  ///
  /// google_sign_in v7 requires serverClientId to be passed explicitly on
  /// Android. This is your Firebase project's Web client ID — find it in
  /// Firebase Console > Authentication > Sign-in method > Google > Web SDK
  /// configuration, or in android/app/google-services.json under the
  /// "client_type": 3 entry.
  Future<void> initialize() async {
    await _googleSignIn.initialize(
      serverClientId:
          '382821611392-2qt7c3iqe8ek6tcfdm2gm3f89ff0h0f2.apps.googleusercontent.com',
    );
  }

  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount account = await _googleSignIn.authenticate();

    final GoogleSignInAuthentication googleAuth =
        await account.authentication;

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
}