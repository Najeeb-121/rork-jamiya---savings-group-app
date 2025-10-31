import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class PhoneAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _verificationId;

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onError,
  }) async {
    try {
      // Clear any existing verification state
      _verificationId = null;

      // Cancel any existing verification process
      await _auth.signOut();

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _auth.signInWithCredential(credential);
          } catch (e) {
            onError(e.toString());
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  Future<UserCredential?> signInWithPhoneNumber(String smsCode) async {
    try {
      if (_verificationId == null) {
        throw Exception(
            'Verification ID is null. Please request a new verification code.');
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      // Clear verification state before signing in
      final verificationId = _verificationId;
      _verificationId = null;

      final userCredential = await _auth.signInWithCredential(credential);

      return userCredential;
    } catch (e) {
      // Clear verification state on error
      _verificationId = null;
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      // Clear verification state
      _verificationId = null;

      // Force sign out from Firebase
      await _auth.signOut();

      // Clear any pending operations
      await Future.delayed(const Duration(milliseconds: 100));

      // Force another sign out to ensure complete cleanup
      await _auth.signOut();

      // Verify that the user is actually signed out
      if (_auth.currentUser != null) {
        // If still signed in, try one more time
        await _auth.signOut();
        await Future.delayed(const Duration(milliseconds: 100));

        if (_auth.currentUser != null) {
          throw Exception('Failed to sign out. User is still authenticated.');
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createUser(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(user.toMap());
    } catch (e) {
      rethrow;
    }
  }
}
