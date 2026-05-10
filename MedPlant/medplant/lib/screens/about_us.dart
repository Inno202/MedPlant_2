import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medplant/models/aboutmodel.dart';
import '../constants/app_colors.dart';

import '../widgets/section_header.dart';
import '../widgets/badge_chip.dart';
import '../widgets/info_note_about.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AboutScreen extends StatelessWidget {
  final bool isAdmin;

  const AboutScreen({super.key, this.isAdmin = false});

  @override
  Widget build(BuildContext context) {
    // dummy data instance
    final AboutModel about = dummyAbout;

    // badges row
    final List<Map<String, dynamic>> badges = [
      {'icon': FontAwesomeIcons.leaf, 'text': 'Indigenous Knowledge'},
      {'icon': FontAwesomeIcons.mobileAlt, 'text': 'ICT Integration'},
      {'icon': FontAwesomeIcons.heart, 'text': 'Conservation'},
      {'icon': FontAwesomeIcons.users, 'text': 'Community Based'},
      {'icon': FontAwesomeIcons.chartLine, 'text': 'Monitoring'},
    ];

    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('About MedPlants'),
      //   backgroundColor: AppColors.primaryDark,
      //   centerTitle: true,
      // ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            const SectionHeader(
              title: 'About MedPlants',
            ),
            const SizedBox(height: 16),

            // About card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSoft),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(15, 74, 56, 0.08),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // title + subtitle
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(FontAwesomeIcons.seedling,
                          color: AppColors.primarySoft, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              about.title,
                              style: GoogleFonts.montserrat(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            Text(
                              about.subtitle,
                              style: GoogleFonts.dancingScript(
                                fontSize: 16,
                              
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // description 1
                  Text(
                    about.description1,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.7,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                  const SizedBox(height: 12),

                  // description 2
                  Text(
                    about.description2,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.7,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                  const SizedBox(height: 16),

                  // highlight/info note
                  InfoNoteAbout(text: about.highlight),

                  // extra text / ITIKI link
                  Text(
                    about.extraText,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.7,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                  const SizedBox(height: 16),

                  // ITIKI link button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        // TODO: launch URL using url_launcher
                      },
                      icon: const FaIcon(
                        FontAwesomeIcons.arrowRight,
                        size: 14,
                        color: AppColors.white,
                      ),
                      label: Text(
                        'Discover ITIKI',
                        style: GoogleFonts.lato(
                          color: AppColors.white,
                        
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // badges row
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: badges
                        .map((b) => BadgeChip(
                              icon: b['icon'],
                              text: b['text'],
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}