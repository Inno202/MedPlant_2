// lib/providers/navigation_provider.dart
// Two-role navigation aligned with research proposal actors:
//   communityUser → Home, Reports, Predictions, Profile
//   researcher    → Home, All Reports (+ approve), Analytics, Profile

import 'package:flutter/material.dart';
import '../models/user_role.dart';

class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;
  List<String> _routes = [];

  int get currentIndex => _currentIndex;
  List<String> get routes => _routes;

  void configureRoutes(UserRole? role) {
    if (role == UserRole.researcher) {
      _routes = [
        '/home',
        '/viewreports',      // researcher sees ALL reports + can approve flagged
        '/predictions',
        '/researcher/dashboard',
        '/profile',
      ];
    } else {
      // communityUser or guest
      _routes = [
        '/home',
        '/viewreports',      // community user sees their own reports
        '/predictions',
        '/profile',
      ];
    }
    _currentIndex = 0;
    notifyListeners();
  }

  void setIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  void setRoute(String route) {
    final index = _routes.indexWhere((r) => route.startsWith(r));
    if (index != -1 && index != _currentIndex) {
      _currentIndex = index;
      notifyListeners();
    }
  }
}
