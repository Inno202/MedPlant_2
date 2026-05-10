import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';

class ReportCard extends StatefulWidget {
  final String imageUrl;
  final String location;
  final String date;
  final String environment;
  final String description;

  const ReportCard({
    super.key,
    required this.imageUrl,
    required this.location,
    required this.date,
    required this.environment,
    required this.description,
    
  });

  @override
  State<ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<ReportCard> {
  bool isExpanded = false;
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        maxHeight: 520, // 🔥 prevents overflow globally
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 40, 20, 0.07),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView( // 🔥 makes card scrollable
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔥 IMAGE + OVERLAY
              Stack(
                children: [
                  Image.network(
                    widget.imageUrl,
                    height: 200, // 🔥 increased from 220 → 260
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),

                  // gradient overlay
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black54,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // overlay text
                  const Positioned(
                    bottom: 10,
                    left: 12,
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          "Click to enlarge",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 🔥 CONTENT
              Padding(
                padding: const EdgeInsets.all(14), // slightly reduced padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // DATE + LOCATION (FIXED OVERFLOW)
                    Row(
                      children: [
                        // DATE
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accentBg,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today,
                                    size: 12, color: AppColors.primaryDark),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    widget.date,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // LOCATION
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 12, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.location,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ENVIRONMENT BADGE
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.accentBg,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.thermostat,
                              size: 12, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              widget.environment,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Divider(color: AppColors.borderSoft),

                    const SizedBox(height: 10),

                    // 🔥 DESCRIPTION WITH HOVER + TAP EXPAND
                    MouseRegion(
                      onEnter: (_) => setState(() => isHovered = true),
                      onExit: (_) => setState(() => isHovered = false),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => isExpanded = !isExpanded);
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "❝",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: AppColors.primarySoft,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    widget.description,
                                    maxLines: isExpanded ? null : 3,
                                    overflow: isExpanded
                                        ? TextOverflow.visible
                                        : TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            if (!isExpanded && (isHovered || widget.description.length > 100))
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  "Read more...",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Divider(color: AppColors.borderSoft),

                    const SizedBox(height: 8),

                    // VIEW PHOTO
                    InkWell(
                      // onTap: () {context.push("/plantdetail");},
                      child: const Row(
                        children: [
                          Icon(Icons.camera_alt,
                              size: 14, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            "Read full report",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward,
                              size: 14, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}