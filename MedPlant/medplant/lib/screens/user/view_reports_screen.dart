// lib/screens/user/view_reports_screen.dart
// Public feed of approved observation reports.
//   • Community users: "Add New" opens the report form (pushed, so Back
//     returns here).
//   • Researchers: "Review" opens the flagged-report review queue.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:medplant/constants/app_colors.dart';
import 'package:medplant/models/user_role.dart';
import 'package:medplant/providers/user_provider.dart';
import 'package:medplant/services/database_service.dart';
import 'package:medplant/widgets/empty_state_report.dart';
import 'package:medplant/widgets/report_card.dart';
import 'package:medplant/widgets/report_grid.dart';
import 'package:medplant/widgets/section_header.dart';

class ViewReportsScreen extends StatefulWidget {
  const ViewReportsScreen({super.key});

  @override
  State<ViewReportsScreen> createState() => _ViewReportsScreenState();
}

class _ViewReportsScreenState extends State<ViewReportsScreen> {
  // Created once — creating the stream inside build() re-subscribed to
  // Firestore on every rebuild and flashed the loading spinner.
  late final Stream<QuerySnapshot> _stream = DatabaseService.getReportsStream();

  static String _formatDate(dynamic ts) {
    if (ts is! Timestamp) return 'No date';
    final d = ts.toDate();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final role = context.select<UserProvider, UserRole?>((u) => u.role);

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (context, snapshot) {
          Widget content;

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            content = const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasError) {
            content = SliverFillRemaining(
              hasScrollBody: false,
              child: _ErrorState(error: '${snapshot.error}'),
            );
          } else {
            // Legacy docs (no reviewStatus) and approved docs are visible;
            // pending / declined are hidden from the public feed.
            final visibleDocs = (snapshot.data?.docs ?? []).where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return DatabaseService.isReportVisible(data);
            }).toList();

            if (visibleDocs.isEmpty) {
              content = const SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: EmptyState(),
                ),
              );
            } else {
              content = SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${visibleDocs.length} report${visibleDocs.length == 1 ? '' : 's'}",
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    ReportGrid(
                      reports: visibleDocs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return ReportCard(
                          imageUrl: data['imageUrl'] ?? '',
                          location: data['location'] ?? 'Unknown location',
                          date: _formatDate(data['submittedAt']),
                          environment:
                              data['environmentalCondition'] ?? 'Unknown',
                          description: data['observerNotes'] ?? '',
                          species: data['speciesName'] as String?,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            }
          }

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    sliver: SliverToBoxAdapter(child: _header(context, role)),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: content,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, UserRole? role) {
    final (String? label, IconData? icon, String? route) = switch (role) {
      UserRole.communityUser => ("Add New", Icons.add, '/addreport'),
      UserRole.researcher => ("Review", Icons.fact_check, '/approvereports'),
      null => (null, null, null),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(child: SectionHeader(title: "Observation Reports")),
        if (label != null)
          ElevatedButton.icon(
            onPressed: () => context.push(route!),
            icon: Icon(icon, size: 18, color: Colors.white),
            label: Text(
              label,
              style: GoogleFonts.montserrat(
                color: AppColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50)),
            ),
          ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.orange),
            const SizedBox(height: 12),
            Text("Couldn't load reports",
                style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark)),
            const SizedBox(height: 6),
            const Text(
              "Please check your internet connection and try again.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
