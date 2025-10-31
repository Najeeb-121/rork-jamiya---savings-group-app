import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../pages/sign_in_page.dart';
import '../pages/dashboard_page.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If we're waiting for the initial auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;

        // If user is not signed in
        if (user == null) {
          return const SignInPage();
        }

        // If user is signed in, load their data
        return FutureBuilder<UserModel?>(
          future: UserService().getUserData(user.uid),
          builder: (context, snapshot) {
            // If we're waiting for user data
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            // If there's an error or no data
            if (!snapshot.hasData) {
              return const SignInPage();
            }

            // If we have user data, show the dashboard
            return DashboardPage(userData: snapshot.data!);
          },
        );
      },
    );
  }
}
