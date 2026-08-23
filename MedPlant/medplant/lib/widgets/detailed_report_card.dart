// lib/widgets/detailed_report_card.dart
// Shared detailed report card used by both ApproveReportsScreen and
// ViewReportsScreen, so both screens render reports identically.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medplant/constants/app_colors.dart';

class DetailedReportCard extends StatelessWidget {
  final Map<String, dynamic> data;

  /// If provided, shows an "Approve" button that calls this callback.
  final VoidCallback? onApprove;

  /// If provided, shows a "Decline" button that calls this callback.
  final VoidCallback? onDecline;

  const DetailedReportCard({
    super.key,
    required this.data,
    this.onApprove,
    this.onDecline,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF27AE60);
      case 'declined':
        return const Color(0xFFE74C3C);
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'declined':
        return 'Declined';
      case 'pending':
      default:
        return 'Pending Review';
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'declined':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
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

    // Legacy docs with no reviewStatus are treated as approved.
    final reviewStatus = (data['reviewStatus'] as String?) ?? 'approved';
    final statusColor = _statusColor(reviewStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top strip colour-coded by status
          Container(
            height: 8,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [statusColor, statusColor.withOpacity(0.55)],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
          ),

          // Status banner
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: statusColor.withOpacity(0.12),
            child: Row(
              children: [
                Icon(_statusIcon(reviewStatus), color: statusColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusLabel(reviewStatus),
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Image
          if (imageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  height: 200,
                  width: double.infinity,
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
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Icon(Icons.camera_alt,
                    size: 48, color: AppColors.primarySoft),
              ),
            ),

          // Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _detailRow(Icons.calendar_today, "Submitted", dateStr),
                _detailRow(Icons.location_on, "Location", location),
                _detailRow(Icons.cloud, "Environment", environment),
                _detailRow(Icons.search, "Species suggested",
                    "$speciesName ($confidence% conf.)"),
                _detailRow(
                    Icons.warning, "Degradation indicator", indicator),
                _detailRow(Icons.speed, "Severity reported", "$severity / 5"),
                _detailRow(Icons.notes, "Observer notes", notes),
              ],
            ),
          ),

          // Approve / Decline actions (field manager only, pending reports only)
          if (onApprove != null || onDecline != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  if (onDecline != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.red, width: 2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40)),
                        ),
                        onPressed: onDecline,
                        icon: const Icon(Icons.close,
                            color: Colors.red, size: 18),
                        label: const Text("Decline",
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  if (onDecline != null && onApprove != null)
                    const SizedBox(width: 12),
                  if (onApprove != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40)),
                        ),
                        onPressed: onApprove,
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
            )
          else
            const SizedBox(height: 16),
        ],
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
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.03), blurRadius: 6),
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
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}