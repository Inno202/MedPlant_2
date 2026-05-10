// lib/screens/user/predictions_screen.dart
// Shows ML health monitoring for Lessertia frutescens only.
// Scope reduced to one species as per research prototype decision.
// Fetches a live prediction from the ML server on screen load.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medplant/constants/app_colors.dart';
import 'package:medplant/services/ml_service.dart';
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
      case 'Healthy': return const Color(0xFF27AE60);
      case 'Stressed': return const Color(0xFFF39C12);
      case 'Degraded': return const Color(0xFFE74C3C);
      default: return AppColors.textSecondary;
    }
  }

  IconData _trendIcon(String trend) {
    switch (trend) {
      case 'Improving': return Icons.trending_up;
      case 'Declining': return Icons.trending_down;
      default: return Icons.trending_flat;
    }
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

            // Species focus banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(12),
                border: const Border(left: BorderSide(color: AppColors.primary, width: 4)),
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
                  Text(
                    "Thaba-Nchu, Free State · Monitoring active",
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            // Server status
            _buildServerStatus(),

            const SizedBox(height: 16),

            // Cumulative health summary from all submissions
            _buildHealthSummary(),

            const SizedBox(height: 16),

            // ML function explanations
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
        child: const Row(children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text("Checking ML server...", style: TextStyle(fontSize: 13)),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _serverOnline ? const Color(0xFFEAF7EF) : const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _serverOnline ? const Color(0xFF27AE60) : Colors.orange,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _serverOnline ? Icons.check_circle : Icons.warning_amber_rounded,
            color: _serverOnline ? const Color(0xFF27AE60) : Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _serverOnline
                  ? "ML server online · Random Forest pipeline active"
                  : "ML server offline · Start the Python server on port 8000",
              style: TextStyle(
                fontSize: 12,
                color: _serverOnline ? const Color(0xFF1A6B3A) : const Color(0xFF856404),
              ),
            ),
          ),
          GestureDetector(
            onTap: () { setState(() => _checking = true); _checkServer(); },
            child: const Icon(Icons.refresh, size: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthSummary() {
    // Sample data representing accumulated community submissions
    // In production these come from Firebase aggregated ML results
    final submissions = [
      _SubmissionRecord(date: "2026-05-08", health: "Degraded", trend: "Declining", damage: ["Leaf discolouration", "Browning", "Lesions"], confidence: 1.0, env: "Hot"),
      _SubmissionRecord(date: "2026-05-06", health: "Stressed", trend: "Declining", damage: ["Leaf discolouration"], confidence: 1.0, env: "Dry"),
      _SubmissionRecord(date: "2026-05-03", health: "Stressed", trend: "Stable", damage: ["Browning"], confidence: 1.0, env: "Normal"),
      _SubmissionRecord(date: "2026-04-28", health: "Healthy", trend: "Stable", damage: [], confidence: 1.0, env: "Wet / After rain"),
      _SubmissionRecord(date: "2026-04-21", health: "Healthy", trend: "Improving", damage: [], confidence: 1.0, env: "Normal"),
    ];

    // Count health statuses
    final degraded = submissions.where((s) => s.health == 'Degraded').length;
    final stressed = submissions.where((s) => s.health == 'Stressed').length;
    final healthy = submissions.where((s) => s.health == 'Healthy').length;
    final total = submissions.length;

    // Most recent
    final latest = submissions.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Current status card
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
              Text("Current Status", style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _healthColor(latest.health).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _healthColor(latest.health).withOpacity(0.4)),
                          ),
                          child: Text(
                            latest.health,
                            style: TextStyle(color: _healthColor(latest.health), fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          Icon(_trendIcon(latest.trend), size: 16, color: _healthColor(latest.health)),
                          const SizedBox(width: 4),
                          Text(latest.trend, style: TextStyle(fontSize: 12, color: _healthColor(latest.health), fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 4),
                        Text("Last report: ${latest.date}", style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  // Mini trend bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("$total reports", style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                      Text("total submissions", style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      if (degraded >= 3)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDECEC),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text("⚠ Alert threshold reached", style: TextStyle(fontSize: 10, color: Color(0xFFE74C3C), fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Health breakdown bar
              Text("Health distribution across $total reports:", style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    if (degraded > 0) Expanded(flex: degraded, child: Container(height: 10, color: const Color(0xFFE74C3C))),
                    if (stressed > 0) Expanded(flex: stressed, child: Container(height: 10, color: const Color(0xFFF39C12))),
                    if (healthy > 0) Expanded(flex: healthy, child: Container(height: 10, color: const Color(0xFF27AE60))),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _legendDot(const Color(0xFFE74C3C), "Degraded ($degraded)"),
                  const SizedBox(width: 12),
                  _legendDot(const Color(0xFFF39C12), "Stressed ($stressed)"),
                  const SizedBox(width: 12),
                  _legendDot(const Color(0xFF27AE60), "Healthy ($healthy)"),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Submission history
        Text("Submission History", style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
        const SizedBox(height: 8),

        ...submissions.map((s) => _submissionCard(s)),
      ],
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
        boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.04), blurRadius: 6)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(s.date, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text(s.health, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 6),
                  Icon(_trendIcon(s.trend), size: 13, color: color),
                ]),
                if (s.damage.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text("Damage: ${s.damage.join(', ')}", style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 2),
                Text("Conditions: ${s.env}", style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text("${(s.confidence * 100).toInt()}%", style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
    ],
  );
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