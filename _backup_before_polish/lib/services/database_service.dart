// lib/services/database_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class DatabaseService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Submit report ────────────────────────────────────────────────────────
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
    String? imageUrl,
    String? gpsCoordinates,
  }) async {
    try {
      final uid = AuthService.currentUserId;
      if (uid == null) return null;

      final bool isFlagged = !identified;
      final String reviewStatus = identified ? 'approved' : 'pending';

      final docRef = await _db.collection('plant_reports').add({
        'submittedBy': uid,
        'speciesName': speciesName,
        'identified': identified,
        'confidence': confidence,
        'healthStatus': healthStatus,
        'trendDirection': trendDirection,
        'damageLabels': damageLabels,
        'damageDetected': damageLabels.isNotEmpty,
        'predictionNote': predictionNote,
        'location': location,
        'environmentalCondition': environmentalCondition,
        'degradationIndicator': degradationIndicator,
        'observerNotes': observerNotes,
        'severity': severity,
        'imageUrl': imageUrl ?? '',
        'isFlagged': isFlagged,
        'reviewStatus': reviewStatus,
        'submittedAt': FieldValue.serverTimestamp(),
        'locationArea': 'Thaba-Nchu, Free State',
        'gpsCoordinates': gpsCoordinates ?? '',
      });

      if (identified && healthStatus == 'Stressed') {
        await _checkAndCreateAlert(speciesName);
      }

      return docRef.id;
    } catch (e) {
      return null;
    }
  }

  // ── Visibility helper (used everywhere) ──────────────────────────────────
  /// A document is visible in the main feed if:
  ///   - it has no reviewStatus field (legacy doc, written before this change)
  ///   - OR reviewStatus == 'approved'
  static bool isReportVisible(Map<String, dynamic> data) {
    final reviewStatus = data['reviewStatus'] as String?;
    if (reviewStatus == null) return true; // legacy doc → always show
    return reviewStatus == 'approved';
  }

  // ── Main reports feed (ViewReportsScreen) ─────────────────────────────────
  /// Fetches ALL docs ordered by date; the widget filters with isReportVisible().
  /// This avoids composite index requirements and handles legacy documents.
  static Stream<QuerySnapshot> getReportsStream() {
    return _db
        .collection('plant_reports')
        .orderBy('submittedAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> getUserReportsStream() {
    final uid = AuthService.currentUserId;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('plant_reports')
        .where('submittedBy', isEqualTo: uid)
        .orderBy('submittedAt', descending: true)
        .snapshots();
  }

  // ── Pending queue (ApproveReportsScreen) ──────────────────────────────────
  // Single-field query only — no composite index needed.
  // The UI sorts client-side if ordering matters.
  static Stream<QuerySnapshot> getPendingFlaggedReportsStream() {
    return getReportsByReviewStatusStream('pending');
  }

  static Stream<QuerySnapshot> getReportsByReviewStatusStream(String status) {
    return _db
        .collection('plant_reports')
        .where('reviewStatus', isEqualTo: status)
        .snapshots();
  }

  /// Same idea as [getReportsByReviewStatusStream], but for 'approved' it
  /// ALSO includes legacy documents that have NO reviewStatus field at all.
  ///
  /// Those legacy docs are treated as approved everywhere else in the app
  /// (see [isReportVisible]), but a plain
  /// `.where('reviewStatus', isEqualTo: 'approved')` can never match a
  /// missing field — Firestore has no "field does not exist" operator you
  /// can OR into that query. Without this, any report submitted before the
  /// reviewStatus field existed silently disappears from every tab on
  /// ApproveReportsScreen (though it still shows correctly on the main
  /// ViewReportsScreen feed, since that screen filters with
  /// isReportVisible instead).
  ///
  /// For 'pending' and 'declined' this behaves exactly like
  /// [getReportsByReviewStatusStream] — legacy docs are only ever treated
  /// as approved, never as pending/declined.
  static Stream<List<QueryDocumentSnapshot>> getReviewTabDocsStream(
      String status) {
    if (status != 'approved') {
      return getReportsByReviewStatusStream(status).map((snap) => snap.docs);
    }

    final explicit = _db
        .collection('plant_reports')
        .where('reviewStatus', isEqualTo: 'approved')
        .snapshots();

    // No "field does not exist" query in Firestore, so pull everything and
    // filter client-side for the legacy (missing-field) case. Fine at this
    // project's current scale; revisit with a stored boolean flag
    // (e.g. isLegacyApproved) if plant_reports grows significantly.
    final all = _db.collection('plant_reports').snapshots();

    return explicit.asyncMap((explicitSnap) async {
      final allSnap = await all.first;
      final legacyDocs = allSnap.docs
          .where((d) => (d.data() as Map<String, dynamic>)['reviewStatus'] == null)
          .toList();

      final seen = <String>{};
      final merged = <QueryDocumentSnapshot>[];
      for (final d in [...explicitSnap.docs, ...legacyDocs]) {
        if (seen.add(d.id)) merged.add(d);
      }
      return merged;
    });
  }

  // ── Researcher actions ────────────────────────────────────────────────────
  /// Approve a flagged report.
  ///
  /// [confirmedSpeciesName] is the species the researcher has identified
  /// the plant as, entered/edited in ApproveReportsScreen. When provided
  /// (non-null, non-empty), it overwrites whatever was stored at submission
  /// time — including the "Unidentified — pending review" placeholder used
  /// for reports the ML pipeline couldn't match — and flips `identified`
  /// to true, since a human has now confirmed it.
  ///
  /// Also sets `reviewStatus: 'approved'`, which is the field
  /// `isReportVisible` actually checks for feed visibility. (Previously
  /// this method only set a `status` field, which nothing read — approved
  /// reports never actually became visible.)
  static Future<void> approveReport(
    String reportId, {
    String? confirmedSpeciesName,
  }) async {
    final uid = AuthService.currentUserId;

    final Map<String, dynamic> updateData = {
      'status': 'approved',
      'reviewStatus': 'approved',
      'isFlagged': false,
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedBy': uid,
    };

    final trimmedName = confirmedSpeciesName?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      updateData['speciesName'] = trimmedName;
      updateData['identified'] = true;
    }

    await _db.collection('plant_reports').doc(reportId).update(updateData);

    // A researcher-confirmed species can itself trigger a degradation
    // alert check, same as an auto-identified one would at submission time.
    final doc = await _db.collection('plant_reports').doc(reportId).get();
    final data = doc.data();
    if (data != null && data['healthStatus'] == 'Stressed') {
      final speciesForAlert = trimmedName?.isNotEmpty == true
          ? trimmedName!
          : (data['speciesName'] as String? ?? '');
      if (speciesForAlert.isNotEmpty) {
        await _checkAndCreateAlert(speciesForAlert);
      }
    }
  }

  static Future<void> declineReport(String reportId) async {
    await _db.collection('plant_reports').doc(reportId).update({
      'isFlagged': true,
      'reviewStatus': 'declined',
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Species register ──────────────────────────────────────────────────────
  static Stream<QuerySnapshot> getSpeciesStream() {
    return _db.collection('species').snapshots();
  }

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

  // ── Health history ─────────────────────────────────────────────────────────
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
        return health == 'Stressed' ? '0.6' : '0.2';
      }).toList();

      return scores.join(',');
    } catch (e) {
      return '';
    }
  }

  // ── Degradation alerts ────────────────────────────────────────────────────
  static Future<void> _checkAndCreateAlert(String speciesName) async {
    try {
      final snapshot = await _db
          .collection('plant_reports')
          .where('speciesName', isEqualTo: speciesName)
          .where('healthStatus', isEqualTo: 'Stressed')
          .get();
      // ...rest unchanged (count >= 3 logic, alert doc fields, etc.)
      final count = snapshot.docs
          .where((d) => isReportVisible(d.data() as Map<String, dynamic>))
          .length;

      if (count >= 3) {
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
          await existing.docs.first.reference.update({
            'degradedCount': count,
            'degradationIndex': (count / 10).clamp(0.0, 1.0),
          });
        }
      }
    } catch (e) {
      // Silent fail
    }
  }

  static Stream<QuerySnapshot> getAlertsStream() {
    return _db
        .collection('degradation_alerts')
        .orderBy('alertDate', descending: true)
        .snapshots();
  }

  static Future<void> acknowledgeAlert(String alertId) async {
    await _db.collection('degradation_alerts').doc(alertId).update({
      'notificationStatus': 'Acknowledged',
    });
  }

  static Future<int> recheckAllAlerts() async {
    final speciesSnapshot = await _db.collection('species').get();
    int checked = 0;
    for (final doc in speciesSnapshot.docs) {
      final name = doc.data()['name'] as String?;
      if (name != null && name.isNotEmpty) {
        await _checkAndCreateAlert(name);
        checked++;
      }
    }
    return checked;
  }

  // ── Dashboard stats ───────────────────────────────────────────────────────
  static Future<Map<String, int>> getDashboardStats() async {
    try {
      final allReports = await _db.collection('plant_reports').get();
      final approvedCount = allReports.docs
          .where((d) => isReportVisible(d.data() as Map<String, dynamic>))
          .length;
      final pendingCount = allReports.docs
          .where((d) =>
              (d.data() as Map<String, dynamic>)['reviewStatus'] == 'pending')
          .length;

      final alerts = await _db
          .collection('degradation_alerts')
          .where('notificationStatus', isEqualTo: 'Pending')
          .get();
      final users = await _db.collection('users').get();
      final species = await _db.collection('species').get();

      return {
        'totalReports': approvedCount,
        'pendingReports': pendingCount,
        'activeAlerts': alerts.docs.length,
        'totalUsers': users.docs.length,
        'registeredSpecies': species.docs.length,
      };
    } catch (e) {
      return {
        'totalReports': 0,
        'pendingReports': 0,
        'activeAlerts': 0,
        'totalUsers': 0,
        'registeredSpecies': 0,
      };
    }
  }
}