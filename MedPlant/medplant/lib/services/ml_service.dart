// lib/services/ml_service.dart
// Two separate calls:
//   identifySpecies()      → F1 only — used by AddReportScreen
//   runFullPipelineFromBytes() → F1+F2+F3 — kept for PredictionsScreen if needed
//   isServerReachable()    → health check

import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ── F1 result ─────────────────────────────────────────────────────────────────
class SpeciesIdentificationResult {
  final String species;
  final double confidence;
  final bool identified;
  final String message;

  const SpeciesIdentificationResult({
    required this.species,
    required this.confidence,
    required this.identified,
    required this.message,
  });

  factory SpeciesIdentificationResult.fromJson(Map<String, dynamic> j) =>
      SpeciesIdentificationResult(
        species: j['species'] ?? 'Unknown',
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
        identified: j['identified'] ?? false,
        message: j['message'] ?? '',
      );
}

// ── Full pipeline result (F1+F2+F3) ───────────────────────────────────────────
class FullPipelineResult {
  final String species;
  final double confidence;
  final bool identified;
  final String healthStatus;
  final String trendDirection;
  final int priorReportCount;
  final String predictionNote;
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

// ── Service ───────────────────────────────────────────────────────────────────
class MLService {
  // localhost for web / Windows desktop
  // Change to your ngrok URL for physical Android/iOS device
  static const String _baseUrl = 'http://localhost:8000';
  static const Duration _timeout = Duration(seconds: 30);

  // ── F1 only — used by AddReportScreen ────────────────────────────────────────
  // Sends image bytes to /predict/species
  // Returns SpeciesIdentificationResult with identified=true/false
  static Future<SpeciesIdentificationResult?> identifySpecies(
    Uint8List imageBytes, {
    String fileName = 'image.jpg',
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/predict/species');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: fileName),
      );

      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        return SpeciesIdentificationResult.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      }
      debugPrint('Species ID error: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('ML service identifySpecies: $e');
      return null;
    }
  }

  // ── Full pipeline — F1+F2+F3 ─────────────────────────────────────────────────
  // Kept for future use / PredictionsScreen
  static Future<FullPipelineResult?> runFullPipelineFromBytes(
    Uint8List imageBytes, {
    String fileName = 'image.jpg',
    String priorScores = '',
  }) async {
    try {
      final uri = Uri.parse(
          '$_baseUrl/predict/full?prior_scores=${Uri.encodeComponent(priorScores)}');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: fileName),
      );

      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        return FullPipelineResult.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      }
      debugPrint('ML pipeline error: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('ML service runFullPipeline: $e');
      return null;
    }
  }

  // ── Health check ──────────────────────────────────────────────────────────────
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