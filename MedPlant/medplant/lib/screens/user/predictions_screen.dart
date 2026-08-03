// lib/screens/user/predictions_screen.dart
//
// Flow:
//  1. On load → fetch plant_reports collection from Firestore (real data)
//  2. Show report count + overall trend summary (top section)
//  3. For each report → check ml_predictions/{reportId} for cached analysis
//     → if absent, call MLService.runContextualAnalysisFromUrl() (F2+F3)
//     using the report's stored imageUrl + context fields
//     → save result to ml_predictions/{reportId}
//  4. Display submission history timeline, newest first

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medplant/constants/app_colors.dart';
import 'package:medplant/services/ml_service.dart';
import 'package:medplant/widgets/section_header.dart';
import 'package:medplant/widgets/info_note.dart';

// ── Lightweight data model matching Firestore plant_reports documents ─────────
class _PlantReport {
  final String id;
  final String imageUrl;
  final String location;
  final String date;
  final String environment;
  final String description;
  final String degradationIndicator;
  final String severity;

  const _PlantReport({
    required this.id,
    required this.imageUrl,
    required this.location,
    required this.date,
    required this.environment,
    required this.description,
    required this.degradationIndicator,
    required this.severity,
  });

  /// Build from a Firestore plant_reports document.
  /// Field names match DatabaseService.submitReport() exactly.
  factory _PlantReport.fromMap(String id, Map<String, dynamic> m) =>
      _PlantReport(
        id: id,
        imageUrl: m['imageUrl'] ?? '',
        location: m['location'] ?? '',
        date: m['submittedAt'] != null
            ? (m['submittedAt'] as Timestamp)
                .toDate()
                .toString()
                .split(' ')
                .first
            : '',
        environment: m['environmentalCondition'] ?? 'Normal',
        description: m['observerNotes'] ?? '',
        degradationIndicator: m['degradationIndicator'] ?? 'None observed',
        severity: m['severity']?.toString() ?? '1',
      );
}

// ── Merged view model: one Firestore report + its ML analysis ────────────────
class _AnalysedReport {
  final _PlantReport report;
  final ContextualAnalysisResult? analysis;
  final bool loading;
  final bool failed;

  const _AnalysedReport({
    required this.report,
    this.analysis,
    this.loading = false,
    this.failed = false,
  });

  _AnalysedReport copyWith({
    ContextualAnalysisResult? analysis,
    bool? loading,
    bool? failed,
  }) =>
      _AnalysedReport(
        report: report,
        analysis: analysis ?? this.analysis,
        loading: loading ?? this.loading,
        failed: failed ?? this.failed,
      );
}

// ── Screen ────────────────────────────────────────────────────────────────────
class PredictionsScreen extends StatefulWidget {
  const PredictionsScreen({super.key});

  @override
  State<PredictionsScreen> createState() => _PredictionsScreenState();
}

class _PredictionsScreenState extends State<PredictionsScreen> {
  bool _serverOnline = false;
  bool _checkingServer = true;
  bool _loadingReports = true;
  String? _loadError;

  List<_AnalysedReport> _items = [];

  // ── Firestore: fetch plant_reports ───────────────────────────────────────
  Future<List<_PlantReport>> _fetchPlantReports() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('plant_reports')
        .orderBy('submittedAt', descending: true)
        .get();
    return snapshot.docs
        .map((d) => _PlantReport.fromMap(d.id, d.data()))
        .toList();
  }

  // ── Firestore: read cached analysis from ml_predictions ──────────────────
  Future<ContextualAnalysisResult?> _fetchCachedPrediction(
      String reportId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('ml_predictions')
          .doc(reportId)
          .get();
      if (doc.exists && doc.data() != null) {
        return ContextualAnalysisResult.fromJson(
            doc.data()! as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Cache fetch error for $reportId: $e');
    }
    return null;
  }

  // ── Firestore: write analysis result to ml_predictions ───────────────────
  Future<void> _savePrediction(
    String reportId,
    String date,
    String env,
    ContextualAnalysisResult result,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('ml_predictions')
          .doc(reportId)
          .set(result.toFirestoreMap(
            reportId: reportId,
            date: date,
            env: env,
          ));
    } catch (e) {
      debugPrint('Cache save error for $reportId: $e');
    }
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _checkServer().then((_) => _loadAndAnalyse());
  }

  Future<void> _checkServer() async {
    final online = await MLService.isServerReachable();
    if (mounted) {
      setState(() {
        _serverOnline = online;
        _checkingServer = false;
      });
    }
  }

  Future<void> _loadAndAnalyse() async {
    setState(() {
      _loadingReports = true;
      _loadError = null;
    });

    List<_PlantReport> reports;
    try {
      reports = await _fetchPlantReports();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingReports = false;
          _loadError = 'Could not load reports from Firestore: $e';
        });
      }
      return;
    }

    if (reports.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingReports = false;
          _items = [];
        });
      }
      return;
    }

    // Seed items as loading
    if (mounted) {
      setState(() {
        _loadingReports = false;
        _items = reports
            .map((r) => _AnalysedReport(report: r, loading: true))
            .toList();
      });
    }

    // Build prior-score string for trend computation (oldest first)
    final priorScoresList = <double>[];

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];

      // 1. Check ml_predictions cache first
      final cached = await _fetchCachedPrediction(item.report.id);
      if (cached != null) {
        priorScoresList.add(cached.trendScore);
        if (mounted) {
          setState(() {
            _items[i] = item.copyWith(analysis: cached, loading: false);
          });
        }
        continue;
      }

      // 2. No cache — call ML server (F2 + F3)
      ContextualAnalysisResult? result;
      if (_serverOnline && item.report.imageUrl.isNotEmpty) {
        result = await MLService.runContextualAnalysisFromUrl(
          imageUrl: item.report.imageUrl,
          location: item.report.location,
          environmentalCondition: item.report.environment,
          degradationIndicator: item.report.degradationIndicator,
          observerNotes: item.report.description,
          severity: item.report.severity,
          priorScores: priorScoresList.join(','),
        );
      }

      if (result != null) {
        priorScoresList.add(result.trendScore);
        // 3. Persist to ml_predictions so next load uses cache
        await _savePrediction(
          item.report.id,
          item.report.date,
          item.report.environment,
          result,
        );
        if (mounted) {
          setState(() {
            _items[i] = item.copyWith(analysis: result, loading: false);
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _items[i] = item.copyWith(loading: false, failed: true);
          });
        }
      }
    }
  }

  // ── Force re-analyse a single report (clears cache first) ────────────────
  Future<void> _reanalyse(int index) async {
    final item = _items[index];
    // Delete cached entry
    try {
      await FirebaseFirestore.instance
          .collection('ml_predictions')
          .doc(item.report.id)
          .delete();
    } catch (_) {}

    setState(() {
      _items[index] = _AnalysedReport(report: item.report, loading: true);
    });

    if (!_serverOnline || item.report.imageUrl.isEmpty) {
      setState(() {
        _items[index] =
            _AnalysedReport(report: item.report, loading: false, failed: true);
      });
      return;
    }

    final priorScores = _items
        .where((i) => i.analysis != null)
        .map((i) => i.analysis!.trendScore.toString())
        .join(',');

    final result = await MLService.runContextualAnalysisFromUrl(
      imageUrl: item.report.imageUrl,
      location: item.report.location,
      environmentalCondition: item.report.environment,
      degradationIndicator: item.report.degradationIndicator,
      observerNotes: item.report.description,
      severity: item.report.severity,
      priorScores: priorScores,
    );

    if (result != null) {
      await _savePrediction(
        item.report.id,
        item.report.date,
        item.report.environment,
        result,
      );
      if (mounted) {
        setState(() {
          _items[index] =
              _AnalysedReport(report: item.report, analysis: result);
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _items[index] =
              _AnalysedReport(report: item.report, loading: false, failed: true);
        });
      }
    }
  }

  // ── Summary helpers ───────────────────────────────────────────────────────
  int get _totalReports => _items.length;

  String get _overallTrend {
    final done = _items.where((i) => i.analysis != null).toList();
    if (done.isEmpty) return 'Calculating…';
    final stressed = done.where((i) => i.analysis!.healthStatus == 'Stressed').length;
    final healthy = done.where((i) => i.analysis!.healthStatus == 'Healthy').length;
    final declining = done.where((i) => i.analysis!.trendDirection == 'Declining').length;
    if (stressed >= 3 || declining >= 3) return 'Declining';
    if (healthy >= done.length * 0.6) return 'Stable';
    if (stressed > healthy) return 'Declining';
    return 'Stable';
  }

  String get _overallHealth {
    final done = _items.where((i) => i.analysis != null).toList();
    if (done.isEmpty) return '—';
    final stressed = done.where((i) => i.analysis!.healthStatus == 'Stressed').length;
    final healthy = done.where((i) => i.analysis!.healthStatus == 'Healthy').length;
    if (stressed >= done.length * 0.5) return 'Stressed';
    return 'Healthy';
  }

  int get _alertCount =>
      _items.where((i) => (i.analysis?.alertScore ?? 0) >= 7).length;

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadAndAnalyse,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: "ML Health Predictions"),
              _buildServerBanner(),
              const SizedBox(height: 14),
              _buildSpeciesBanner(),
              const SizedBox(height: 14),

              if (_loadingReports)
                _buildLoadingSkeleton()
              else if (_loadError != null)
                _buildErrorBanner(_loadError!)
              else if (_items.isEmpty)
                _buildEmptyState()
              else ...[
                _buildCountAndTrendRow(),
                const SizedBox(height: 14),
                _buildOverallAnalysisCard(),
                const SizedBox(height: 20),

                Text(
                  "Submission History",
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 10),
                ...List.generate(
                  _items.length,
                  (i) => _buildHistoryCard(i),
                ),
              ],

              // const SizedBox(height: 20),
              // const InfoNote(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Species banner ────────────────────────────────────────────────────────
  Widget _buildSpeciesBanner() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.accentBg,
          borderRadius: BorderRadius.circular(12),
          border: const Border(
              left: BorderSide(color: AppColors.primary, width: 4)),
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
              "Thaba-Nchu, Free State · ML F2 + F3 · Results cached in ml_predictions",
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      );

  // ── Server status banner ──────────────────────────────────────────────────
  Widget _buildServerBanner() {
    if (_checkingServer) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: const Row(children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text("Checking ML server…",
              style: TextStyle(fontSize: 13)),
        ]),
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
            color: _serverOnline
                ? const Color(0xFF27AE60)
                : Colors.orange),
      ),
      child: Row(children: [
        Icon(
          _serverOnline
              ? Icons.check_circle
              : Icons.warning_amber_rounded,
          color:
              _serverOnline ? const Color(0xFF27AE60) : Colors.orange,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _serverOnline
                ? "ML server online · F2 + F3 pipeline active · Results saved to ml_predictions"
                : "ML server offline · Cached results will still display · Start uvicorn on port 8000 for new analyses",
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
            setState(() => _checkingServer = true);
            _checkServer();
          },
          child: const Icon(Icons.refresh,
              size: 16, color: AppColors.textSecondary),
        ),
      ]),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Column(
          children: [
            const Icon(Icons.eco, size: 52, color: AppColors.primarySoft),
            const SizedBox(height: 12),
            Text(
              "No reports yet",
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Submit a plant report to see ML predictions here.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );

  // ── Count + trend row ─────────────────────────────────────────────────────
  Widget _buildCountAndTrendRow() {
    final trend = _overallTrend;
    final health = _overallHealth;
    final healthColor = _healthColor(health);
    final trendColor = _trendColor(trend);

    return Row(children: [
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSoft),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 6)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$_totalReports",
                style: GoogleFonts.montserrat(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              Text(
                "total reports",
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              if (_alertCount > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEC),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "⚠ $_alertCount alert(s)",
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFFE74C3C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: healthColor, width: 4)),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 6)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                health,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: healthColor,
                ),
              ),
              const SizedBox(height: 2),
              Row(children: [
                Icon(_trendIcon(trend), size: 14, color: trendColor),
                const SizedBox(width: 4),
                Text(
                  trend,
                  style: TextStyle(
                      fontSize: 12,
                      color: trendColor,
                      fontWeight: FontWeight.w600),
                ),
              ]),
              const SizedBox(height: 4),
              const Text(
                "overall status",
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  // ── Overall analysis card ─────────────────────────────────────────────────
  Widget _buildOverallAnalysisCard() {
    final done = _items.where((i) => i.analysis != null).toList();
    final total = done.isEmpty ? 1 : done.length;
    final degraded =
        done.where((i) => i.analysis!.healthStatus == 'Degraded').length;
    final stressed =
        done.where((i) => i.analysis!.healthStatus == 'Stressed').length;
    final healthy =
        done.where((i) => i.analysis!.healthStatus == 'Healthy').length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Overall Analysis",
            style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark),
          ),
          const SizedBox(height: 12),

          if (done.isNotEmpty) ...[
            // Distribution bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(children: [
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
                if (degraded == 0 && stressed == 0 && healthy == 0)
                  Expanded(
                      child: Container(
                          height: 10, color: AppColors.borderSoft)),
              ]),
            ),
            const SizedBox(height: 8),
            Row(children: [
              _legendDot(const Color(0xFFE74C3C),
                  "Degraded ($degraded)"),
              const SizedBox(width: 12),
              _legendDot(const Color(0xFFF39C12),
                  "Stressed ($stressed)"),
              const SizedBox(width: 12),
              _legendDot(
                  const Color(0xFF27AE60), "Healthy ($healthy)"),
            ]),
            const SizedBox(height: 14),
          ] else ...[
            const Text(
              "Analysing reports…",
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
          ],

          _buildTrendSummaryText(degraded, stressed, healthy, total),
        ],
      ),
    );
  }

  Widget _buildTrendSummaryText(
      int degraded, int stressed, int healthy, int total) {
    final trend = _overallTrend;
    final decliningCount = _items
        .where((i) => i.analysis?.trendDirection == 'Declining')
        .length;

    String text;
    if (trend == 'Declining') {
      text =
          "Overall population trend is DECLINING. $degraded of $total reports "
          "classify as Degraded, with $decliningCount submission(s) showing a "
          "worsening trajectory. Researcher notification is recommended. "
          "This aligns with documented over-harvesting pressure in the Free "
          "State (Vukeya et al., 2024).";
    } else if (_overallHealth == 'Stressed') {
      text =
          "Population is under STRESS. $stressed of $total reports are Stressed "
          "and $degraded are Degraded. Continued monitoring is required. "
          "Environmental conditions and reported degradation indicators have "
          "been factored into this assessment.";
    } else {
      text =
          "Population appears STABLE. $healthy of $total reports classify as "
          "Healthy. Continue routine monthly monitoring as per the study "
          "protocol. No immediate researcher escalation required.";
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentBg,
        borderRadius: BorderRadius.circular(10),
        border: const Border(
            left: BorderSide(color: AppColors.primary, width: 3)),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12,
              height: 1.6,
              color: AppColors.textPrimary)),
    );
  }

  // ── History card per report ───────────────────────────────────────────────
  Widget _buildHistoryCard(int index) {
    final item = _items[index];

    if (item.loading) {
      return _buildHistoryShell(
        item.report,
        index: index,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Text("Running F2 + F3 analysis…",
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary)),
          ]),
        ),
      );
    }

    if (item.failed || item.analysis == null) {
      return _buildHistoryShell(
        item.report,
        index: index,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.report.imageUrl.isEmpty
                      ? "No image URL stored — cannot run analysis."
                      : _serverOnline
                          ? "Analysis failed — check ML server logs."
                          : "ML server offline — cached result unavailable.",
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF856404)),
                ),
              ),
            ]),
            if (_serverOnline && item.report.imageUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _reanalyse(index),
                child: const Text(
                  "Tap to retry",
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final a = item.analysis!;
    final hColor = _healthColor(a.healthStatus);

    return _buildHistoryShell(
      item.report,
      index: index,
      borderColor: hColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Health + trend + risk
          Row(children: [
            _statusPill(a.healthStatus, hColor),
            const SizedBox(width: 8),
            Icon(_trendIcon(a.trendDirection),
                size: 14, color: _trendColor(a.trendDirection)),
            const SizedBox(width: 3),
            Text(
              a.trendDirection,
              style: TextStyle(
                  fontSize: 11,
                  color: _trendColor(a.trendDirection),
                  fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _riskColor(a.riskLevel).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _riskColor(a.riskLevel).withOpacity(0.4)),
              ),
              child: Text(
                "${a.riskLevel} Risk · ${a.alertScore}/10",
                style: TextStyle(
                    fontSize: 10,
                    color: _riskColor(a.riskLevel),
                    fontWeight: FontWeight.bold),
              ),
            ),
          ]),

          const SizedBox(height: 8),

          // Damage chips
          if (a.damageDetected && a.damageLabels.isNotEmpty)
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: a.damageLabels.map(_damageChip).toList(),
            )
          else
            const Text("✓ No damage detected",
                style: TextStyle(
                    fontSize: 11, color: Color(0xFF27AE60))),

          const SizedBox(height: 8),

          // Prediction note
          Text(a.predictionNote,
              style: const TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: AppColors.textPrimary)),

          // Expandable comprehensive report
          if (a.comprehensiveReport.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ExpandableReport(report: a.comprehensiveReport),
          ],

          // Re-analyse button
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _reanalyse(index),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh,
                    size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  "Re-analyse",
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryShell(
    _PlantReport r, {
    required int index,
    required Widget child,
    Color? borderColor,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: borderColor != null
              ? Border(left: BorderSide(color: borderColor, width: 4))
              : Border.all(color: AppColors.borderSoft),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 6)
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date + location + image thumbnail
              Row(children: [
                if (r.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      r.imageUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 44,
                        height: 44,
                        color: AppColors.borderSoft,
                        child: const Icon(Icons.eco,
                            size: 20, color: AppColors.primarySoft),
                      ),
                    ),
                  ),
                if (r.imageUrl.isNotEmpty) const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accentBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 10,
                                color: AppColors.primaryDark),
                            const SizedBox(width: 3),
                            Text(r.date,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryDark)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.location_on,
                            size: 11, color: AppColors.primary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(r.location,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ),
                      ]),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      );

  // ── Skeleton ──────────────────────────────────────────────────────────────
  Widget _buildLoadingSkeleton() => Column(children: [
        _shimmer(height: 70, radius: 14),
        const SizedBox(height: 12),
        _shimmer(height: 100, radius: 14),
        const SizedBox(height: 12),
        _shimmer(height: 80, radius: 14),
      ]);

  Widget _shimmer({double height = 60, double radius = 8}) => Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.borderSoft.withOpacity(0.5),
          borderRadius: BorderRadius.circular(radius),
        ),
      );

  Widget _buildErrorBanner(String msg) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(12),
          border: const Border(
              left: BorderSide(color: Colors.orange, width: 4)),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF856404)))),
        ]),
      );

  // ── Small reusable widgets ────────────────────────────────────────────────
  Widget _statusPill(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11)),
      );

  Widget _damageChip(String label) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFFE74C3C).withOpacity(0.4)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: Color(0xFFE74C3C),
                fontWeight: FontWeight.w600)),
      );

  Widget _legendDot(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
        ],
      );

  Color _healthColor(String s) {
    switch (s) {
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

  Color _riskColor(String r) {
    switch (r) {
      case 'Critical':
        return const Color(0xFFE74C3C);
      case 'High':
        return const Color(0xFFE67E22);
      case 'Moderate':
        return const Color(0xFFF39C12);
      default:
        return const Color(0xFF27AE60);
    }
  }

  Color _trendColor(String t) {
    switch (t) {
      case 'Improving':
        return const Color(0xFF27AE60);
      case 'Declining':
        return const Color(0xFFE74C3C);
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _trendIcon(String t) {
    switch (t) {
      case 'Improving':
        return Icons.trending_up;
      case 'Declining':
        return Icons.trending_down;
      default:
        return Icons.trending_flat;
    }
  }
}

// ── Expandable comprehensive report widget ────────────────────────────────────
class _ExpandableReport extends StatefulWidget {
  final String report;
  const _ExpandableReport({required this.report});

  @override
  State<_ExpandableReport> createState() => _ExpandableReportState();
}

class _ExpandableReportState extends State<_ExpandableReport> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.accentBg,
          borderRadius: BorderRadius.circular(8),
          border: const Border(
              left: BorderSide(color: AppColors.primary, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(
                "Comprehensive Report",
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark),
              ),
              const Spacer(),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 16,
                color: AppColors.primary,
              ),
            ]),
            if (_expanded) ...[
              const SizedBox(height: 6),
              Text(
                widget.report,
                style: const TextStyle(
                    fontSize: 11,
                    height: 1.6,
                    color: AppColors.textPrimary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}