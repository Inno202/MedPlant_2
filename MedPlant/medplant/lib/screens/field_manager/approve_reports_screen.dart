// lib/screens/field_manager/approve_reports_screen.dart
//
// Researcher review queue — three filterable tabs:
//   Pending   → Approve / Decline
//   Approved  → Revert to Declined (correct a wrong approval)
//   Declined  → Re-Approve (correct a mistaken decline)
//
// Uses the shared DetailedReportCard (also used by ViewReportsScreen) so
// both screens render report data identically. The card renders its own
// Approve/Decline buttons based on which callbacks are passed in — which
// callback maps to which action depends on the active filter tab.
//
// The system monitors a single registered species (Lessertia frutescens —
// see PlantIdentifier.categories in plant_identifier.py). "Approving" a
// flagged/unidentified report is therefore just a yes/no confirmation that
// the image IS that species — not a free-text species entry. Approve/
// Re-Approve always assigns kMonitoredSpeciesName.
//
// Reports are rendered as a plain scrollable list (ListView.builder), same
// browsing pattern as ViewReportsScreen — no swipe/slideshow navigation.
//
// Approved tab uses DatabaseService.getReviewTabDocsStream, which also
// includes legacy documents with no reviewStatus field (treated as
// approved everywhere else in the app — see isReportVisible). Pending and
// Declined use a plain single-field query — no composite index needed.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medplant/services/database_service.dart';
import 'package:medplant/widgets/detailed_report_card.dart';
import 'package:medplant/widgets/section_header.dart';
import '/constants/app_colors.dart';

/// The single species this system currently monitors — matches
/// PlantIdentifier.categories[0] in ml_server/plant_identifier.py.
/// Approving a report (flagged or not) confirms the image as this species;
/// there is nothing else for the researcher to type.
const String kMonitoredSpeciesName = 'Lessertia frutescens';

enum _ReviewFilter { pending, approved, declined }

extension on _ReviewFilter {
  String get status => switch (this) {
        _ReviewFilter.pending => 'pending',
        _ReviewFilter.approved => 'approved',
        _ReviewFilter.declined => 'declined',
      };

  String get label => switch (this) {
        _ReviewFilter.pending => 'Pending',
        _ReviewFilter.approved => 'Approved',
        _ReviewFilter.declined => 'Declined',
      };

  Color get color => switch (this) {
        _ReviewFilter.pending => Colors.orange,
        _ReviewFilter.approved => const Color(0xFF27AE60),
        _ReviewFilter.declined => const Color(0xFFE74C3C),
      };
}

class ApproveReportsScreen extends StatefulWidget {
  const ApproveReportsScreen({super.key});

  @override
  State<ApproveReportsScreen> createState() => _ApproveReportsScreenState();
}

class _ApproveReportsScreenState extends State<ApproveReportsScreen> {
  _ReviewFilter _filter = _ReviewFilter.pending;

  void _changeFilter(_ReviewFilter f) {
    if (f == _filter) return;
    setState(() => _filter = f);
  }

  // ── Actions ────────────────────────────────────────────────────────────
  /// Confirms the report as kMonitoredSpeciesName and publishes it to the
  /// feed. No text entry — this is a yes/no confirmation, not a data-entry
  /// step.
  Future<void> _approve(String docId) async {
    await DatabaseService.approveReport(
      docId,
      confirmedSpeciesName: kMonitoredSpeciesName,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _filter == _ReviewFilter.declined
              ? "Re-approved — restored to reports feed"
              : "Confirmed as $kMonitoredSpeciesName — added to reports feed",
        ),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _decline(String docId) async {
    final isRevert = _filter == _ReviewFilter.approved;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isRevert ? "Revert approval?" : "Decline report?"),
        content: Text(
          isRevert
              ? "This report will be removed from the public feed and moved to Declined. You can re-approve it again later if needed."
              : "This report will be hidden from the feed. You can re-approve it later from the Declined tab if this was a mistake.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isRevert ? "Revert" : "Decline",
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await DatabaseService.declineReport(docId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isRevert
            ? "Approval reverted — moved to Declined"
            : "Report declined and removed from queue"),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  /// Maps the active filter to the callbacks DetailedReportCard should get.
  /// The card only renders a button for a non-null callback.
  VoidCallback? _onApproveFor(String docId) {
    // Pending → confirm; Declined → re-approve. Approved has no approve action.
    if (_filter == _ReviewFilter.approved) return null;
    return () => _approve(docId);
  }

  VoidCallback? _onDeclineFor(String docId) {
    // Pending → decline; Approved → revert. Declined has no decline action.
    if (_filter == _ReviewFilter.declined) return null;
    return () => _decline(docId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<QueryDocumentSnapshot>>(
        stream: DatabaseService.getReviewTabDocsStream(_filter.status),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              children: [
                _buildHeader(),
                _buildFilterTabs(),
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }

          if (snapshot.hasError) {
            return Column(
              children: [
                _buildHeader(),
                _buildFilterTabs(),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            "Failed to load reports.",
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
                  ),
                ),
              ],
            );
          }

          // Client-side sort — newest first — since the query has no
          // .orderBy() (avoids needing a composite index).
          final docs = [...snapshot.data ?? <QueryDocumentSnapshot>[]];
          docs.sort((a, b) {
            final aTs = (a.data() as Map<String, dynamic>)['submittedAt']
                as Timestamp?;
            final bTs = (b.data() as Map<String, dynamic>)['submittedAt']
                as Timestamp?;
            if (aTs == null || bTs == null) return 0;
            return bTs.compareTo(aTs);
          });

          if (docs.isEmpty) {
            return Column(
              children: [
                _buildHeader(),
                _buildFilterTabs(),
                Expanded(child: _buildEmptyState()),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildFilterTabs(),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _filter.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _filter.color.withOpacity(0.4)),
                  ),
                  child: Text(
                    "${docs.length} ${_filter.label.toLowerCase()} report${docs.length == 1 ? '' : 's'}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _filter.color,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ── Plain scrollable list — same browsing pattern as
              // ViewReportsScreen, no swipe/slideshow. ────────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return DetailedReportCard(
                      key: ValueKey('report_card_${doc.id}'),
                      data: data,
                      onApprove: _onApproveFor(doc.id),
                      onDecline: _onDeclineFor(doc.id),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.only(left: 16, top: 8),
      child: SectionHeader(title: "Report Review"),
    );
  }

  // ── Filter tabs — Pending / Approved / Declined, each with a live count ──
  Widget _buildFilterTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: _ReviewFilter.values
            .map((f) => Expanded(child: _filterChip(f)))
            .toList(),
      ),
    );
  }

  Widget _filterChip(_ReviewFilter f) {
    final isActive = f == _filter;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () => _changeFilter(f),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? f.color.withOpacity(0.12) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isActive ? f.color : AppColors.borderSoft,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                f.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? f.color : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              StreamBuilder<List<QueryDocumentSnapshot>>(
                stream: DatabaseService.getReviewTabDocsStream(f.status),
                builder: (context, snap) {
                  final count = snap.data?.length;
                  return Text(
                    count == null ? '···' : '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? f.color
                          : AppColors.textSecondary.withOpacity(0.7),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final String message = switch (_filter) {
      _ReviewFilter.pending =>
        "No pending flagged submissions.\nNew unidentified reports will appear here.",
      _ReviewFilter.approved => "No approved reports yet.",
      _ReviewFilter.declined =>
        "No declined reports.\nDeclined submissions can be re-approved here if needed.",
    };

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
            Icon(
              _filter == _ReviewFilter.declined
                  ? Icons.restore_from_trash
                  : Icons.check_circle_outline,
              size: 64,
              color: AppColors.primarySoft,
            ),
            const SizedBox(height: 16),
            Text(
              switch (_filter) {
                _ReviewFilter.pending => "All reports reviewed",
                _ReviewFilter.approved => "Nothing approved yet",
                _ReviewFilter.declined => "Nothing declined",
              },
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}