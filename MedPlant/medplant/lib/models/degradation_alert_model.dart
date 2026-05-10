// lib/models/degradation_alert_model.dart
// Corresponds to DEGRADATION_ALERT entity in the ERD (Assignment 3, Section 2.5)
// Triggered when a species receives 3+ 'Degraded' classifications
// within a defined reporting window — researcher early-warning feature.

class DegradationAlertModel {
  final String alertId;
  final String speciesId;
  final String speciesName;

  /// Number of 'Degraded' classifications that triggered this alert
  final int degradedCount;

  /// Threshold that triggers an alert (default: 3 per proposal)
  final int triggerThreshold;

  /// Current degradation index (0.0 = healthy, 1.0 = critical)
  final double degradationIndex;

  final String alertDate;

  /// 'Pending' | 'Acknowledged' | 'Resolved'
  final String notificationStatus;

  final String locationArea;

  const DegradationAlertModel({
    required this.alertId,
    required this.speciesId,
    required this.speciesName,
    required this.degradedCount,
    this.triggerThreshold = 3,
    required this.degradationIndex,
    required this.alertDate,
    this.notificationStatus = 'Pending',
    required this.locationArea,
  });

  /// Returns colour-coded severity based on degradation index
  String get severityLabel {
    if (degradationIndex >= 0.75) return 'Critical';
    if (degradationIndex >= 0.50) return 'High';
    if (degradationIndex >= 0.25) return 'Moderate';
    return 'Low';
  }
}

// ── Sample data for UI development ─────────────────────────────────────────
final List<DegradationAlertModel> sampleAlerts = [
  DegradationAlertModel(
    alertId: 'ALT-001',
    speciesId: 'SP-003',
    speciesName: 'Lessertia Frutescens',
    degradedCount: 4,
    degradationIndex: 0.78,
    alertDate: '2026-05-01',
    notificationStatus: 'Pending',
    locationArea: 'Thaba-Nchu, Free State',
  ),
  DegradationAlertModel(
    alertId: 'ALT-002',
    speciesId: 'SP-001',
    speciesName: 'Agapanthus Africanus',
    degradedCount: 3,
    degradationIndex: 0.55,
    alertDate: '2026-04-28',
    notificationStatus: 'Acknowledged',
    locationArea: 'Thaba-Nchu, Free State',
  ),
];
