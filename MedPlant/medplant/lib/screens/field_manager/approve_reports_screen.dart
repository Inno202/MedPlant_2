// lib/screens/field_manager/approve_reports_screen.dart
//
// Researcher review queue for flagged (unidentified) submissions.
//
// KEY FIX: the ML pipeline can't confirm a species for these reports, so
// they're stored with speciesName == "Unidentified — pending review" (see
// kPlaceholderSpeciesNames below, mirrored from add_report_screen.dart).
// Approving used to call DatabaseService.approveReport(docId) with no
// species name, which never overwrote that placeholder — so approved
// reports kept the placeholder name forever, and any downstream screen
// that queries/joins on speciesName (predictions, species-grouped views,
// prior-score lookups) silently never found them.
//
// Now the researcher must type the confirmed species name into a required
// field before the Approve button will do anything; that name is passed
// through as `confirmedSpeciesName` to DatabaseService.approveReport,
// which writes it to the doc and flips `identified` to true.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medplant/services/database_service.dart';
import 'package:medplant/widgets/section_header.dart';
import '/constants/app_colors.dart';

/// Species names that mean "not actually identified" — used to decide
/// whether to prefill the confirm-species field or leave it blank.
const List<String> kPlaceholderSpeciesNames = [
  'Unidentified — pending review',
  'Unknown species',
  '',
];

class ApproveReportsScreen extends StatefulWidget {
  const ApproveReportsScreen({super.key});

  @override
  State<ApproveReportsScreen> createState() => _ApproveReportsScreenState();
}

class _ApproveReportsScreenState extends State<ApproveReportsScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // One species-name controller per report, keyed by docId, so text typed
  // while reviewing one card survives page swipes back and forth.
  final Map<String, TextEditingController> _speciesControllers = {};

  TextEditingController _speciesControllerFor(
      String docId, Map<String, dynamic> data) {
    return _speciesControllers.putIfAbsent(docId, () {
      final existing = (data['speciesName'] as String?)?.trim() ?? '';
      final prefill = kPlaceholderSpeciesNames.contains(existing)
          ? ''
          : existing;
      return TextEditingController(text: prefill);
    });
  }

  @override
  void dispose() {
    for (final c in _speciesControllers.values) {
      c.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _approve(
      String docId, TextEditingController speciesController) async {
    final speciesName = speciesController.text.trim();

    if (speciesName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Please enter the confirmed species name before approving."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await DatabaseService.approveReport(docId,
        confirmedSpeciesName: speciesName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Approved — $speciesName added to reports feed"),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _decline(
      String docId, TextEditingController speciesController) async {
    final label = speciesController.text.trim().isEmpty
        ? "this report"
        : speciesController.text.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Decline report?"),
        content: Text(
          "'$label' will be permanently hidden. This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Decline",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await DatabaseService.declineReport(docId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Report declined and removed from queue"),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        // Single-field query — no composite index needed
        stream: DatabaseService.getPendingFlaggedReportsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      "Failed to load pending reports.",
                      style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${snapshot.error}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          final safeIndex = _currentIndex.clamp(0, docs.length - 1);
          if (safeIndex != _currentIndex) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _currentIndex = safeIndex);
            });
          }

          final currentDoc = docs[safeIndex];
          final currentData = currentDoc.data() as Map<String, dynamic>;
          final currentSpeciesController =
              _speciesControllerFor(currentDoc.id, currentData);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 16, top: 8),
                child: SectionHeader(title: "Pending Reports"),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Text(
                    "${docs.length} report${docs.length == 1 ? '' : 's'} awaiting review",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF856404),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: docs.length,
                  onPageChanged: (index) =>
                      setState(() => _currentIndex = index),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final controller =
                        _speciesControllerFor(docs[index].id, data);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SingleChildScrollView(
                        child: _buildReportCard(data, controller),
                      ),
                    );
                  },
                ),
              ),

              _buildDots(docs.length),
              _buildActionButtons(currentDoc.id, currentSpeciesController),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 64, color: AppColors.primarySoft),
            const SizedBox(height: 16),
            Text(
              "All reports reviewed",
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "No pending flagged submissions.\nNew unidentified reports will appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ── Report card — shell matches PlantCard/ReportCard, content stays in
  // the boxed "textfield" style, no icons anywhere on this card. ─────────
  Widget _buildReportCard(
      Map<String, dynamic> data, TextEditingController speciesController) {
    final imageUrl = data['imageUrl'] ?? '';
    final location = data['location'] ?? 'Unknown location';
    final gps = (data['gpsCoordinates'] as String?)?.trim() ?? '';
    final environment = data['environmentalCondition'] ?? 'Unknown';
    final notes = data['observerNotes'] ?? 'No notes';
    final confidence =
        ((data['confidence'] ?? 0.0) * 100).toStringAsFixed(0);
    final severity = data['severity'] ?? '1';
    final indicator = data['degradationIndicator'] ?? 'None';
    final submittedAt = data['submittedAt'] as Timestamp?;
    final dateStr = submittedAt != null
        ? submittedAt.toDate().toString().split(' ').first
        : 'Unknown date';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 40, 20, 0.07),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Image ─────────────────────────────────────────────────
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      color: AppColors.accentBg,
                      alignment: Alignment.center,
                      child: const Text(
                        "Image unavailable",
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : Container(
                    height: 200,
                    color: AppColors.accentBg,
                    alignment: Alignment.center,
                    child: const Text(
                      "No image",
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Flag banner — text only, no icon
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Text(
                    "Flagged for review — the system could not identify this species.",
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF856404),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Required, editable species assignment ────────────
                _speciesNameField(speciesController),

                // ── Read-only details, boxed "textfield" style ────────
                _detailRow("Location", location),
                _detailRow(
                    "GPS Coordinates", gps.isEmpty ? "Not captured" : gps),
                _detailRow("Environmental Condition", environment),
                _detailRow("Degradation Indicator", indicator),
                _detailRow("Severity Reported", "$severity / 5"),
                _detailRow("Observer Notes", notes),
                _detailRow("Submitted", dateStr),
                _detailRow(
                    "ML Confidence", "$confidence% — species not confirmed"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _speciesNameField(TextEditingController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.03), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "CONFIRM SPECIES NAME *",
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.8,
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextFormField(
            controller: controller,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: "e.g. Lessertia frutescens",
              hintStyle: TextStyle(
                fontWeight: FontWeight.normal,
                color: Colors.grey,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: const [
          BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.03), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 0.8,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(value,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDots(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (index) {
          final isActive = index == _currentIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 12 : 8,
            height: isActive ? 12 : 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? AppColors.primary
                  : AppColors.borderSoft,
            ),
          );
        }),
      ),
    );
  }

  // ── Approve / Decline — stacked full-width, matching the primary/
  // outlined button layout used on LoginScreen and RegisterScreen. ───────
  Widget _buildActionButtons(
      String docId, TextEditingController speciesController) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50)),
              ),
              onPressed: () => _approve(docId, speciesController),
              child: Text(
                "Approve",
                style: GoogleFonts.lato(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.red, width: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50)),
              ),
              onPressed: () => _decline(docId, speciesController),
              child: Text(
                "Decline",
                style: GoogleFonts.lato(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}