// lib/screens/field_manager/approve_reports_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medplant/services/database_service.dart';
import 'package:medplant/widgets/section_header.dart';
import '/constants/app_colors.dart';

class ApproveReportsScreen extends StatefulWidget {
  const ApproveReportsScreen({super.key});

  @override
  State<ApproveReportsScreen> createState() => _ApproveReportsScreenState();
}

class _ApproveReportsScreenState extends State<ApproveReportsScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  Future<void> _approve(String docId, String speciesName) async {
    await DatabaseService.approveReport(docId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✅ Approved — $speciesName added to reports feed"),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _decline(String docId, String speciesName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Decline report?"),
        content: Text(
          "This report for '$speciesName' will be permanently hidden. "
          "This cannot be undone.",
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
        content: Text("❌ Report declined and removed from queue"),
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
          final currentData =
              currentDoc.data() as Map<String, dynamic>;

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
                    final data =
                        docs[index].data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child:
                          _buildReportCard(docs[index].id, data),
                    );
                  },
                ),
              ),

              _buildDots(docs.length),
              _buildActionButtons(
                currentDoc.id,
                currentData['speciesName'] ?? 'Unknown species',
              ),
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

  Widget _buildReportCard(String docId, Map<String, dynamic> data) {
    final imageUrl = data['imageUrl'] ?? '';
    final location = data['location'] ?? 'Unknown';
    final environment = data['environmentalCondition'] ?? 'Unknown';
    final notes = data['observerNotes'] ?? 'No notes';
    final speciesName = data['speciesName'] ?? 'Unknown species';
    final confidence =
        ((data['confidence'] ?? 0.0) * 100).toStringAsFixed(0);
    final severity = data['severity'] ?? '1';
    final indicator = data['degradationIndicator'] ?? 'None';
    final submittedAt = data['submittedAt'] as Timestamp?;
    final dateStr = submittedAt != null
        ? submittedAt.toDate().toString().split(' ').first
        : 'Unknown date';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 74, 56, 0.12),
            blurRadius: 25,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Orange top strip — indicates unreviewed
            Container(
              height: 8,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange, Colors.deepOrange],
                ),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),

            // Warning banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              color: const Color(0xFFFFF3CD),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "ML could not identify the plant species — flagged for review",
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF856404),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Image
            if (imageUrl.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.accentBg,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 150,
                      color: AppColors.borderSoft,
                      child: const Center(
                        child: Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 120,
                color: AppColors.accentBg,
                child: const Center(
                  child: Icon(Icons.camera_alt,
                      size: 48, color: AppColors.primarySoft),
                ),
              ),

            // Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _detailRow(
                      Icons.calendar_today, "Submitted", dateStr),
                  _detailRow(
                      Icons.location_on, "Location", location),
                  _detailRow(
                      Icons.cloud, "Environment", environment),
                  _detailRow(Icons.search, "Species suggested",
                      "$speciesName ($confidence% conf.)"),
                  _detailRow(Icons.warning,
                      "Degradation indicator", indicator),
                  _detailRow(Icons.speed,
                      "Severity reported", "$severity / 5"),
                  _detailRow(
                      Icons.notes, "Observer notes", notes),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
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
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
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

  Widget _buildActionButtons(String docId, String speciesName) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border:
            Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Colors.red, width: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40)),
              ),
              onPressed: () => _decline(docId, speciesName),
              icon: const Icon(Icons.close,
                  color: Colors.red, size: 18),
              label: const Text("Decline",
                  style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40)),
              ),
              onPressed: () => _approve(docId, speciesName),
              icon: const Icon(Icons.check,
                  color: Colors.white, size: 18),
              label: const Text("Approve",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}