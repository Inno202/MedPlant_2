import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CustomDropdown extends StatelessWidget {
  final String value;
  final List<DropdownMenuItem<String>> items;
  final Function(String?) onChanged;
  final String? hint;

  const CustomDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,

      dropdownColor: Colors.white,

      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),

      icon: const Icon(
        Icons.keyboard_arrow_down,
        color: AppColors.primary,
      ),

      menuMaxHeight: 250,

      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),

        filled: true,
        fillColor: const Color(0xFFFAFDFB),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.borderSoft,
            width: 2,
          ),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.borderSoft,
            width: 2,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
      ),

      // 🔥 ensures readable text in dropdown menu
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item.value,
              child: Text(
                (item.child as Text).data!,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          )
          .toList(),

      onChanged: onChanged,
    );
  }
}