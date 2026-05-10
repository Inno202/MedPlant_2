// lib/models/prediction_model.dart
// Aligned with the three-function Random Forest ML pipeline described in
// the research proposal (Assignment 3 & Proposal v6):
//   Function 1 – Species Identification
//   Function 2 – Trend-Based Health Classification
//   Function 3 – Damage Detection

import 'package:flutter/material.dart';

class PredictionModel {
  // ── Species info ─────────────────────────────────────────────────────────
  final String name;               // confirmed species name
  final String location;           // submission location (e.g. Thaba-Nchu)
  final IconData icon;

  // ── ML Function 1: Species Identification ────────────────────────────────
  /// Confidence score from RF species identification (0.0–1.0)
  final double similarity;         // kept for UI compatibility (same as idConfidence)
  final double? idConfidence;

  // ── ML Function 2: Trend-Based Health Classification ─────────────────────
  /// Current health: 'Healthy' | 'Stressed' | 'Degraded'
  final String healthStatus;

  /// Trend direction derived from historical Firebase submissions:
  /// 'Improving' | 'Stable' | 'Declining'
  final String trendDirection;

  /// Number of prior reports used to compute the trend score
  final int priorReportCount;

  // ── ML Function 3: Damage Detection ─────────────────────────────────────
  /// Detected damage types (multi-label)
  /// e.g. ['Leaf discolouration', 'Wilting', 'Browning']
  final List<String> damageLabels;

  // ── Environmental context (captured at submission time) ───────────────────
  final String temperature;
  final String season;
  final String environmentalCondition; // Hot | Cold | Wet | Dry | Normal

  // ── Combined prediction output (Functions 2 + 3) ─────────────────────────
  /// Plain-language summary shown to user
  /// e.g. "This plant has shown declining condition over the past 3 reports"
  final String predictionNote;

  // ── Legacy field kept for existing UI widgets ─────────────────────────────
  final String imageMatch;

  const PredictionModel({
    required this.name,
    required this.location,
    required this.similarity,
    required this.icon,
    required this.healthStatus,
    required this.trendDirection,
    required this.priorReportCount,
    required this.damageLabels,
    required this.temperature,
    required this.season,
    required this.environmentalCondition,
    required this.predictionNote,
    this.idConfidence,
    this.imageMatch = 'Confirmed',
  });
}
