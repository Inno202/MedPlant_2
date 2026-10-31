import 'package:flutter/material.dart';
import 'package:medplant/screens/auth/login_screen.dart';
import 'package:medplant/screens/user/user_home_screen.dart';


class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool? isLoggedIn;

  @override
  void initState() {
    super.initState();
    checkAuth();
  }

  Future<void> checkAuth() async {
    await Future.delayed(const Duration(seconds: 1)); // simulate loading

    // TODO: Replace with real auth logic
    bool loggedIn = false; // change this later

    setState(() {
      isLoggedIn = loggedIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoggedIn == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return isLoggedIn!
        ? const UserHomeScreen()
        :  LoginScreen();
  }
}