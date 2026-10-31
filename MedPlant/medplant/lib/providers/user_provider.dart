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
    // Wait for Firebase to finish restoring any persisted session. On the
    // web `currentUser` is still null right after start-up, so reading it
    // directly logged users out on every refresh.
    final firebaseUser = await AuthService.authStateChanges.first
        .timeout(const Duration(seconds: 8), onTimeout: () => AuthService.currentUser)
        .catchError((_) => AuthService.currentUser);
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


    notifyListeners();
  }

  /// Signs out of Firebase AND clears local session state. Use this for
  /// every Logout button — clearing only the role (the old behaviour)
  /// left the Firebase session alive, so the user was silently logged
  /// back in on the next app start.
  Future<void> signOut() async {
    try {
      await AuthService.logout();
    } catch (e) {
      debugPrint('Sign-out failed: $e');
    }
    logout();
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
    _isLoggedIn = newRole != null;
    notifyListeners();
  }

  /// Updates the cached username after the user edits their profile.
  void updateUsername(String username) {
    _username = username;
    notifyListeners();
  }
}