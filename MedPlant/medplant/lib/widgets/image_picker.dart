import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medplant/constants/app_colors.dart';

class UploadSection extends StatelessWidget {
  final Function(String path) onImageSelected;

  const UploadSection({super.key, required this.onImageSelected});

  @override
  Widget build(BuildContext context) {
    return DottedBorder(
      borderType: BorderType.RRect,
      radius: const Radius.circular(16),
      dashPattern: const [6, 4],
      color: AppColors.primarySoft,
      strokeWidth: 2,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: 40,
          horizontal: 20,
        ),
        decoration: BoxDecoration(
          color: AppColors.primarySoft.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              Icons.cloud_upload,
              size: 55,
              color: AppColors.primary,
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
                elevation: 3,
              ),
              onPressed: () {
                // TODO: image picker
              },
              icon: const Icon(Icons.camera_alt,color: AppColors.white,),
              label:  Text(
                "Choose Image",
                style: GoogleFonts.lato(color: AppColors.white),
              ),
            ),

         

          
          ],
        ),
      ),
    );
  }
}