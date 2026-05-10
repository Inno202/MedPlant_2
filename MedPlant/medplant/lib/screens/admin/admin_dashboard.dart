// lib/screens/admin/admin_dashboard.dart
// Researcher Analytics Dashboard — aligned with research proposal Section 2.3.2
// Shows: longitudinal health trends, degradation alerts, species breakdown,
// environmental patterns — all sourced from Firebase (dummy data for prototype)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medplant/models/degradation_alert_model.dart';
import 'package:medplant/widgets/section_header.dart';
import 'package:medplant/constants/app_colors.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: "Researcher Dashboard"),
            const SizedBox(height: 4),
            Text(
              "Thaba-Nchu Medicinal Plant Monitoring · Free State",
              style: GoogleFonts.lato(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // ── Summary stats ──────────────────────────────────────────────
            _statsRow(),
            const SizedBox(height: 20),

            // ── Degradation Alerts ─────────────────────────────────────────
            _sectionTitle("⚠ Degradation Alerts"),
            const SizedBox(height: 10),
            ...sampleAlerts.map((alert) => _alertCard(alert)),
            const SizedBox(height: 20),

            // ── Species Health Summary ─────────────────────────────────────
            _sectionTitle("Species Health Summary"),
            const SizedBox(height: 10),
            _healthSummaryTable(),
            const SizedBox(height: 20),

            // ── ML Pipeline Status ─────────────────────────────────────────
            _sectionTitle("ML Pipeline Status"),
            const SizedBox(height: 10),
            _mlStatusCard(),
            const SizedBox(height: 20),

            // ── Top Damage Types ───────────────────────────────────────────
            _sectionTitle("Dominant Damage Types (All Submissions)"),
            const SizedBox(height: 10),
            _damageBreakdown(),
          ],
        ),
      ),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────────────
  Widget _statsRow() {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 500;
      final cards = [
        _statCard("Registered Species", "12", Icons.eco, AppColors.primary),
        _statCard("Total Submissions", "87", Icons.camera_alt, AppColors.primarySoft),
        _statCard("Active Alerts", "2", Icons.warning, const Color(0xFFE74C3C)),
        _statCard("Community Users", "34", Icons.people, AppColors.primaryDark),
      ];
      return isNarrow
          ? GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: cards,
            )
          : Row(
              children: cards
                  .map((c) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: c,
                        ),
                      ))
                  .toList(),
            );
    });
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  // ── Degradation alert card ────────────────────────────────────────────────
  Widget _alertCard(DegradationAlertModel alert) {
    final Color severityColor = alert.degradationIndex >= 0.75
        ? const Color(0xFFE74C3C)
        : const Color(0xFFF39C12);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: severityColor, width: 4)),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.04), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: severityColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.speciesName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${alert.degradedCount} 'Degraded' classifications · ${alert.locationArea}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  alert.severityLabel,
                  style: TextStyle(
                    color: severityColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                alert.notificationStatus,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Species health summary table ──────────────────────────────────────────
  Widget _healthSummaryTable() {
    final data = [
      ['Agapanthus Africanus', '14', 'Stressed', 'Declining'],
      ['Knowltonia Capensis', '11', 'Healthy', 'Stable'],
      ['Lessertia Frutescens', '21', 'Degraded', 'Declining'],
      ['Hypoxis Hemerocallidea', '9', 'Stressed', 'Improving'],
      ['Bulbine Frutescens', '6', 'Healthy', 'Stable'],
    ];

    Color statusColor(String s) {
      if (s == 'Healthy') return const Color(0xFF27AE60);
      if (s == 'Degraded') return const Color(0xFFE74C3C);
      return const Color(0xFFF39C12);
    }

    Color trendColor(String t) {
      if (t == 'Improving') return const Color(0xFF27AE60);
      if (t == 'Declining') return const Color(0xFFE74C3C);
      return Colors.grey;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.accentBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text("Species", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(child: Text("Reports", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(child: Text("Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(child: Text("Trend", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
            ),
          ),
          ...data.map((row) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.borderSoft)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(row[0], style: const TextStyle(fontSize: 12)),
                    ),
                    Expanded(
                      child: Text(row[1], style: const TextStyle(fontSize: 12)),
                    ),
                    Expanded(
                      child: Text(
                        row[2],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor(row[2]),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row[3],
                        style: TextStyle(
                          fontSize: 12,
                          color: trendColor(row[3]),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── ML Pipeline status ────────────────────────────────────────────────────
  Widget _mlStatusCard() {
    final functions = [
      ['F1 · Species Identification', 'Random Forest', '94.2% accuracy', Icons.search],
      ['F2 · Health Classification', 'Random Forest + Firebase history', '88.7% accuracy', Icons.health_and_safety],
      ['F3 · Damage Detection', 'Random Forest (multi-label)', '85.1% accuracy', Icons.bug_report],
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        children: functions.map((f) {
          return ListTile(
            leading: Icon(f[3] as IconData, color: AppColors.primary, size: 20),
            title: Text(f[0] as String,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text("${f[1]} · ${f[2]}",
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            dense: true,
          );
        }).toList(),
      ),
    );
  }

  // ── Damage type breakdown ─────────────────────────────────────────────────
  Widget _damageBreakdown() {
    final items = [
      ('Leaf discolouration', 0.68),
      ('Wilting', 0.52),
      ('Browning', 0.44),
      ('Lesions', 0.31),
      ('Stem damage', 0.19),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.$1, style: const TextStyle(fontSize: 12)),
                    Text("${(item.$2 * 100).toInt()}%",
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: item.$2,
                    minHeight: 6,
                    backgroundColor: AppColors.accentBg,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      item.$2 >= 0.6
                          ? const Color(0xFFE74C3C)
                          : item.$2 >= 0.4
                              ? const Color(0xFFF39C12)
                              : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: GoogleFonts.montserrat(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
        ),
      );
}
