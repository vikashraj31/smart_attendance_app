import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'face_matching_service.dart';

class AuthService {
  AuthService._();

  static final AuthService instance =
      AuthService._();

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final GoogleSignIn _googleSignIn =
      GoogleSignIn.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final DeviceInfoPlugin _deviceInfo =
      DeviceInfoPlugin();

  FirebaseAuth get auth => _auth;

  // ============================================================
  // GOOGLE SIGN-IN INITIALIZATION
  // ============================================================

  Future<void> initialize() async {
    await _googleSignIn.initialize(
      serverClientId:
          '382821611392-2qt7c3iqe8ek6tcfdm2gm3f89ff0h0f2.apps.googleusercontent.com',
    );
  }

  // ============================================================
  // GOOGLE SIGN-IN
  // ============================================================

  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount account =
        await _googleSignIn.authenticate();

    final GoogleSignInAuthentication googleAuth =
        account.authentication;

    final credential =
        GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(
      credential,
    );
  }

  // ============================================================
  // SIGN OUT
  // ============================================================

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ============================================================
  // CURRENT USER
  // ============================================================

  User? get currentUser =>
      _auth.currentUser;

  Stream<User?> get authStateChanges =>
      _auth.authStateChanges();

  // ============================================================
  // GET USER ROLE
  // ============================================================

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

  // ============================================================
  // GET STUDENT ROLL NUMBER
  // ============================================================

  Future<String?> getStudentRollNo() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    final email = user.email;

    if (email == null ||
        email.trim().isEmpty) {
      return null;
    }

    final parts =
        email.trim().split('@');

    if (parts.length != 2) {
      return null;
    }

    final rollNo =
        parts.first.trim();

    if (rollNo.isEmpty) {
      return null;
    }

    return rollNo;
  }

  // ============================================================
  // SAVE USER ROLE
  // ============================================================

  Future<void> saveUserRole(
    String role,
  ) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    final userRef =
        _firestore
            .collection('users')
            .doc(user.uid);

    final existingDoc =
        await userRef.get();

    if (existingDoc.exists &&
        existingDoc.data()?['role'] !=
            null) {
      throw Exception(
        'Role is already assigned.',
      );
    }

    final Map<String, dynamic>
        userData = {
      'email': user.email,
      'name':
          user.displayName ?? '',
      'fullName':
          user.displayName ?? '',
      'role': role,
      'createdAt':
          FieldValue.serverTimestamp(),
    };

    if (role == 'student') {
      final rollNo =
          await getStudentRollNo();

      if (rollNo == null ||
          rollNo.isEmpty) {
        throw Exception(
          'Could not determine student roll number.',
        );
      }

      userData['rollNo'] =
          rollNo;
    }

    await userRef.set(
      userData,
      SetOptions(merge: true),
    );
  }

  // ============================================================
  // DEVICE ID
  // ============================================================

  Future<String> getDeviceId() async {
    final androidInfo =
        await _deviceInfo.androidInfo;

    final deviceId =
        androidInfo.id.trim();

    if (deviceId.isEmpty) {
      throw Exception(
        'Could not identify this device.',
      );
    }

    return 'android_$deviceId';
  }

  // ============================================================
  // CHECK WHETHER CURRENT USER HAS A FACE
  // ============================================================

  Future<bool> isFaceRegistered() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    final doc = await _firestore
        .collection('face_data')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      return false;
    }

    final data = doc.data();

    return data != null &&
        data['embedding'] != null;
  }

  // ============================================================
  // CHECK CURRENT DEVICE
  // ============================================================

  Future<bool> isCurrentDeviceRegistered()
      async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    final faceDoc =
        await _firestore
            .collection('face_data')
            .doc(user.uid)
            .get();

    if (!faceDoc.exists) {
      return false;
    }

    final data =
        faceDoc.data();

    if (data == null) {
      return false;
    }

    final registeredDevice =
        data['deviceId']?.toString();

    if (registeredDevice == null ||
        registeredDevice.isEmpty) {
      return false;
    }

    final currentDevice =
        await getDeviceId();

    return registeredDevice ==
        currentDevice;
  }

  // ============================================================
  // CHECK IF THIS FACE IS ALREADY REGISTERED
  // ============================================================

  Future<bool> _isFaceAlreadyRegisteredByAnotherUser(
    List<double> newEmbedding,
  ) async {
    final currentUser =
        _auth.currentUser;

    if (currentUser == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    final snapshot =
        await _firestore
            .collection('face_data')
            .get();

    for (final doc
        in snapshot.docs) {
      // --------------------------------------------------------
      // Skip current user's own face.
      // --------------------------------------------------------

      if (doc.id ==
          currentUser.uid) {
        continue;
      }

      final data =
          doc.data();

      final rawEmbedding =
          data['embedding'];

      if (rawEmbedding == null) {
        continue;
      }

      try {
        final existingEmbedding =
            List<double>.from(
          rawEmbedding,
        );

        // ------------------------------------------------------
        // Same Face?
        //
        // Existing FaceMatchingService
        // uses cosine similarity.
        // ------------------------------------------------------

        final similarity =
            FaceMatchingService
                .cosineSimilarity(
          existingEmbedding,
          newEmbedding,
        );

        // ------------------------------------------------------
        // 0.70 is the existing face
        // verification threshold.
        // Use the same threshold for
        // duplicate registration.
        // ------------------------------------------------------

        if (similarity >= 0.70) {
          return true;
        }
      } catch (_) {
        // Invalid/old embedding:
        // ignore and continue checking.
        continue;
      }
    }

    return false;
  }

  // ============================================================
  // SAVE FACE EMBEDDING
  // ============================================================

  Future<void> saveFaceEmbedding(
    List<double> embedding,
  ) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    if (embedding.isEmpty) {
      throw Exception(
        'Face embedding is empty.',
      );
    }

    final faceRef =
        _firestore
            .collection('face_data')
            .doc(user.uid);

    // ==========================================================
    // 1. CHECK CURRENT USER
    // ==========================================================

    final existingFace =
        await faceRef.get();

    if (existingFace.exists) {
      final existingData =
          existingFace.data();

      final registeredDevice =
          existingData?['deviceId']
              ?.toString();

      if (registeredDevice != null &&
          registeredDevice.isNotEmpty) {
        final currentDevice =
            await getDeviceId();

        // ------------------------------------------------------
        // SAME USER + SAME DEVICE
        // ------------------------------------------------------

        if (registeredDevice ==
            currentDevice) {
          throw Exception(
            'Face is already registered on this device.',
          );
        }

        // ------------------------------------------------------
        // SAME USER + DIFFERENT DEVICE
        // ------------------------------------------------------

        throw Exception(
          'Face is already registered on another device.',
        );
      }

      // --------------------------------------------------------
      // OLD RECORD WITHOUT DEVICE ID
      // --------------------------------------------------------

      final currentDevice =
          await getDeviceId();

      await faceRef.update({
        'deviceId': currentDevice,
        'deviceBoundAt':
            FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'faceRegistered':
              true,
        },
        SetOptions(
          merge: true,
        ),
      );

      return;
    }

    // ==========================================================
    // 2. GLOBAL DUPLICATE FACE CHECK
    // ==========================================================

    final duplicate =
        await _isFaceAlreadyRegisteredByAnotherUser(
      embedding,
    );

    if (duplicate) {
      throw Exception(
        'This face is already registered with another student account. '
        'One person can register only one student account.',
      );
    }

    // ==========================================================
    // 3. DEVICE ID
    // ==========================================================

    final currentDevice =
        await getDeviceId();

    // ==========================================================
    // 4. SAVE NEW FACE
    // ==========================================================

    await faceRef.set({
      'embedding': embedding,

      'deviceId':
          currentDevice,

      'createdAt':
          FieldValue.serverTimestamp(),

      'deviceBoundAt':
          FieldValue.serverTimestamp(),
    });

    // ==========================================================
    // 5. UPDATE USER
    // ==========================================================

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(
      {
        'faceRegistered':
            true,
      },
      SetOptions(
        merge: true,
      ),
    );
  }

  // ============================================================
  // GET REGISTERED FACE EMBEDDING
  // ============================================================

  Future<List<double>?>
      getRegisteredFaceEmbedding() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    final doc = await _firestore
        .collection('face_data')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      return null;
    }

    final data =
        doc.data();

    if (data == null ||
        data['embedding'] == null) {
      return null;
    }

    return List<double>.from(
      data['embedding'],
    );
  }

  // ============================================================
  // TESTING HELPER FOR TEACHER
  // ============================================================

  Future<void>
      ensureTeacherForTesting() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    final userRef =
        _firestore
            .collection('users')
            .doc(user.uid);

    final existingDoc =
        await userRef.get();

    if (existingDoc.exists &&
        existingDoc.data()?['role'] !=
            null) {
      return;
    }

    await userRef.set(
      {
        'email': user.email,
        'name':
            user.displayName ?? '',
        'fullName':
            user.displayName ?? '',
        'role': 'teacher',
        'createdAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(
        merge: true,
      ),
    );
  }
}