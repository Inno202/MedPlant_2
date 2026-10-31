// lib/providers/user_provider.dart

import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';

class UserProvider extends ChangeNotifier {
  UserRole? _role;
  bool _isLoggedIn = false;

  String? _uid;
  String? _username;
  String? _email;

  bool _restoring = true;

  // Getters
  UserRole? get role => _role;
  bool get isLoggedIn => _isLoggedIn;
  bool get isRestoring => _restoring;

  String? get uid => _uid;
  String? get username => _username;
  String? get email => _email;

  bool get isCommunityUser => _role == UserRole.communityUser;
  bool get isResearcher => _role == UserRole.researcher;

  UserProvider() {
    _restoreSession();
  }

  // ── Restore session from Firebase on app start ───────────────────────────
  Future<void> _restoreSession() async {
    final firebaseUser = AuthService.currentUser;
    if (firebaseUser != null) {
      final profile = await AuthService.getUserProfile(firebaseUser.uid);
      if (profile != null) {
        final roleStr = profile['role'] ?? 'communityUser';
        final role = switch (roleStr) {
          'researcher' => UserRole.researcher,
          _ => UserRole.communityUser,
        };
        loginWithDetails(
          role: role,
          uid: firebaseUser.uid,
          username: profile['username'] ?? '',
          email: profile['email'] ?? '',
        );
      }
    }
    _restoring = false;
    notifyListeners();
  }

  // Basic login
  void login(UserRole role) {
    _role = role;
    _isLoggedIn = true;

    debugPrint("User logged in as: ${role.name}");

    notifyListeners();
  }

  // Login with Firestore details
  void loginWithDetails({
    required UserRole role,
    required String uid,
    required String username,
    required String email,
  }) {
    _role = role;
    _uid = uid;
    _username = username;
    _email = email;

    _isLoggedIn = true;

    debugPrint("Logged in user:");
    debugPrint("UID: $uid");
    debugPrint("Username: $username");
    debugPrint("Email: $email");
    debugPrint("Role: ${role.name}");

    notifyListeners();
  }

  void logout() {
    _role = null;
    _uid = null;
    _username = null;
    _email = null;

    _isLoggedIn = false;

    debugPrint("User logged out");

    notifyListeners();
  }

  void setRole(UserRole? newRole) {
    _role = newRole;
    notifyListeners();
  }
}