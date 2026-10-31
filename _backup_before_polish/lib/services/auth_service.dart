// lib/services/auth_service.dart
// Handles Firebase Authentication for two roles:
//   communityUser — traditional healers / IK holders in Thaba-Nchu
//   researcher    — study author / supervisor

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_role.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Current user stream ────────────────────────────────────────────────────
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;
  static String? get currentUserId => _auth.currentUser?.uid;

  // ── Register ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String username,
    required String contact,
    required String country,
    required String province,
    UserRole role = UserRole.communityUser,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final uid = credential.user!.uid;

      // Save user profile to Firestore users collection
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'username': username.trim(),
        'email': email.trim(),
        'contact': contact.trim(),
        'country': country.trim(),
        'province': province.trim(),
        'role': role.name, // 'communityUser' or 'researcher'
        'locationArea': 'Thaba-Nchu, Free State',
        'registeredAt': FieldValue.serverTimestamp(),
      });

      return {'success': true, 'uid': uid, 'role': role.name};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _authErrorMessage(e.code)};
    } catch (e) {
      return {'success': false, 'error': 'Registration failed. Try again.'};
    }
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final uid = credential.user!.uid;

      // Fetch role from Firestore
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) {
        return {'success': false, 'error': 'User profile not found.'};
      }

      final roleStr = doc.data()?['role'] ?? 'communityUser';
      final role = roleStr == 'researcher'
          ? UserRole.researcher
          : UserRole.communityUser;

      return {
        'success': true,
        'uid': uid,
        'role': role,
        'username': doc.data()?['username'] ?? '',
        'email': doc.data()?['email'] ?? '',
      };
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'error': _authErrorMessage(e.code)};
    } catch (e) {
      return {'success': false, 'error': 'Login failed. Try again.'};
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  static Future<void> logout() async {
    await _auth.signOut();
  }

  // ── Get user profile ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      return null;
    }
  }

  // ── Friendly error messages ────────────────────────────────────────────────
  static String _authErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication error. Please try again.';
    }
  }
}