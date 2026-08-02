import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medplant/models/user_role.dart';
import 'package:provider/provider.dart';
import 'package:medplant/constants/app_colors.dart';
import 'package:medplant/providers/user_provider.dart';
import 'package:medplant/widgets/empty_state_report.dart';
import 'package:medplant/widgets/section_header.dart';
import 'package:medplant/widgets/report_card.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medplant/services/database_service.dart';

class ViewReportsScreen extends StatelessWidget {
  const ViewReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final role = userProvider.role;
    final width = MediaQuery.of(context).size.width;

    String? getButtonText() {
      switch (role) {
        case UserRole.communityUser:
          return "Add New";
        case UserRole.researcher:
          return "Pending Reports";
        default:
          return null;
      }
    }

    void onButtonPressed() {
      switch (role) {
        case UserRole.communityUser:
          context.go('/addreport');
          break;
        case UserRole.researcher:
          context.go('/approvereports');
          break;
        default:
          break;
      }
    }

    final buttonText = getButtonText();

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<QuerySnapshot>(
            stream: DatabaseService.getReportsStream(),
            builder: (context, snapshot) {
              // Loading
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Error
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    "Error loading reports: ${snapshot.error}",
                    style: GoogleFonts.montserrat(),
                  ),
                );
              }

              // Apply client-side visibility filter:
              // - Legacy docs (no reviewStatus) → always visible
              // - Docs with reviewStatus == 'approved' → visible
              // - Docs with reviewStatus == 'pending' or 'declined' → hidden
              final allDocs = snapshot.data?.docs ?? [];
              final visibleDocs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return DatabaseService.isReportVisible(data);
              }).toList();

              // Empty state
              if (visibleDocs.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SectionHeader(title: "Observation Reports"),
                        if (buttonText != null)
                          ElevatedButton(
                            onPressed: onButtonPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 20),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                            ),
                            child: Text(
                              buttonText,
                              style: GoogleFonts.montserrat(
                                color: AppColors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Expanded(child: EmptyState()),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SectionHeader(title: "Observation Reports"),
                      if (buttonText != null)
                        ElevatedButton(
                          onPressed: onButtonPressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 20),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                          ),
                          child: Text(
                            buttonText,
                            style: GoogleFonts.montserrat(
                              color: AppColors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: width < 700 ? 1 : 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: width < 700 ? 1.05 : 0.78,
                      ),
                      itemCount: visibleDocs.length,
                      itemBuilder: (context, index) {
                        final doc = visibleDocs[index].data()
                            as Map<String, dynamic>;

                        return ReportCard(
                          imageUrl: doc['imageUrl'] ?? '',
                          location: doc['location'] ?? 'Unknown location',
                          date: doc['submittedAt'] != null
                              ? (doc['submittedAt'] as Timestamp)
                                  .toDate()
                                  .toString()
                                  .split(' ')
                                  .first
                              : 'No date',
                          environment:
                              doc['environmentalCondition'] ?? 'Unknown',
                          description:
                              doc['observerNotes'] ?? 'No description',
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}