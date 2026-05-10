import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medplant/models/user_role.dart';
import 'package:provider/provider.dart';
import 'package:medplant/constants/app_colors.dart';
import 'package:medplant/models/report_model.dart';
import 'package:medplant/providers/user_provider.dart';
import 'package:medplant/widgets/empty_state_report.dart';
import 'package:medplant/widgets/section_header.dart';
import 'package:medplant/widgets/report_card.dart';
import 'package:go_router/go_router.dart';

class ViewReportsScreen extends StatelessWidget {
  const ViewReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<ReportModel> reports = [
      ReportModel(
        imageUrl: "https://images.unsplash.com/photo-1501004318641-b39e6451bec6",
        location: "Nairobi Forest",
        date: "2024-01-15",
        environment: "22°C, Humid",
        description:
            "Observed a healthy population of Agapanthus Africanus flowering near the river bank.",
      ),
      ReportModel(
        imageUrl: "https://images.unsplash.com/photo-1502082553048-f009c37129b9",
        location: "Mount Kenya Region",
        date: "2024-01-20",
        environment: "18°C, Light rain",
        description:
            "Knowltonia Capensis specimens found in shaded areas under indigenous trees. Several young plants observed.",
      ),
      ReportModel(
        imageUrl: "https://images.unsplash.com/photo-1473773508845-188df298d2d1",
        location: "Coastal Region",
        date: "2024-01-25",
        environment: "28°C, Sunny",
        description:
            "Lessertia frutescens thriving in well-drained soil. Traditional healer reported increased harvesting pressure.",
      ),
      // Add remaining reports as before
    ];

    final userProvider = Provider.of<UserProvider>(context);
    final role = userProvider.role;

    String? getButtonText() {
      switch (role) {
        case UserRole.communityUser:
          return "Add New";
        case UserRole.researcher:
          return "Pending Reports";
      // admin sees no button
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
          child: reports.isEmpty
              ? const EmptyState()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section header with button on the far right
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
                                borderRadius: BorderRadius.circular(6),
                              ),
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
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: reports.length,
                        itemBuilder: (context, index) {
                          final report = reports[index];

                          return ReportCard(
                            imageUrl: report.imageUrl,
                            location: report.location,
                            date: report.date,
                            environment: report.environment,
                            description: report.description,
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}