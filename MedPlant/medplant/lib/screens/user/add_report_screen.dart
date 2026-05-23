// lib/screens/user/add_report_screen.dart
// Uses F1 (species identification) only.
// Shows "Identified as Lessertia frutescens" or "Plant not identified".
// F2 and F3 are handled separately on the Predictions screen.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medplant/constants/app_colors.dart';
import 'package:medplant/services/ml_service.dart';
import 'package:medplant/widgets/custom_dropdown.dart';
import 'package:medplant/widgets/custom_text_field.dart';
import 'dart:convert';
import 'package:medplant/services/database_service.dart';
import 'package:medplant/services/cloudinary_service.dart';

typedef SpeciesIdentificationResult = FullPipelineResult;

extension SpeciesIdentificationResultExtras on FullPipelineResult {
  String get message => predictionNote;
}

enum _IDState { idle, loading, identified, notIdentified, serverError }

class AddReportScreen extends StatefulWidget {
  const AddReportScreen({super.key});

  @override
  State<AddReportScreen> createState() => _AddReportScreenState();
}

class _AddReportScreenState extends State<AddReportScreen> {
  // ── Image ────────────────────────────────────────────────────────────────────
  Uint8List? _imageBytes;
  XFile? _imageFile;
  _IDState _idState = _IDState.idle;
  SpeciesIdentificationResult? _idResult;
  bool _submitting = false;

  // ── Form ─────────────────────────────────────────────────────────────────────
  final _locationController = TextEditingController();
  final _observationController = TextEditingController();
  String _environmentalCondition = 'Normal';
  String _degradationIndicator = 'None observed';
  String _severity = '1';

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _locationController.dispose();
    _observationController.dispose();
    super.dispose();
  }

  // ── Pick image and run F1 ─────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    setState(() {
      _imageBytes = bytes;
      _imageFile = picked;
      _idState = _IDState.loading;
      _idResult = null;
    });

    // F1 only — species identification
    final result = await MLService.runFullPipelineFromBytes(
      bytes,
      fileName: picked.name,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() => _idState = _IDState.serverError);
      return;
    }

    setState(() {
      _idResult = result;
      _idState = result.identified
          ? _IDState.identified
          : _IDState.notIdentified;
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
              leading:
                  const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text("Take a photo"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library,
                  color: AppColors.primary),
              title: const Text("Choose from gallery"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
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
                border: Border.all(
                    color: AppColors.primarySoft.withOpacity(0.4)),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, 10)),
                ],
              ),
              child: Column(
                children: [
                  _buildHeader(),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── 1. Image ──────────────────────────────────────
                        _sectionLabel("1. Plant Image"),
                        const SizedBox(height: 8),
                        _buildImageArea(),
                        const SizedBox(height: 6),
                        Text(
                          "Photo is automatically checked against the Lessertia frutescens species register.",
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),

                        // ── Species ID result ─────────────────────────────
                        if (_idState != _IDState.idle) ...[
                          const SizedBox(height: 16),
                          _buildIDResult(),
                        ],

                        // ── 2. Location ───────────────────────────────────
                        const SizedBox(height: 20),
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
                          const Icon(Icons.gps_fixed,
                              size: 12, color: AppColors.primarySoft),
                          const SizedBox(width: 4),
                          Text(
                            "GPS captured automatically on mobile",
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary),
                          ),
                        ]),

                        // ── 3. Environmental condition ────────────────────
                        const SizedBox(height: 20),
                        _sectionLabel("3. Environmental Condition"),
                        const SizedBox(height: 8),
                        CustomDropdown(
                          value: _environmentalCondition,
                          items: const [
                            DropdownMenuItem(
                                value: 'Normal', child: Text('Normal')),
                            DropdownMenuItem(
                                value: 'Hot', child: Text('Hot')),
                            DropdownMenuItem(
                                value: 'Cold', child: Text('Cold')),
                            DropdownMenuItem(
                                value: 'Wet / After rain',
                                child: Text('Wet / After rain')),
                            DropdownMenuItem(
                                value: 'Dry', child: Text('Dry')),
                            DropdownMenuItem(
                                value: 'Windy', child: Text('Windy')),
                            DropdownMenuItem(
                                value: 'Frost', child: Text('Frost')),
                          ],
                          onChanged: (v) => setState(
                              () => _environmentalCondition = v!),
                        ),

                        // ── 4. Degradation indicator ──────────────────────
                        const SizedBox(height: 20),
                        _sectionLabel("4. Degradation Indicator"),
                        const SizedBox(height: 8),
                        CustomDropdown(
                          value: _degradationIndicator,
                          items: const [
                            DropdownMenuItem(
                                value: 'None observed',
                                child: Text('None observed')),
                            DropdownMenuItem(
                                value: 'Over-harvesting',
                                child: Text('Over-harvesting')),
                            DropdownMenuItem(
                                value: 'Land use change',
                                child: Text('Land use change')),
                            DropdownMenuItem(
                                value: 'Pollution',
                                child: Text('Pollution')),
                            DropdownMenuItem(
                                value: 'Drought stress',
                                child: Text('Drought stress')),
                            DropdownMenuItem(
                                value: 'Flooding',
                                child: Text('Flooding')),
                            DropdownMenuItem(
                                value: 'Fire damage',
                                child: Text('Fire damage')),
                            DropdownMenuItem(
                                value: 'Invasive species nearby',
                                child: Text('Invasive species nearby')),
                          ],
                          onChanged: (v) =>
                              setState(() => _degradationIndicator = v!),
                        ),

                        // ── 5. Observer notes ─────────────────────────────
                        const SizedBox(height: 20),
                        _sectionLabel("5. Observer Notes"),
                        const SizedBox(height: 8),
                        CustomTextField(
                          label: "",
                          hint:
                              "Describe leaf condition, colour, size, surrounding vegetation...",
                          icon: Icons.notes,
                          controller: _observationController,
                        ),

                        // ── 6. Severity ───────────────────────────────────
                        const SizedBox(height: 20),
                        _sectionLabel("6. Overall Severity (your assessment)"),
                        const SizedBox(height: 8),
                        CustomDropdown(
                          value: _severity,
                          items: const [
                            DropdownMenuItem(
                                value: '1',
                                child: Text('1 — No visible damage')),
                            DropdownMenuItem(
                                value: '2',
                                child: Text('2 — Minor stress')),
                            DropdownMenuItem(
                                value: '3',
                                child: Text('3 — Moderate stress')),
                            DropdownMenuItem(
                                value: '4',
                                child: Text('4 — Severe stress')),
                            DropdownMenuItem(
                                value: '5',
                                child: Text('5 — Critical / dying')),
                          ],
                          onChanged: (v) =>
                              setState(() => _severity = v!),
                        ),

                        const SizedBox(height: 28),
                        _buildButtons(),
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

  // ── Header ────────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.primarySoft.withOpacity(0.2),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primarySoft,
            child: Icon(Icons.add, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            "Submit Plant Report",
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Lessertia frutescens · Thaba-Nchu",
            style: GoogleFonts.dancingScript(
                color: AppColors.primary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // ── Image area ────────────────────────────────────────────────────────────────
  Widget _buildImageArea() {
    if (_imageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Image.memory(
              _imageBytes!,
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: _showSourceSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(children: [
                    Icon(Icons.refresh, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text("Retake",
                        style:
                            TextStyle(color: Colors.white, fontSize: 12)),
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
            const Icon(Icons.camera_alt,
                size: 40, color: AppColors.primary),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50)),
              ),
              onPressed: _showSourceSheet,
              child: Text(
                "Capture / Upload Image",
                style: GoogleFonts.lato(
                    color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Species ID result ─────────────────────────────────────────────────────────
  Widget _buildIDResult() {
    // Loading
    if (_idState == _IDState.loading) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.accentBg,
          borderRadius: BorderRadius.circular(12),
          border: const Border(
              left: BorderSide(color: AppColors.primary, width: 4)),
        ),
        child: const Row(children: [
          SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text("Checking species identity..."),
        ]),
      );
    }

    // Server not reachable
    if (_idState == _IDState.serverError) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(12),
          border: const Border(
              left: BorderSide(color: Colors.orange, width: 4)),
        ),
        child: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "ML server not reachable.\nMake sure main.py is running on port 8000.\nYou can still submit the report manually.",
              style: TextStyle(fontSize: 12),
            ),
          ),
        ]),
      );
    }

    // Identified
    if (_idState == _IDState.identified) {
      final confidence =
          ((_idResult?.confidence ?? 0) * 100).toStringAsFixed(0);
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF7EF),
          borderRadius: BorderRadius.circular(12),
          border: const Border(
              left: BorderSide(color: Color(0xFF27AE60), width: 4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle,
                color: Color(0xFF27AE60), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Identified as Lessertia frutescens",
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A6B3A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Confidence: $confidence% · Species confirmed",
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF2E7D50)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Not identified
    if (_idState == _IDState.notIdentified) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEC),
          borderRadius: BorderRadius.circular(12),
          border: const Border(
              left: BorderSide(color: Color(0xFFE74C3C), width: 4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel, color: Color(0xFFE74C3C), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Plant not identified",
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF9B2335),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "This image does not match Lessertia frutescens.\nSubmission will be flagged for researcher review.",
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF9B2335)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox();
  }

  // ── Buttons ───────────────────────────────────────────────────────────────────
  Widget _buildButtons() {
    final bool isLoading = _idState == _IDState.loading;

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor:
    (isLoading || _submitting)
        ? Colors.grey
        : AppColors.primaryDark,
            padding: const EdgeInsets.symmetric(
                horizontal: 28, vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50)),
          ),
          onPressed: isLoading || _submitting
    ? null
    : () async {
        if (_imageBytes == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Please capture a plant image first",
              ),
            ),
          );
          return;
        }

        setState(() {
          _submitting = true;
        });

        try {
          // Convert image to base64
          final imageUrl =
    await CloudinaryService.uploadImage(
  _imageBytes!,
);

if (imageUrl == null) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        "Failed to upload image",
      ),
    ),
  );

  setState(() {
    _submitting = false;
  });

  return;
}

          final result = await DatabaseService.submitReport(
            speciesName:
                _idResult?.species ?? "Unknown species",

            identified:
                _idResult?.identified ?? false,

            confidence:
                _idResult?.confidence ?? 0.0,

            // F2 placeholders for now
            healthStatus: 'Healthy',
            trendDirection: 'Stable',

            // F3 placeholders
            damageLabels: [],

            predictionNote:
                _idResult?.message ??
                'Manual observation submission',

            // Form values
            location: _locationController.text.trim(),

            environmentalCondition:
                _environmentalCondition,

            degradationIndicator:
                _degradationIndicator,

            observerNotes:
                _observationController.text.trim(),

            severity: _severity,

            imageUrl: imageUrl,
          );

          if (!mounted) return;

          setState(() {
            _submitting = false;
          });

          if (result != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Report submitted successfully",
                ),
              ),
            );

            context.go('/viewreports');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Failed to submit report",
                ),
              ),
            );
          }
        } catch (e) {
          setState(() {
            _submitting = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Error: $e",
              ),
            ),
          );
        }
      },
          icon: const Icon(Icons.send, color: Colors.white),
          label: Text(
  _submitting ? "Submitting..." : "Submit Report",
  style: GoogleFonts.lato(color: Colors.white),
),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
                horizontal: 28, vertical: 16),
            side: const BorderSide(
                color: AppColors.primaryDark, width: 2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50)),
          ),
          onPressed: () => context.go('/viewreports'),
          icon:
              const Icon(Icons.close, color: AppColors.primaryDark),
          label: Text("Cancel",
              style: GoogleFonts.lato(color: AppColors.primaryDark)),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.montserrat(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
        ),
      );
}