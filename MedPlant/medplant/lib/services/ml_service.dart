// lib/services/ml_service.dart
//
// FINAL ML ARCHITECTURE (matches ml_server/main.py):
//   F1 — Species Identification (unchanged)
//   F2 — Leaf Health: BINARY Healthy / Stressed. Visual evidence
//        (discolouration, browning, wilting, lesions, stem irregularity)
//        is only present when health_status == 'Stressed' — it's
//        supporting detail for F2, not a separate function or class.
//        `damageLabels` below carries that evidence list — the name is
//        kept for backward compatibility with existing UI widgets, but it
//        no longer represents a distinct "damage detection" function.
//   F3 — Trend & Monitoring: Improving / Stable / Declining, computed
//        server-side from a linear-regression slope over prior health
//        scores + the current score.
//
// AddReportScreen  → runFullPipelineFromBytes()   (F1+F2+F3, image bytes)
// PredictionsScreen→ runContextualAnalysisFromUrl() (F2+F3, image URL stored
//                    in Firestore plant_reports, + all report context fields)

import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ── F1+F2+F3 full pipeline result  (AddReportScreen) ─────────────────────────
class FullPipelineResult {
  final String species;
  final double confidence;
  final bool identified;

  /// F2 — 'Healthy' | 'Stressed' only. No 'Degraded' class.
  final String healthStatus;

  /// F3 — 'Improving' | 'Stable' | 'Declining'.
  final String trendDirection;
  final int priorReportCount;
  final String predictionNote;

  /// F2 supporting evidence (discolouration, browning, wilting, lesions,
  /// stem irregularity) — only populated when [healthStatus] == 'Stressed'.
  final List<String> damageLabels;
  final bool damageDetected;
  final String overallMessage;

  const FullPipelineResult({
    required this.species,
    required this.confidence,
    required this.identified,
    required this.healthStatus,
    required this.trendDirection,
    required this.priorReportCount,
    required this.predictionNote,
    required this.damageLabels,
    required this.damageDetected,
    required this.overallMessage,
  });

  factory FullPipelineResult.fromJson(Map<String, dynamic> j) =>
      FullPipelineResult(
        species: j['species'] ?? 'Unknown',
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
        identified: j['identified'] ?? false,
        healthStatus: j['health_status'] ?? 'Unknown',
        trendDirection: j['trend_direction'] ?? 'Stable',
        priorReportCount: (j['prior_report_count'] as num?)?.toInt() ?? 0,
        predictionNote: j['prediction_note'] ?? '',
        damageLabels: List<String>.from(j['damage_labels'] ?? []),
        damageDetected: j['damage_detected'] ?? false,
        overallMessage: j['overall_message'] ?? '',
      );
}

// ── F2+F3 contextual result  (PredictionsScreen) ─────────────────────────────
class ContextualAnalysisResult {
  /// F2 — 'Healthy' | 'Stressed' only.
  final String healthStatus;

  /// F3 — 'Improving' | 'Stable' | 'Declining'.
  final String trendDirection;
  final int priorReportCount;

  /// F2's raw 0.0 (healthy) .. 1.0 (stressed) score — this is what F3's
  /// trend slope is computed over.
  final double trendScore;
  final String predictionNote;

  /// F2 supporting evidence — only populated when [healthStatus] == 'Stressed'.
  final List<String> damageLabels;
  final bool damageDetected;
  final double severityScore;
  final String comprehensiveReport;
  final List<String> recommendations;
  final Map<String, String> factorBreakdown;

  /// Researcher follow-up priority — independent of healthStatus, never
  /// overrides the F2 Healthy/Stressed call.
  final String riskLevel;         // Low | Moderate | High | Critical
  final int alertScore;           // 0–10

  const ContextualAnalysisResult({
    required this.healthStatus,
    required this.trendDirection,
    required this.priorReportCount,
    required this.trendScore,
    required this.predictionNote,
    required this.damageLabels,
    required this.damageDetected,
    required this.severityScore,
    required this.comprehensiveReport,
    required this.recommendations,
    required this.factorBreakdown,
    required this.riskLevel,
    required this.alertScore,
  });

  factory ContextualAnalysisResult.fromJson(Map<String, dynamic> j) =>
      ContextualAnalysisResult(
        healthStatus: j['health_status'] ?? 'Unknown',
        trendDirection: j['trend_direction'] ?? 'Stable',
        priorReportCount: (j['prior_report_count'] as num?)?.toInt() ?? 0,
        trendScore: (j['trend_score'] as num?)?.toDouble() ?? 0.0,
        predictionNote: j['prediction_note'] ?? '',
        damageLabels: List<String>.from(j['damage_labels'] ?? []),
        damageDetected: j['damage_detected'] ?? false,
        severityScore: (j['severity_score'] as num?)?.toDouble() ?? 0.0,
        comprehensiveReport: j['comprehensive_report'] ?? '',
        recommendations: List<String>.from(j['recommendations'] ?? []),
        factorBreakdown: Map<String, String>.from(j['factor_breakdown'] ?? {}),
        riskLevel: j['risk_level'] ?? 'Low',
        alertScore: (j['alert_score'] as num?)?.toInt() ?? 0,
      );

  /// Serialise to Firestore-compatible map for storage in ml_predictions.
  Map<String, dynamic> toFirestoreMap({
    required String reportId,
    required String date,
    required String env,
  }) =>
      {
        'report_id': reportId,
        'analysed_at': date,
        'environment': env,
        'health_status': healthStatus,
        'trend_direction': trendDirection,
        'prior_report_count': priorReportCount,
        'trend_score': trendScore,
        'prediction_note': predictionNote,
        'damage_labels': damageLabels,
        'damage_detected': damageDetected,
        'severity_score': severityScore,
        'comprehensive_report': comprehensiveReport,
        'recommendations': recommendations,
        'factor_breakdown': factorBreakdown,
        'risk_level': riskLevel,
        'alert_score': alertScore,
      };
}

// ── F2-only result  (rarely used directly, exposed for completeness) ─────────
class LeafHealthResult {
  final String healthStatus;   // 'Healthy' | 'Stressed'
  final double healthScore;    // 0.0..1.0
  final double confidence;
  final String predictionNote;
  final List<String> evidence; // only populated when Stressed

  const LeafHealthResult({
    required this.healthStatus,
    required this.healthScore,
    required this.confidence,
    required this.predictionNote,
    required this.evidence,
  });

  factory LeafHealthResult.fromJson(Map<String, dynamic> j) => LeafHealthResult(
        healthStatus: j['health_status'] ?? 'Unknown',
        healthScore: (j['health_score'] as num?)?.toDouble() ?? 0.0,
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
        predictionNote: j['prediction_note'] ?? '',
        evidence: List<String>.from(j['evidence'] ?? []),
      );
}

// ── Service ───────────────────────────────────────────────────────────────────
class MLService {
  // Change to ngrok URL when running on a physical device.
  static const String _baseUrl = 'http://localhost:8000';
  static const Duration _timeout = Duration(seconds: 30);

  // ── AddReportScreen: F1+F2+F3 from raw image bytes ───────────────────────
  static Future<FullPipelineResult?> runFullPipelineFromBytes(
    Uint8List imageBytes, {
    String fileName = 'image.jpg',
    String priorScores = '',
    String reportedSeverity = '1',
    String environmentalCondition = 'Normal',
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/predict/full');
      final request = http.MultipartRequest('POST', uri);
      request.fields['prior_scores'] = priorScores;
      request.fields['reported_severity'] = reportedSeverity;
      request.fields['environmental_condition'] = environmentalCondition;
      request.files.add(
          http.MultipartFile.fromBytes('file', imageBytes, filename: fileName));
      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        return FullPipelineResult.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      }
      debugPrint('ML full pipeline error: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('ML full pipeline: $e');
      return null;
    }
  }

  // ── PredictionsScreen: F2+F3 from Firestore image URL + report fields ────
  // The server downloads the image from the stored URL, runs F2 and F3, then
  // cross-references results with the report's context fields.
  static Future<ContextualAnalysisResult?> runContextualAnalysisFromUrl({
    required String imageUrl,
    required String location,
    required String environmentalCondition,
    required String degradationIndicator,
    required String observerNotes,
    required String severity,
    String priorScores = '',
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/predict/contextual_url');
      final request = http.MultipartRequest('POST', uri);
      request.fields['image_url'] = imageUrl;
      request.fields['prior_scores'] = priorScores;
      request.fields['environmental_condition'] = environmentalCondition;
      request.fields['degradation_indicator'] = degradationIndicator;
      request.fields['observer_notes'] = observerNotes;
      request.fields['reported_severity'] = severity;
      request.fields['location'] = location;

      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        return ContextualAnalysisResult.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      }
      debugPrint(
          'Contextual URL error: ${response.statusCode} — ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Contextual URL analysis: $e');
      return null;
    }
  }

  // ── F2 only (rarely called directly — mostly for debugging/testing) ──────
  static Future<LeafHealthResult?> runLeafHealthFromBytes(
    Uint8List imageBytes, {
    String fileName = 'image.jpg',
    String reportedSeverity = '1',
    String environmentalCondition = 'Normal',
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/predict/health');
      final request = http.MultipartRequest('POST', uri);
      request.fields['reported_severity'] = reportedSeverity;
      request.fields['environmental_condition'] = environmentalCondition;
      request.files.add(
          http.MultipartFile.fromBytes('file', imageBytes, filename: fileName));
      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        return LeafHealthResult.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('ML leaf health: $e');
      return null;
    }
  }

  // ── Health check ─────────────────────────────────────────────────────────
  static Future<bool> isServerReachable() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}