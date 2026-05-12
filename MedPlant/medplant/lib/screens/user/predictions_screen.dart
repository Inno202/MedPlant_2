// lib/screens/user/predictions_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:medplant/constants/app_colors.dart';
import 'package:medplant/services/ml_service.dart';
import 'package:medplant/services/database_service.dart';
import 'package:medplant/widgets/section_header.dart';
import 'package:medplant/widgets/info_note.dart';

class PredictionsScreen extends StatefulWidget {
  const PredictionsScreen({super.key});

  @override
  State<PredictionsScreen> createState() => _PredictionsScreenState();
}

class _PredictionsScreenState extends State<PredictionsScreen> {
  bool _serverOnline = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkServer();
  }

  Future<void> _checkServer() async {
    final online = await MLService.isServerReachable();
    if (mounted) {
      setState(() {
        _serverOnline = online;
        _checking = false;
      });
    }
  }

  Color _healthColor(String status) {
    switch (status) {
      case 'Healthy':
        return const Color(0xFF27AE60);
      case 'Stressed':
        return const Color(0xFFF39C12);
      case 'Degraded':
        return const Color(0xFFE74C3C);
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _trendIcon(String trend) {
    switch (trend) {
      case 'Improving':
        return Icons.trending_up;
      case 'Declining':
        return Icons.trending_down;
      default:
        return Icons.trending_flat;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return "Unknown";

    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    }

    return timestamp.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: "ML Health Predictions"),

            // Species banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(12),
                border: const Border(
                  left: BorderSide(color: AppColors.primary, width: 4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Lessertia frutescens (Cancer Bush)",
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Live data from Firestore · Thaba-Nchu monitoring",
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            _buildServerStatus(),
            const SizedBox(height: 16),
            _buildHealthSummary(),
            const SizedBox(height: 16),
            const InfoNote(),
          ],
        ),
      ),
    );
  }

  Widget _buildServerStatus() {
    if (_checking) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text("Checking ML server...", style: TextStyle(fontSize: 13)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _serverOnline
            ? const Color(0xFFEAF7EF)
            : const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _serverOnline ? const Color(0xFF27AE60) : Colors.orange,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _serverOnline
                ? Icons.check_circle
                : Icons.warning_amber_rounded,
            color: _serverOnline ? const Color(0xFF27AE60) : Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _serverOnline
                  ? "ML server online · Random Forest active"
                  : "ML server offline · Start Python server",
              style: TextStyle(
                fontSize: 12,
                color: _serverOnline
                    ? const Color(0xFF1A6B3A)
                    : const Color(0xFF856404),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() => _checking = true);
              _checkServer();
            },
            child: const Icon(Icons.refresh,
                size: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: DatabaseService.getReportsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Text(
            "No reports available",
            style: TextStyle(color: AppColors.textSecondary),
          );
        }

        final submissions = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;

          return _SubmissionRecord(
            date: _formatDate(data['submittedAt']),
            health: data['healthStatus'] ?? 'Unknown',
            trend: data['trendDirection'] ?? 'Stable',
            damage: List<String>.from(data['damageLabels'] ?? []),
            confidence: (data['confidence'] ?? 0).toDouble(),
            env: data['environmentalCondition'] ?? 'Unknown',
          );
        }).toList();

        final degraded =
            submissions.where((s) => s.health == 'Degraded').length;
        final stressed =
            submissions.where((s) => s.health == 'Stressed').length;
        final healthy =
            submissions.where((s) => s.health == 'Healthy').length;

        final total = submissions.length;
        final latest = submissions.first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CURRENT STATUS
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Current Status",
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _healthColor(latest.health)
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                latest.health,
                                style: TextStyle(
                                  color: _healthColor(latest.health),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(_trendIcon(latest.trend),
                                    size: 16,
                                    color: _healthColor(latest.health)),
                                const SizedBox(width: 4),
                                Text(
                                  latest.trend,
                                  style: TextStyle(
                                    color: _healthColor(latest.health),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              "Last report: ${latest.date}",
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "$total reports",
                            style: GoogleFonts.montserrat(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (degraded >= 3)
                            const Text(
                              "⚠ Alert triggered",
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFFE74C3C),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      children: [
                        if (degraded > 0)
                          Expanded(
                              flex: degraded,
                              child: Container(
                                  height: 10,
                                  color: const Color(0xFFE74C3C))),
                        if (stressed > 0)
                          Expanded(
                              flex: stressed,
                              child: Container(
                                  height: 10,
                                  color: const Color(0xFFF39C12))),
                        if (healthy > 0)
                          Expanded(
                              flex: healthy,
                              child: Container(
                                  height: 10,
                                  color: const Color(0xFF27AE60))),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Text(
              "Submission History",
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            ...submissions.map(_submissionCard),
          ],
        );
      },
    );
  }

  Widget _submissionCard(_SubmissionRecord s) {
    final color = _healthColor(s.health);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.date, style: const TextStyle(fontSize: 12)),
                Text(s.health,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color)),
                if (s.damage.isNotEmpty)
                  Text("Damage: ${s.damage.join(', ')}",
                      style: const TextStyle(fontSize: 11)),
                Text("Conditions: ${s.env}",
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
          Text(
            "${(s.confidence * 100).toInt()}%",
            style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _SubmissionRecord {
  final String date;
  final String health;
  final String trend;
  final List<String> damage;
  final double confidence;
  final String env;

  _SubmissionRecord({
    required this.date,
    required this.health,
    required this.trend,
    required this.damage,
    required this.confidence,
    required this.env,
  });
}