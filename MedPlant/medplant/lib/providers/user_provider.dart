// lib/providers/user_provider.dart
import 'package:flutter/material.dart';
import '../models/user_role.dart';

class UserProvider extends ChangeNotifier {
  UserRole? _role;
  bool _isLoggedIn = false;

  UserRole? get role => _role;
  bool get isLoggedIn => _isLoggedIn;

  bool get isCommunityUser => _role == UserRole.communityUser;
  bool get isResearcher => _role == UserRole.researcher;

  void login(UserRole role) {
    _role = role;
    _isLoggedIn = true;
    debugPrint("User logged in as: ${role.name}");
    notifyListeners();
  }

  void logout() {
    _role = null;
    _isLoggedIn = false;
    debugPrint("User logged out");
    notifyListeners();
  }

  void setRole(UserRole? newRole) {
    _role = newRole;
    notifyListeners();
  }
}
