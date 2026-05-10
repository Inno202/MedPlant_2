import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:medplant/constants/app_colors.dart';
import 'custom_text_field.dart';
import 'package:medplant/widgets/custom_dropdown.dart';


class ReportFormFields extends StatefulWidget {
  const ReportFormFields({super.key});

  @override
  State<ReportFormFields> createState() => _ReportFormFieldsState();
}

class _ReportFormFieldsState extends State<ReportFormFields> {
  final locationController = TextEditingController();
  final descriptionController = TextEditingController();
  final statusController = TextEditingController();

  String environment = "hot";
  String indicator = "Land Use Change";
  String severity = "1";

  // 🔥 reusable row (matches web table layout)
  Widget buildRow(String label, Widget field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // responsive switch
          if (constraints.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 6),
                field,
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: field,
              ),
            ],
          );
        },
      ),
    );
  }

  InputDecoration dropdownStyle() {
    return InputDecoration(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // LOCATION
        buildRow(
          "Area / Location",
          CustomTextField(
            label: "",
            hint: "Enter location name",
            icon: FontAwesomeIcons.mapPin,
            controller: locationController,
          ),
        ),

        // ENVIRONMENT
        buildRow(
          "Environment Condition",
          CustomDropdown(
            value: environment,
            // decoration: dropdownStyle(),
            items: const [
              DropdownMenuItem(value: "hot", child: Text("Hot")),
              DropdownMenuItem(value: "warm", child: Text("Warm")),
              DropdownMenuItem(value: "cool", child: Text("Cool")),
              DropdownMenuItem(value: "cold", child: Text("Cold")),
              DropdownMenuItem(value: "wet", child: Text("Wet soil / rain")),
              DropdownMenuItem(value: "snow", child: Text("Snow")),
              DropdownMenuItem(value: "windy", child: Text("Windy")),
              DropdownMenuItem(value: "dusty", child: Text("Dusty")),
              DropdownMenuItem(value: "frost", child: Text("Frost")),
            ],
            onChanged: (val) => setState(() => environment = val!),
          ),
        ),

        // DEGRADATION
        buildRow(
          "Degradation Indicator",
          CustomDropdown(
            value: indicator,
          //  decoration: dropdownStyle(),
            items: const [
              DropdownMenuItem(value: "Land Use Change", child: Text("Land Use Change")),
              DropdownMenuItem(value: "Pollution", child: Text("Pollution")),
              DropdownMenuItem(value: "Climate Change", child: Text("Climate Change")),
              DropdownMenuItem(value: "Overexploitation", child: Text("Overexploitation")),
              DropdownMenuItem(value: "Invasive Species", child: Text("Invasive Species")),
              DropdownMenuItem(value: "Drought", child: Text("Drought")),
              DropdownMenuItem(value: "Flooding", child: Text("Flooding")),
              DropdownMenuItem(value: "Fire Damage", child: Text("Fire Damage")),
            ],
            onChanged: (val) => setState(() => indicator = val!),
          ),
        ),

        // DESCRIPTION
        buildRow(
          "Description",
          CustomTextField(
            label: "",
            hint: "Short description",
            icon: FontAwesomeIcons.alignLeft,
            controller: descriptionController,
          ),
        ),

        // STATUS
        buildRow(
          "Plant Status",
          CustomTextField(
            label: "",
            hint: "e.g. healthy, wilting",
            icon: FontAwesomeIcons.heartPulse,
            controller: statusController,
          ),
        ),

        // SEVERITY
        buildRow(
          "Severity",
          CustomDropdown(
            
            value: severity,
            // decoration: dropdownStyle(),
            items: const [
              DropdownMenuItem(value: "1", child: Text("No damage")),
              DropdownMenuItem(value: "2", child: Text("Minor stress")),
              DropdownMenuItem(value: "3", child: Text("Moderate stress")),
              DropdownMenuItem(value: "4", child: Text("Severe stress")),
              DropdownMenuItem(value: "5", child: Text("Critical")),
            ],
            onChanged: (val) => setState(() => severity = val!),
          ),
        ),
      ],
    );
  }
}