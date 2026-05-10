import 'package:flutter/material.dart';
import 'package:medplant/models/observation_model.dart';
import 'package:medplant/widgets/section_header.dart';
import '/constants/app_colors.dart';

class ApproveReportsScreen extends StatefulWidget {
  const ApproveReportsScreen({super.key});

  @override
  State<ApproveReportsScreen> createState() =>
      _ApproveReportsScreenState();
}

class _ApproveReportsScreenState extends State<ApproveReportsScreen> {
  final PageController _pageController = PageController();
  int currentIndex = 0;

  final List<ObservationModel> observations = [
    ObservationModel(
      observerName: "Mary Wanjiku",
      date: "2024-02-15",
      location: "Nairobi Forest",
      temperature: "22°C, Humidity 65%",
      description:
          "Observed a healthy population of Agapanthus Africanus flowering near the river bank. Soil moisture appears optimal and several new shoots are emerging.",
      imageUrl:
          "https://images.unsplash.com/photo-1471193945509-9ad0617afabf?w=800",
    ),
    ObservationModel(
      observerName: "John Mwangi",
      date: "2024-02-14",
      location: "Mount Kenya",
      temperature: "18°C, Light rain",
      description:
          "Knowltonia Capensis specimens found in shaded areas under indigenous trees. Multiple mature plants with flowers observed.",
      imageUrl:
          "https://images.unsplash.com/photo-1471193945509-9ad0617afabf?w=800",
    ),
  ];

  void approve() {
    final obs = observations[currentIndex];

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Approved: ${obs.observerName} (${obs.location})"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (observations.isEmpty) {
      return Scaffold(
        
        body: const Center(
          child: Text("No reports pending approval"),
        ),
      );
    }

    return Scaffold(
    
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16, ),
            child: SectionHeader(title: "Approve Reports"),
          ),

          // 🔥 SWIPEABLE CAROUSEL
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: observations.length,
              onPageChanged: (index) {
                setState(() => currentIndex = index);
              },
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildReportCard(observations[index]),
                );
              },
            ),
          ),

          _buildDots(),

          _buildApproveButton(),
        ],
      ),
    );
  }

  // 🔥 SCROLLABLE CARD (IMAGE INCLUDED)
  Widget _buildReportCard(ObservationModel obs) {
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
            // TOP STRIP
            Container(
              height: 8,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primarySoft],
                ),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),

            // IMAGE
            Container(
              padding: const EdgeInsets.all(20),
              color: AppColors.accentBg,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: obs.imageUrl.isEmpty
                      ? const SizedBox(
                          height: 200,
                          child: Center(
                            child: Icon(Icons.image, size: 80),
                          ),
                        )
                      : Image.network(
                          obs.imageUrl,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),

            // DETAILS
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _detailCard(Icons.person, "Observer", obs.observerName),
                  _detailCard(
                    Icons.calendar_today,
                    "Observed On",
                    "${obs.date} • ${obs.location}",
                  ),
                  _detailCard(Icons.thermostat,
                      "Environmental Condition", obs.temperature),
                  _detailCard(
                      Icons.description, "Description", obs.description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 DETAIL ITEM
  Widget _detailCard(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.8,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 DOT INDICATOR
  Widget _buildDots() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(observations.length, (index) {
          final isActive = index == currentIndex;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 12 : 8,
            height: isActive ? 12 : 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isActive ? AppColors.primary : AppColors.borderSoft,
            ),
          );
        }),
      ),
    );
  }

  // 🔥 APPROVE BUTTON ONLY
  Widget _buildApproveButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.borderSoft),
        ),
      ),
      child: GestureDetector(
        onTap: approve,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primarySoft],
            ),
            borderRadius: BorderRadius.circular(40),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(15, 74, 56, 0.3),
                blurRadius: 15,
              )
            ],
          ),
          child: const Center(
            child: Text(
              "Approve Report",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}