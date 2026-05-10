// lib/services/ml_service.dart
// Uses Uint8List bytes — works on Flutter Web AND mobile

import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

class MLService {
  // localhost for web/windows desktop
  // Change to ngrok URL for physical Android device
  static const String _baseUrl = 'http://localhost:8000';
  static const Duration _timeout = Duration(seconds: 30);

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
      debugPrint('ML error: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('ML service: $e');
      return null;
    }
  }

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