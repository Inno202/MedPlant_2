// lib/screens/user/predictions_screen.dart
//
// FINAL ML ARCHITECTURE (matches ml_server/main.py):
//   F1 — Species Identification (unchanged, not used on this screen)
//   F2 — Leaf Health: BINARY Healthy / Stressed. Supporting visual evidence
//        (discolouration, browning, wilting, lesions, stem irregularity)
//        is only present when health_status == 'Stressed'.
//   F3 — Trend & Monitoring: Improving / Stable / Declining, computed from
//        a linear-regression slope over prior F2 scores + the current score.
//
// There is no 'Degraded' class anywhere in this screen. Population-level
// concern is expressed through F3's trend plus how many recent reports are
// Stressed — not a third health class.
//
// Flow:
//  1. On load → fetch plant_reports collection from Firestore (real data)
//  2. Show report count + overall trend summary (top section, preserved from original)
//  3. For each report → check ml_predictions for cached analysis; if absent
//     → call MLService.runContextualAnalysisFromUrl() (F2+F3) using the
//     report's stored imageUrl + context fields → save result to ml_predictions
//  4. Display submission history timeline from ml_predictions, newest first
//
// NOTE: Because firebase_core / cloud_firestore are not yet in pubspec.yaml,
// the Firestore calls are wrapped in a FirestoreService abstraction that uses
// dummy data as a fallback when firebase is not initialised. Swap the
// _PlantReportData list and _savePrediction() body for real Firestore calls
// once you add the firebase dependencies.

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
  final String environment;        // maps to environmental_condition
  final String description;        // observer notes
  final String degradationIndicator;
  final String severity;           // "1"–"5"

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

  /// Build from a Firestore document map.
  factory _PlantReport.fromMap(String id, Map<String, dynamic> m) =>
      _PlantReport(
        id: id,
        imageUrl: m['image'] ?? m['imageUrl'] ?? '',
        location: m['location'] ?? '',
        date: m['date'] ?? '',
        environment: m['environment'] ?? 'Normal',
        description: m['description'] ?? '',
        degradationIndicator: m['degradation_indicator'] ?? 'None observed',
        severity: m['severity']?.toString() ?? '1',
      );
}

// ── Merged view model: one Firestore report + its ML analysis ────────────────
class _AnalysedReport {
  final _PlantReport report;
  final ContextualAnalysisResult? analysis; // null while loading
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

  // ── Firestore helpers (swap bodies for real firebase calls) ───────────────
  Future<List<_PlantReport>> _fetchPlantReports() async {
    // ── REAL FIRESTORE (uncomment once firebase is added to pubspec.yaml) ──
    // final snapshot = await FirebaseFirestore.instance
    //     .collection('plant_reports')
    //     .orderBy('date', descending: true)
    //     .get();
    // return snapshot.docs
    //     .map((d) => _PlantReport.fromMap(d.id, d.data()))
    //     .toList();

    // ── FALLBACK / DEMO: mirrors the dummy data in ViewReportsScreen ─────
    await Future.delayed(const Duration(milliseconds: 600));
    return [
      const _PlantReport(
        id: 'rpt_001',
        imageUrl: 'https://images.unsplash.com/photo-1473773508845-188df298d2d1?w=800',
        location: 'Thaba-Nchu hillside, near stream',
        date: '2026-05-08',
        environment: 'Hot',
        description:
            'Significant browning on lower leaves. Several stems appear wilted. '
            'Traditional healer noted reduced plant population in this area.',
        degradationIndicator: 'Over-harvesting',
        severity: '4',
      ),
      const _PlantReport(
        id: 'rpt_002',
        imageUrl: 'https://images.unsplash.com/photo-1501004318641-b39e6451bec6?w=800',
        location: 'Thaba-Nchu eastern slope',
        date: '2026-05-03',
        environment: 'Dry',
        description:
            'Mild discolouration on upper leaves. Plant otherwise appears structurally intact. '
            'Dry soil noted around root base.',
        degradationIndicator: 'Drought stress',
        severity: '2',
      ),
      const _PlantReport(
        id: 'rpt_003',
        imageUrl: 'https://images.unsplash.com/photo-1502082553048-f009c37129b9?w=800',
        location: 'Thaba-Nchu valley, near river bank',
        date: '2026-04-28',
        environment: 'Wet / After rain',
        description:
            'Plant looks healthy after recent rainfall. New shoots visible at the base. '
            'Good leaf coverage and normal colouration.',
        degradationIndicator: 'None observed',
        severity: '1',
      ),
      const _PlantReport(
        id: 'rpt_004',
        imageUrl: 'https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=800',
        location: 'Thaba-Nchu community gardens',
        date: '2026-04-21',
        environment: 'Normal',
        description:
            'Healthy specimen. No visible stress indicators. '
            'Community member noted this area is protected from livestock.',
        degradationIndicator: 'None observed',
        severity: '1',
      ),
      const _PlantReport(
        id: 'rpt_005',
        imageUrl: 'https://images.unsplash.com/photo-1471193945509-9ad0617afabf?w=800',
        location: 'Thaba-Nchu northern boundary',
        date: '2026-04-14',
        environment: 'Windy',
        description:
            'Wind damage visible on outer leaves. Some stem bending observed. '
            'Overall plant appears alive but stressed.',
        degradationIndicator: 'None observed',
        severity: '2',
      ),
    ];
  }

  Future<ContextualAnalysisResult?> _fetchCachedPrediction(
      String reportId) async {
    // ── REAL FIRESTORE ──
    // final doc = await FirebaseFirestore.instance
    //     .collection('ml_predictions')
    //     .doc(reportId)
    //     .get();
    // if (doc.exists) {
    //   return ContextualAnalysisResult.fromJson(
    //       doc.data()! as Map<String, dynamic>);
    // }
    return null; // no cache in demo
  }

  Future<void> _savePrediction(
      String reportId, String date, String env,
      ContextualAnalysisResult result) async {
    // ── REAL FIRESTORE ──
    // await FirebaseFirestore.instance
    //     .collection('ml_predictions')
    //     .doc(reportId)
    //     .set(result.toFirestoreMap(
    //       reportId: reportId,
    //       date: date,
    //       env: env,
    //     ));
    debugPrint('Prediction saved for $reportId (demo — no Firestore)');
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
          _loadError = 'Could not load reports: $e';
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

    // Build prior-score string for F3's trend computation (oldest → newest,
    // in the same 0.0=healthy .. 1.0=stressed scale F2 produces).
    final priorScoresList = <double>[];

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];

      // Check cache first
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

      // Run F2+F3 via ML server
      ContextualAnalysisResult? result;
      if (_serverOnline) {
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
        await _savePrediction(
            item.report.id, item.report.date, item.report.environment, result);
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

  // ── Summary helpers (binary F2 + F3 trend) ────────────────────────────────
  int get _totalReports => _items.length;

  List<_AnalysedReport> get _doneItems =>
      _items.where((i) => i.analysis != null).toList();

  int get _stressedCount =>
      _doneItems.where((i) => i.analysis!.healthStatus == 'Stressed').length;

  int get _healthyCount =>
      _doneItems.where((i) => i.analysis!.healthStatus == 'Healthy').length;

  int get _decliningCount =>
      _doneItems.where((i) => i.analysis!.trendDirection == 'Declining').length;

  /// Overall population signal — driven by F3 trend across recent reports
  /// plus how many are currently Stressed. No 'Degraded' class involved.
  String get _overallTrend {
    final done = _doneItems;
    if (done.isEmpty) return 'Calculating…';
    if (_decliningCount >= 3 || _stressedCount >= done.length * 0.6) {
      return 'Declining';
    }
    if (_healthyCount >= done.length * 0.6) return 'Stable';
    return _stressedCount > _healthyCount ? 'Declining' : 'Stable';
  }

  /// Overall F2 signal — binary Healthy/Stressed, majority-based.
  String get _overallHealth {
    final done = _doneItems;
    if (done.isEmpty) return '—';
    return _stressedCount >= done.length * 0.5 ? 'Stressed' : 'Healthy';
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

              // ── Species focus ──────────────────────────────────────────
              _buildSpeciesBanner(),
              const SizedBox(height: 14),

              // ── Report count + overall trend (top section) ─────────────
              if (_loadingReports)
                _buildLoadingSkeleton()
              else if (_loadError != null)
                _buildErrorBanner(_loadError!)
              else ...[
                _buildCountAndTrendRow(),
                const SizedBox(height: 14),
                _buildOverallAnalysisCard(),
                const SizedBox(height: 20),

                // ── Submission history ─────────────────────────────────
                Text(
                  "Submission History",
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 10),
                ..._items.map(_buildHistoryCard),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
            "Thaba-Nchu, Free State · F2 leaf health (binary) + F3 trend analysis",
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ]),
      );

  // ── Server banner ─────────────────────────────────────────────────────────
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
          Text("Checking ML server…", style: TextStyle(fontSize: 13)),
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
            color: _serverOnline ? const Color(0xFF27AE60) : Colors.orange),
      ),
      child: Row(children: [
        Icon(
          _serverOnline ? Icons.check_circle : Icons.warning_amber_rounded,
          color: _serverOnline ? const Color(0xFF27AE60) : Colors.orange,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _serverOnline
                ? "ML server online · F2 (binary health) + F3 (trend) active"
                : "ML server offline · Analyses will be skipped — start uvicorn on port 8000",
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
          child:
              const Icon(Icons.refresh, size: 16, color: AppColors.textSecondary),
        ),
      ]),
    );
  }

  // ── Report count + overall trend row (top section from original screen) ───
  Widget _buildCountAndTrendRow() {
    final trend = _overallTrend;
    final health = _overallHealth;
    final healthColor = _healthColor(health);
    final trendColor = _trendColor(trend);

    return Row(children: [
      // Report count card
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
                style: TextStyle(
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
      // Overall health card
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
              Text(
                "F2 health · F3 trend",
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  // ── Overall analysis card (binary distribution + trend breakdown) ─────────
  Widget _buildOverallAnalysisCard() {
    final done = _doneItems;
    final stressed = _stressedCount;
    final healthy = _healthyCount;
    final declining = _decliningCount;
    final improving =
        done.where((i) => i.analysis!.trendDirection == 'Improving').length;
    final stable = done.length - declining - improving;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          "F2 · Leaf Health Distribution",
          style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark),
        ),
        const SizedBox(height: 12),

        // Binary distribution bar — Healthy vs Stressed only
        if (done.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(children: [
              if (stressed > 0)
                Expanded(
                    flex: stressed,
                    child: Container(height: 10, color: const Color(0xFFF39C12))),
              if (healthy > 0)
                Expanded(
                    flex: healthy,
                    child: Container(height: 10, color: const Color(0xFF27AE60))),
              if (stressed == 0 && healthy == 0)
                Expanded(
                    child: Container(
                        height: 10, color: AppColors.borderSoft)),
            ]),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _legendDot(const Color(0xFFF39C12), "Stressed ($stressed)"),
            const SizedBox(width: 12),
            _legendDot(const Color(0xFF27AE60), "Healthy ($healthy)"),
          ]),

          const SizedBox(height: 16),
          Text(
            "F3 · Trend Breakdown",
            style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _legendDot(const Color(0xFFE74C3C), "Declining ($declining)"),
            const SizedBox(width: 12),
            _legendDot(AppColors.textSecondary, "Stable ($stable)"),
            const SizedBox(width: 12),
            _legendDot(const Color(0xFF27AE60), "Improving ($improving)"),
          ]),
          const SizedBox(height: 14),
        ] else ...[
          const Text(
            "Analysing reports…",
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
        ],

        // Trend summary sentence
        _buildTrendSummaryText(stressed, healthy, declining, done.length),
      ]),
    );
  }

  Widget _buildTrendSummaryText(
      int stressed, int healthy, int declining, int total) {
    final trend = _overallTrend;

    String text;
    if (total == 0) {
      text = "Analysing submitted reports…";
    } else if (trend == 'Declining') {
      text =
          "Overall population signal is DECLINING. $stressed of $total reports "
          "classify as Stressed (F2), with $declining submission(s) showing a "
          "worsening trajectory (F3). Researcher notification is recommended "
          "once this species accumulates repeated Stressed + Declining reports. "
          "This aligns with documented over-harvesting pressure in the Free "
          "State (Vukeya et al., 2024).";
    } else {
      text =
          "Population appears STABLE. $healthy of $total reports classify as "
          "Healthy (F2), and the F3 trend across recent submissions is not "
          "declining. Continue routine monthly monitoring as per the study "
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
              fontSize: 12, height: 1.6, color: AppColors.textPrimary)),
    );
  }

  // ── History card per report ───────────────────────────────────────────────
  Widget _buildHistoryCard(_AnalysedReport item) {
    if (item.loading) {
      return _buildHistoryShell(
        item.report,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Text("Running F2 (leaf health) + F3 (trend) analysis…",
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
      );
    }

    if (item.failed || item.analysis == null) {
      return _buildHistoryShell(
        item.report,
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _serverOnline
                  ? "Analysis failed — check ML server logs."
                  : "ML server offline — start uvicorn on port 8000.",
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF856404)),
            ),
          ),
        ]),
      );
    }

    final a = item.analysis!;
    final hColor = _healthColor(a.healthStatus);

    return _buildHistoryShell(
      item.report,
      borderColor: hColor,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // F2 health + F3 trend row
        Row(children: [
          _statusPill(a.healthStatus, hColor),
          const SizedBox(width: 8),
          Icon(_trendIcon(a.trendDirection),
              size: 14, color: _trendColor(a.trendDirection)),
          const SizedBox(width: 3),
          Text(a.trendDirection,
              style: TextStyle(
                  fontSize: 11,
                  color: _trendColor(a.trendDirection),
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          // Monitoring priority badge — researcher follow-up urgency,
          // separate from the F2 Healthy/Stressed call.
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
              "${a.riskLevel} Priority · ${a.alertScore}/10",
              style: TextStyle(
                  fontSize: 10,
                  color: _riskColor(a.riskLevel),
                  fontWeight: FontWeight.bold),
            ),
          ),
        ]),

        const SizedBox(height: 8),

        // F2 supporting evidence — only ever present when Stressed
        if (a.damageDetected && a.damageLabels.isNotEmpty)
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: a.damageLabels.map(_damageChip).toList(),
          )
        else
          const Text("✓ No stress evidence detected",
              style: TextStyle(fontSize: 11, color: Color(0xFF27AE60))),

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
      ]),
    );
  }

  Widget _buildHistoryShell(
    _PlantReport r, {
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
              // Date + location
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today,
                        size: 10, color: AppColors.primaryDark),
                    const SizedBox(width: 3),
                    Text(r.date,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark)),
                  ]),
                ),
                const SizedBox(width: 8),
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
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      );

  // ── Skeleton while loading reports ────────────────────────────────────────
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
          border:
              const Border(left: BorderSide(color: Colors.orange, width: 4)),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF856404)))),
        ]),
      );

  // ── Reusable widgets ─────────────────────────────────────────────────────
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
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFFF39C12).withOpacity(0.4)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: Color(0xFFB8720A),
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

  /// F2 colour coding — binary only. 'Healthy' → green, everything else
  /// (i.e. 'Stressed') → amber. No 'Degraded' / red case exists.
  Color _healthColor(String s) {
    switch (s) {
      case 'Healthy':
        return const Color(0xFF27AE60);
      case 'Stressed':
        return const Color(0xFFF39C12);
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
                style: TextStyle(
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