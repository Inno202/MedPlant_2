// lib/services/database_service.dart
// All Firestore read/write operations.
// Collections:
//   users/           — user profiles
//   plant_reports/   — community submissions + ML results
//   species/         — registered medicinal species register
//   degradation_alerts/ — researcher early-warning alerts

import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';


class DatabaseService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ────────────────────────────────────────────────────────────────────────────
  // PLANT REPORTS
  // ────────────────────────────────────────────────────────────────────────────

  /// Submit a new plant report with ML results
  static Future<String?> submitReport({
    required String speciesName,
    required bool identified,
    required double confidence,
    required String healthStatus,
    required String trendDirection,
    required List<String> damageLabels,
    required String predictionNote,
    required String location,
    required String environmentalCondition,
    required String degradationIndicator,
    required String observerNotes,
    required String severity,
    String? imageBase64,  // base64 encoded image string
  }) async {
    try {
      final uid = AuthService.currentUserId;
      if (uid == null) return null;

      final docRef = await _db.collection('plant_reports').add({
        'submittedBy': uid,
        'speciesName': speciesName,
        'identified': identified,
        'confidence': confidence,
        // F2 — health classification
        'healthStatus': healthStatus,
        'trendDirection': trendDirection,
        // F3 — damage detection
        'damageLabels': damageLabels,
        'damageDetected': damageLabels.isNotEmpty,
        'predictionNote': predictionNote,
        // Form fields
        'location': location,
        'environmentalCondition': environmentalCondition,
        'degradationIndicator': degradationIndicator,
        'observerNotes': observerNotes,
        'severity': severity,
        // Image
        'imageBase64': imageBase64 ?? '',
        // Metadata
        'status': identified ? 'submitted' : 'flagged',
        'submittedAt': FieldValue.serverTimestamp(),
        'locationArea': 'Thaba-Nchu, Free State',
      });

      // Update degradation alert if health is Degraded
      if (identified && healthStatus == 'Degraded') {
        await _checkAndCreateAlert(speciesName);
      }

      return docRef.id;
    } catch (e) {
      return null;
    }
  }

  /// Stream of all reports — used by ViewReportsScreen
  static Stream<QuerySnapshot> getReportsStream() {
    return _db
        .collection('plant_reports')
        .orderBy('submittedAt', descending: true)
        .snapshots();
  }

  /// Stream of current user's reports only
  static Stream<QuerySnapshot> getUserReportsStream() {
    final uid = AuthService.currentUserId;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('plant_reports')
        .where('submittedBy', isEqualTo: uid)
        .orderBy('submittedAt', descending: true)
        .snapshots();
  }

  /// Stream of flagged reports for researcher review
  static Stream<QuerySnapshot> getFlaggedReportsStream() {
    return _db
        .collection('plant_reports')
        .where('status', isEqualTo: 'flagged')
        .orderBy('submittedAt', descending: true)
        .snapshots();
  }

  /// Approve a flagged report
  static Future<void> approveReport(String reportId) async {
    await _db.collection('plant_reports').doc(reportId).update({
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reject a flagged report
  static Future<void> rejectReport(String reportId) async {
    await _db.collection('plant_reports').doc(reportId).update({
      'status': 'rejected',
    });
  }

  // ────────────────────────────────────────────────────────────────────────────
  // SPECIES REGISTER
  // ────────────────────────────────────────────────────────────────────────────

  /// Stream of registered species — used by home screen plant grid
  static Stream<QuerySnapshot> getSpeciesStream() {
    return _db.collection('species').snapshots();
  }

  /// Seed initial species register (call once from researcher dashboard)
  static Future<void> seedSpeciesRegister() async {
    final batch = _db.batch();
    final species = [
      {
        'name': 'Lessertia frutescens',
        'commonName': 'Cancer Bush',
        'localName': 'Mahloko a Dinoha',
        'family': 'Fabaceae',
        'conservationStatus': 'Least Concern',
        'locationArea': 'Thaba-Nchu, Free State',
        'imageUrl': '',
        'addedAt': FieldValue.serverTimestamp(),
      },
    ];
    for (final s in species) {
      final ref = _db.collection('species').doc();
      batch.set(ref, s);
    }
    await batch.commit();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // HEALTH HISTORY — for F2 trend calculation
  // ────────────────────────────────────────────────────────────────────────────

  /// Get prior health scores for a species (used to pass to ML server)
  static Future<String> getPriorScores(String speciesName) async {
    try {
      final snapshot = await _db
          .collection('plant_reports')
          .where('speciesName', isEqualTo: speciesName)
          .where('identified', isEqualTo: true)
          .orderBy('submittedAt', descending: true)
          .limit(10)
          .get();

      final scores = snapshot.docs.map((doc) {
        final health = doc['healthStatus'] ?? 'Healthy';
        if (health == 'Degraded') return '0.8';
        if (health == 'Stressed') return '0.5';
        return '0.2';
      }).toList();

      return scores.join(',');
    } catch (e) {
      return '';
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // DEGRADATION ALERTS
  // ────────────────────────────────────────────────────────────────────────────

  /// Check if species has 3+ Degraded reports → create/update alert
  static Future<void> _checkAndCreateAlert(String speciesName) async {
    try {
      final snapshot = await _db
          .collection('plant_reports')
          .where('speciesName', isEqualTo: speciesName)
          .where('healthStatus', isEqualTo: 'Degraded')
          .get();

      final count = snapshot.docs.length;

      if (count >= 3) {
        // Check if alert already exists
        final existing = await _db
            .collection('degradation_alerts')
            .where('speciesName', isEqualTo: speciesName)
            .where('notificationStatus', isEqualTo: 'Pending')
            .get();

        if (existing.docs.isEmpty) {
          await _db.collection('degradation_alerts').add({
            'speciesName': speciesName,
            'degradedCount': count,
            'triggerThreshold': 3,
            'degradationIndex': (count / 10).clamp(0.0, 1.0),
            'locationArea': 'Thaba-Nchu, Free State',
            'notificationStatus': 'Pending',
            'alertDate': FieldValue.serverTimestamp(),
          });
        } else {
          // Update existing alert count
          await existing.docs.first.reference.update({
            'degradedCount': count,
            'degradationIndex': (count / 10).clamp(0.0, 1.0),
          });
        }
      }
    } catch (e) {
      // Silent fail — alert creation is non-critical
    }
  }

  /// Stream of degradation alerts for researcher dashboard
  static Stream<QuerySnapshot> getAlertsStream() {
    return _db
        .collection('degradation_alerts')
        .orderBy('alertDate', descending: true)
        .snapshots();
  }

  /// Acknowledge an alert
  static Future<void> acknowledgeAlert(String alertId) async {
    await _db.collection('degradation_alerts').doc(alertId).update({
      'notificationStatus': 'Acknowledged',
    });
  }

  // ────────────────────────────────────────────────────────────────────────────
  // DASHBOARD STATS
  // ────────────────────────────────────────────────────────────────────────────

  /// Get summary counts for researcher dashboard
  static Future<Map<String, int>> getDashboardStats() async {
    try {
      final reports = await _db.collection('plant_reports').get();
      final alerts = await _db
          .collection('degradation_alerts')
          .where('notificationStatus', isEqualTo: 'Pending')
          .get();
      final users = await _db.collection('users').get();
      final species = await _db.collection('species').get();

      return {
        'totalReports': reports.docs.length,
        'activeAlerts': alerts.docs.length,
        'totalUsers': users.docs.length,
        'registeredSpecies': species.docs.length,
      };
    } catch (e) {
      return {
        'totalReports': 0,
        'activeAlerts': 0,
        'totalUsers': 0,
        'registeredSpecies': 0,
      };
    }
  }
}