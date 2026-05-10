// lib/screens/user/add_report_screen.dart
// Fixed for Flutter Web: uses Image.memory instead of Image.file
// Form fields aligned with research proposal Section 2.3 data collection

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medplant/constants/app_colors.dart';
import 'package:medplant/services/ml_service.dart';
import 'package:medplant/widgets/custom_dropdown.dart';
import 'package:medplant/widgets/custom_text_field.dart';

enum _MLState { idle, loading, done, error }

class AddReportScreen extends StatefulWidget {
  const AddReportScreen({super.key});

  @override
  State<AddReportScreen> createState() => _AddReportScreenState();
}

class _AddReportScreenState extends State<AddReportScreen> {
  Uint8List? _imageBytes;
  XFile? _imageFile;
  _MLState _mlState = _MLState.idle;
  FullPipelineResult? _mlResult;

  final _locationController = TextEditingController();
  final _observationController = TextEditingController();

  String _environmentalCondition = 'Normal';
  String _degradationIndicator = 'None observed';
  String _severity = '1';

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    setState(() {
      _imageBytes = bytes;
      _imageFile = picked;
      _mlState = _MLState.loading;
      _mlResult = null;
    });

    final result = await MLService.runFullPipelineFromBytes(
      bytes,
      fileName: picked.name,
    );

    if (!mounted) return;
    setState(() {
      _mlResult = result;
      _mlState = result != null ? _MLState.done : _MLState.error;
    });
  }

  void _showSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text("Take a photo"),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text("Choose from gallery"),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locationController.dispose();
    _observationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primarySoft.withOpacity(0.4)),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft.withOpacity(0.2),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        const CircleAvatar(radius: 18, backgroundColor: AppColors.primarySoft, child: Icon(Icons.add, color: Colors.white)),
                        const SizedBox(height: 10),
                        Text("Submit Plant Report", style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                        const SizedBox(height: 4),
                        Text("Lessertia frutescens · Thaba-Nchu", style: GoogleFonts.dancingScript(color: AppColors.primary, fontSize: 16)),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // 1. Image
                        _sectionLabel("1. Plant Image"),
                        const SizedBox(height: 8),
                        _buildImageArea(),
                        const SizedBox(height: 6),
                        Text("Photo is analysed automatically by the ML pipeline (species ID, health, damage).",
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),

                        // ML result
                        if (_mlState != _MLState.idle) ...[
                          const SizedBox(height: 16),
                          _sectionLabel("ML Pipeline Result"),
                          const SizedBox(height: 8),
                          _buildMLResult(),
                        ],

                        // 2. Location
                        const SizedBox(height: 16),
                        _sectionLabel("2. Observation Location"),
                        const SizedBox(height: 8),
                        CustomTextField(
                          label: "",
                          hint: "e.g. Thaba-Nchu hillside, near stream",
                          icon: Icons.location_on,
                          controller: _locationController,
                        ),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.gps_fixed, size: 12, color: AppColors.primarySoft),
                          const SizedBox(width: 4),
                          Text("GPS captured automatically on mobile", style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ]),

                        // 3. Environmental condition
                        const SizedBox(height: 16),
                        _sectionLabel("3. Environmental Condition"),
                        const SizedBox(height: 8),
                        CustomDropdown(
                          value: _environmentalCondition,
                          items: const [
                            DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                            DropdownMenuItem(value: 'Hot', child: Text('Hot')),
                            DropdownMenuItem(value: 'Cold', child: Text('Cold')),
                            DropdownMenuItem(value: 'Wet / After rain', child: Text('Wet / After rain')),
                            DropdownMenuItem(value: 'Dry', child: Text('Dry')),
                            DropdownMenuItem(value: 'Windy', child: Text('Windy')),
                            DropdownMenuItem(value: 'Frost', child: Text('Frost')),
                          ],
                          onChanged: (v) => setState(() => _environmentalCondition = v!),
                        ),

                        // 4. Degradation indicator (IK vocabulary)
                        const SizedBox(height: 16),
                        _sectionLabel("4. Degradation Indicator"),
                        const SizedBox(height: 8),
                        CustomDropdown(
                          value: _degradationIndicator,
                          items: const [
                            DropdownMenuItem(value: 'None observed', child: Text('None observed')),
                            DropdownMenuItem(value: 'Over-harvesting', child: Text('Over-harvesting')),
                            DropdownMenuItem(value: 'Land use change', child: Text('Land use change')),
                            DropdownMenuItem(value: 'Pollution', child: Text('Pollution')),
                            DropdownMenuItem(value: 'Drought stress', child: Text('Drought stress')),
                            DropdownMenuItem(value: 'Flooding', child: Text('Flooding')),
                            DropdownMenuItem(value: 'Fire damage', child: Text('Fire damage')),
                            DropdownMenuItem(value: 'Invasive species nearby', child: Text('Invasive species nearby')),
                          ],
                          onChanged: (v) => setState(() => _degradationIndicator = v!),
                        ),

                        // 5. Observer notes
                        const SizedBox(height: 16),
                        _sectionLabel("5. Observer Notes"),
                        const SizedBox(height: 8),
                        CustomTextField(
                          label: "",
                          hint: "Describe leaf condition, colour, size, surrounding vegetation...",
                          icon: Icons.notes,
                          controller: _observationController,
                        ),

                        // 6. Severity
                        const SizedBox(height: 16),
                        _sectionLabel("6. Overall Severity (your assessment)"),
                        const SizedBox(height: 8),
                        CustomDropdown(
                          value: _severity,
                          items: const [
                            DropdownMenuItem(value: '1', child: Text('1 — No visible damage')),
                            DropdownMenuItem(value: '2', child: Text('2 — Minor stress')),
                            DropdownMenuItem(value: '3', child: Text('3 — Moderate stress')),
                            DropdownMenuItem(value: '4', child: Text('4 — Severe stress')),
                            DropdownMenuItem(value: '5', child: Text('5 — Critical / dying')),
                          ],
                          onChanged: (v) => setState(() => _severity = v!),
                        ),

                        const SizedBox(height: 28),

                        // Buttons
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _mlState == _MLState.loading ? Colors.grey : AppColors.primaryDark,
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                              ),
                              onPressed: _mlState == _MLState.loading ? null : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Report submitted successfully")),
                                );
                                context.go('/viewreports');
                              },
                              icon: const Icon(Icons.send, color: Colors.white),
                              label: Text("Submit Report", style: GoogleFonts.lato(color: Colors.white)),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                                side: const BorderSide(color: AppColors.primaryDark, width: 2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                              ),
                              onPressed: () => context.go('/viewreports'),
                              icon: const Icon(Icons.close, color: AppColors.primaryDark),
                              label: Text("Cancel", style: GoogleFonts.lato(color: AppColors.primaryDark)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageArea() {
    if (_imageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Image.memory(_imageBytes!, width: double.infinity, height: 220, fit: BoxFit.cover),
            Positioned(
              top: 8, right: 8,
              child: GestureDetector(
                onTap: _showSourceSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: const Row(children: [
                    Icon(Icons.refresh, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text("Retake", style: TextStyle(color: Colors.white, fontSize: 12)),
                  ]),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _showSourceSheet,
      child: Container(
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.accentBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primarySoft, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, size: 40, color: AppColors.primary),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              ),
              onPressed: _showSourceSheet,
              child: Text("Capture / Upload Image", style: GoogleFonts.lato(color: Colors.white, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMLResult() {
    if (_mlState == _MLState.loading) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.accentBg,
          borderRadius: BorderRadius.circular(12),
          border: const Border(left: BorderSide(color: AppColors.primary, width: 4)),
        ),
        child: const Row(children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text("Running ML pipeline (F1 → F2 → F3)..."),
        ]),
      );
    }

    if (_mlState == _MLState.error || _mlResult == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(12),
          border: const Border(left: BorderSide(color: Colors.orange, width: 4)),
        ),
        child: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 12),
          Expanded(child: Text("ML server not reachable. Submit report manually.\nEnsure Python server runs on port 8000.", style: TextStyle(fontSize: 12))),
        ]),
      );
    }

    final r = _mlResult!;
    final healthColor = r.healthStatus == 'Healthy'
        ? const Color(0xFF27AE60)
        : r.healthStatus == 'Stressed'
            ? const Color(0xFFF39C12)
            : const Color(0xFFE74C3C);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.biotech, color: AppColors.primary, size: 16),
            const SizedBox(width: 6),
            Text("ML Pipeline Result", style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: AppColors.primaryDark, fontSize: 13)),
          ]),
          const SizedBox(height: 12),
          _mlRow("F1 · Species ID", "${r.species} · ${(r.confidence * 100).toStringAsFixed(0)}% confidence", Icons.search,
            trailing: r.identified ? const Icon(Icons.check_circle, color: Color(0xFF27AE60), size: 16) : const Icon(Icons.flag, color: Colors.orange, size: 16)),
          const SizedBox(height: 8),
          _mlRow("F2 · Health & Trend", "${r.healthStatus} · ${r.trendDirection}", Icons.health_and_safety,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: healthColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Text(r.healthStatus, style: TextStyle(color: healthColor, fontSize: 11, fontWeight: FontWeight.bold)),
            )),
          const SizedBox(height: 8),
          _mlRow("F3 · Damage", r.damageDetected ? r.damageLabels.join(", ") : "None detected", Icons.bug_report),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accentBg,
              borderRadius: BorderRadius.circular(8),
              border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
            ),
            child: Text(r.predictionNote, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _mlRow(String label, String value, IconData icon, {Widget? trailing}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.primarySoft),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
              children: [
                TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 6), trailing],
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryDark));
}