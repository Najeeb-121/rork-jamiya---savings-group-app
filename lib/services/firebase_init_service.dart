import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseInitService {
  static Future<void> initialize() async {
    try {
      print('Initializing Firebase...');
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      print('Firebase initialized successfully');
    } catch (e) {
      print('Error initializing Firebase: $e');
      rethrow;
    }
  }
}
