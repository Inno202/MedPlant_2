// lib/screens/admin/admin_dashboard.dart
// Researcher Analytics Dashboard — fully Firestore-backed.
//
// Stat cards are clickable and open a bottom sheet with live Firestore data:
//   • Registered Species  → list + "Add New Species" button
//   • Total Submissions   → list of all plant_reports
//   • Active Alerts       → degradation_alerts with status=Pending
//   • Community Users     → list + edit role button per user
//
// "Add New Species" and the edit-user sheet follow the same button style
// as AddReportScreen (primaryDark ElevatedButton / outlined cancel).

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medplant/constants/app_colors.dart';
import 'package:medplant/models/plant_model.dart';
import 'package:medplant/models/user_role.dart';
import 'package:medplant/services/cloudinary_service.dart';
import 'package:medplant/widgets/custom_dropdown.dart';
import 'package:medplant/widgets/custom_text_field.dart';
import 'package:medplant/widgets/section_header.dart';

final _db = FirebaseFirestore.instance;

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: "Researcher Dashboard"),
            const SizedBox(height: 4),
            Text(
              "Thaba-Nchu Medicinal Plant Monitoring · Free State",
              style: GoogleFonts.lato(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            // ── Clickable stat cards ───────────────────────────────────
            _LiveStatsRow(),
            const SizedBox(height: 20),

            // ── Degradation alerts ─────────────────────────────────────
            _sectionTitle("⚠ Degradation Alerts"),
            const SizedBox(height: 10),
            _LiveAlertsList(),
            const SizedBox(height: 20),

            // ── Species health summary ─────────────────────────────────
            _sectionTitle("Species Health Summary"),
            const SizedBox(height: 10),
            _LiveHealthTable(),
            const SizedBox(height: 20),

            // ── ML pipeline status ─────────────────────────────────────
            _sectionTitle("ML Pipeline Status"),
            const SizedBox(height: 10),
            _mlStatusCard(),
            const SizedBox(height: 20),

            // ── Top damage types ───────────────────────────────────────
            _sectionTitle("Dominant Damage Types (All Submissions)"),
            const SizedBox(height: 10),
            _LiveDamageBreakdown(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: GoogleFonts.montserrat(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
        ),
      );

  Widget _mlStatusCard() {
    final functions = [
      [
        'F1 · Species Identification',
        'Random Forest',
        '94.2% accuracy',
        Icons.search
      ],
      [
        'F2 · Health Classification',
        'Random Forest + Firebase history',
        '88.7% accuracy',
        Icons.health_and_safety
      ],
      [
        'F3 · Damage Detection',
        'Random Forest (multi-label)',
        '85.1% accuracy',
        Icons.bug_report
      ],
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        children: functions
            .map((f) => ListTile(
                  leading: Icon(f[3] as IconData,
                      color: AppColors.primary, size: 20),
                  title: Text(f[0] as String,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text("${f[1]} · ${f[2]}",
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                  dense: true,
                ))
            .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live stats row — each card is tappable
// ─────────────────────────────────────────────────────────────────────────────
class _LiveStatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<int>>(
      stream: _statsStream(),
      builder: (context, snap) {
        final counts = snap.data ?? [0, 0, 0, 0];
        final cards = [
          _StatCard(
            label: "Registered Species",
            value: "${counts[0]}",
            icon: Icons.eco,
            color: AppColors.primary,
            onTap: () => _openSheet(context, const _SpeciesSheet()),
          ),
          _StatCard(
            label: "Total Submissions",
            value: "${counts[1]}",
            icon: Icons.camera_alt,
            color: AppColors.primarySoft,
            onTap: () => _openSheet(context, const _ReportsSheet()),
          ),
          _StatCard(
            label: "Active Alerts",
            value: "${counts[2]}",
            icon: Icons.warning,
            color: const Color(0xFFE74C3C),
            onTap: () => _openSheet(context, const _AlertsSheet()),
          ),
          _StatCard(
            label: "Community Users",
            value: "${counts[3]}",
            icon: Icons.people,
            color: AppColors.primaryDark,
            onTap: () => _openSheet(context, const _UsersSheet()),
          ),
        ];

        return LayoutBuilder(builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 500;
          return isNarrow
              ? GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: cards,
                )
              : Row(
                  children: cards
                      .map((c) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: c,
                            ),
                          ))
                      .toList(),
                );
        });
      },
    );
  }

  Stream<List<int>> _statsStream() async* {
    // Combine four collection counts into a single stream by polling
    while (true) {
      try {
        final results = await Future.wait([
          _db.collection('species').get(),
          _db.collection('plant_reports').get(),
          _db
              .collection('degradation_alerts')
              .where('notificationStatus', isEqualTo: 'Pending')
              .get(),
          _db
              .collection('users')
              .where('role', isEqualTo: 'communityUser')
              .get(),
        ]);
        yield results.map((r) => r.docs.length).toList();
      } catch (_) {
        yield [0, 0, 0, 0];
      }
      await Future.delayed(const Duration(seconds: 30));
    }
  }

  void _openSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSoft),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 20),
                Icon(Icons.chevron_right,
                    size: 16, color: Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet base
// ─────────────────────────────────────────────────────────────────────────────
class _SheetBase extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;

  const _SheetBase(
      {required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7FAF8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSoft,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const Spacer(),
                  if (action != null) action!,
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(16),
                children: [child],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Species sheet
// ─────────────────────────────────────────────────────────────────────────────
class _SpeciesSheet extends StatelessWidget {
  const _SpeciesSheet();

  @override
  Widget build(BuildContext context) {
    return _SheetBase(
      title: "Registered Species",
      action: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6)),
        ),
        icon: const Icon(Icons.add, color: Colors.white, size: 16),
        label: Text("Add New Species",
            style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        onPressed: () {
          Navigator.pop(context);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const _AddSpeciesSheet(),
          );
        },
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('species').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _emptyState("No species registered yet.");
          }
          return Column(
            children: docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return _SpeciesItem(docId: doc.id, data: d);
            }).toList(),
          );
        },
      ),
    );
  }
}

class _SpeciesItem extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _SpeciesItem({required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    final status = data['conservationStatus'] ?? 'Unknown';
    final statusColor = status == 'Least Concern'
        ? const Color(0xFF27AE60)
        : status == 'Vulnerable'
            ? const Color(0xFFF39C12)
            : const Color(0xFFE74C3C);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.eco, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'] ?? 'Unknown',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  data['commonName'] ?? '',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          fontSize: 10,
                          color: statusColor,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Colors.red, size: 20),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Delete species?"),
                  content: Text(
                      "Remove ${data['name']} from the register?"),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel")),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("Delete",
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirm == true) {
                await _db.collection('species').doc(docId).delete();
              }
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add species sheet
// ─────────────────────────────────────────────────────────────────────────────
class _AddSpeciesSheet extends StatefulWidget {
  const _AddSpeciesSheet();

  @override
  State<_AddSpeciesSheet> createState() => _AddSpeciesSheetState();
}

class _AddSpeciesSheetState extends State<_AddSpeciesSheet> {
  final _nameController = TextEditingController();
  final _commonNameController = TextEditingController();
  final _localNameController = TextEditingController();
  final _familyController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _medicinalUsesController = TextEditingController();
  final _harvestingSeasonController = TextEditingController();

  // Image state
  Uint8List? _imageBytes;
  String? _imageFileName;
  bool _uploading = false;

  String _conservationStatus = 'Least Concern';
  bool _saving = false;
  String? _error;

  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imageFileName = picked.name;
      _error = null;
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
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: AppColors.primary),
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

  @override
  void dispose() {
    _nameController.dispose();
    _commonNameController.dispose();
    _localNameController.dispose();
    _familyController.dispose();
    _descriptionController.dispose();
    _medicinalUsesController.dispose();
    _harvestingSeasonController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = "Scientific name is required.");
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    // Upload image to Cloudinary if one was picked
    String imageUrl = '';
    if (_imageBytes != null) {
      setState(() => _uploading = true);
      final uploaded = await CloudinaryService.uploadImage(_imageBytes!);
      setState(() => _uploading = false);
      if (uploaded == null) {
        setState(() {
          _saving = false;
          _error = "Image upload failed. Check your connection and try again.";
        });
        return;
      }
      imageUrl = uploaded;
    }

    try {
      // Build a PlantModel-aligned document matching species collection schema
      await _db.collection('species').add({
        'name': _nameController.text.trim(),
        'commonName': _commonNameController.text.trim(),
        'localName': _localNameController.text.trim(),
        'family': _familyController.text.trim(),
        'description': _descriptionController.text.trim(),
        'medicinalUses': _medicinalUsesController.text.trim(),
        'harvestingSeason': _harvestingSeasonController.text.trim(),
        'imageUrl': imageUrl,
        'conservationStatus': _conservationStatus,
        'locationArea': 'Thaba-Nchu, Free State',
        'addedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = "Failed to save: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.97,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7FAF8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSoft,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.primarySoft.withOpacity(0.15),
              ),
              child: Column(children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primarySoft,
                  child: Icon(Icons.add, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text("Add New Species",
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    )),
                const SizedBox(height: 4),
                Text("Lessertia frutescens · Thaba-Nchu",
                    style: GoogleFonts.dancingScript(
                        color: AppColors.primary, fontSize: 14)),
              ]),
            ),

            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEC),
                        borderRadius: BorderRadius.circular(12),
                        border: const Border(
                            left: BorderSide(
                                color: Color(0xFFE74C3C), width: 4)),
                      ),
                      child: Text(_error!,
                          style: const TextStyle(
                              color: Color(0xFF9B2335),
                              fontSize: 13)),
                    ),

                  CustomTextField(
                    label: "Scientific Name *",
                    hint: "e.g. Lessertia frutescens",
                    icon: Icons.science,
                    controller: _nameController,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: "Common Name",
                    hint: "e.g. Cancer Bush",
                    icon: Icons.label_outline,
                    controller: _commonNameController,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: "Local Name (Sesotho/Barolong)",
                    hint: "e.g. Umswane",
                    icon: Icons.people_outline,
                    controller: _localNameController,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: "Family",
                    hint: "e.g. Fabaceae",
                    icon: Icons.account_tree_outlined,
                    controller: _familyController,
                  ),
                  const SizedBox(height: 14),

                  // Conservation status
                  Text("Conservation Status",
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.primaryDark)),
                  const SizedBox(height: 6),
                  CustomDropdown(
                    value: _conservationStatus,
                    items: const [
                      DropdownMenuItem(
                          value: 'Least Concern',
                          child: Text('Least Concern')),
                      DropdownMenuItem(
                          value: 'Near Threatened',
                          child: Text('Near Threatened')),
                      DropdownMenuItem(
                          value: 'Vulnerable',
                          child: Text('Vulnerable')),
                      DropdownMenuItem(
                          value: 'Endangered',
                          child: Text('Endangered')),
                      DropdownMenuItem(
                          value: 'Critically Endangered',
                          child: Text('Critically Endangered')),
                    ],
                    onChanged: (v) =>
                        setState(() => _conservationStatus = v!),
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: "Harvesting Season",
                    hint: "e.g. Spring – Summer",
                    icon: Icons.calendar_month_outlined,
                    controller: _harvestingSeasonController,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: "Description",
                    hint: "Brief botanical description",
                    icon: Icons.description_outlined,
                    controller: _descriptionController,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: "Medicinal Uses",
                    hint: "Traditional uses in Thaba-Nchu",
                    icon: Icons.medical_services_outlined,
                    controller: _medicinalUsesController,
                  ),
                  const SizedBox(height: 14),

                  // ── Image picker ──────────────────────────────────────
                  Text(
                    "Species Image (optional)",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Preview or placeholder
                  GestureDetector(
                    onTap: _showSourceSheet,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _imageBytes != null
                          ? Stack(
                              key: const ValueKey('preview'),
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.memory(
                                    _imageBytes!,
                                    width: double.infinity,
                                    height: 180,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                // Upload progress overlay
                                if (_uploading)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.black.withOpacity(0.45),
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                      child: const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2),
                                            SizedBox(height: 8),
                                            Text(
                                              "Uploading to Cloudinary…",
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                // Retake button
                                if (!_uploading)
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
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.refresh,
                                                color: Colors.white,
                                                size: 14),
                                            SizedBox(width: 4),
                                            Text("Change",
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          : Container(
                              key: const ValueKey('placeholder'),
                              width: double.infinity,
                              height: 120,
                              decoration: BoxDecoration(
                                color: AppColors.accentBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: AppColors.primarySoft,
                                    width: 2),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_photo_alternate,
                                      size: 36,
                                      color: AppColors.primary),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          AppColors.primaryDark,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(50)),
                                    ),
                                    onPressed: _showSourceSheet,
                                    icon: const Icon(Icons.camera_alt,
                                        color: Colors.white, size: 16),
                                    label: Text(
                                      "Choose Image",
                                      style: GoogleFonts.lato(
                                          color: Colors.white,
                                          fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Save button — same style as AddReportScreen
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_saving || _uploading)
                            ? Colors.grey
                            : AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50)),
                      ),
                      onPressed: (_saving || _uploading) ? null : _save,
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: Text(
                        _uploading
                            ? "Uploading image…"
                            : _saving
                                ? "Saving…"
                                : "Save Species",
                        style: GoogleFonts.lato(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 16),
                        side: const BorderSide(
                            color: AppColors.primaryDark, width: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close,
                          color: AppColors.primaryDark),
                      label: Text("Cancel",
                          style: GoogleFonts.lato(
                              color: AppColors.primaryDark)),
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Reports sheet
// ─────────────────────────────────────────────────────────────────────────────
class _ReportsSheet extends StatelessWidget {
  const _ReportsSheet();

  @override
  Widget build(BuildContext context) {
    return _SheetBase(
      title: "All Submissions",
      child: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('plant_reports')
            .orderBy('submittedAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _emptyState("No submissions yet.");
          }
          return Column(
            children: docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final date = d['submittedAt'] != null
                  ? (d['submittedAt'] as Timestamp)
                      .toDate()
                      .toString()
                      .split(' ')
                      .first
                  : '—';
              final health = d['healthStatus'] ?? '—';
              final healthColor = health == 'Stressed'
                  ? const Color(0xFFE74C3C)
                  : health == 'Healthy'
                      ? const Color(0xFF27AE60)
                      : const Color(0xFFF39C12);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border(
                      left: BorderSide(color: healthColor, width: 3)),
                ),
                child: Row(children: [
                  const Icon(Icons.camera_alt,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d['speciesName'] ?? 'Unknown species',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${d['location'] ?? '—'} · $date",
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary),
                          ),
                        ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: healthColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(health,
                        style: TextStyle(
                            fontSize: 10,
                            color: healthColor,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alerts sheet
// ─────────────────────────────────────────────────────────────────────────────
class _AlertsSheet extends StatelessWidget {
  const _AlertsSheet();

  @override
  Widget build(BuildContext context) {
    return _SheetBase(
      title: "Active Alerts",
      child: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('degradation_alerts')
            .where('notificationStatus', isEqualTo: 'Pending')
            .orderBy('alertDate', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _emptyState("No active alerts.");
          }
          return Column(
            children: docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final index =
                  (d['degradationIndex'] as num?)?.toDouble() ?? 0.0;
              final color = index >= 0.75
                  ? const Color(0xFFE74C3C)
                  : const Color(0xFFF39C12);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border(
                      left: BorderSide(color: color, width: 4)),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d['speciesName'] ?? '—',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark)),
                          const SizedBox(height: 2),
                          Text(
                            "${d['degradedCount'] ?? 0} Degraded classifications · ${d['locationArea'] ?? '—'}",
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ]),
                  ),
                  TextButton(
                    onPressed: () async {
                      await _db
                          .collection('degradation_alerts')
                          .doc(doc.id)
                          .update({
                        'notificationStatus': 'Acknowledged'
                      });
                    },
                    child: const Text("Acknowledge",
                        style: TextStyle(
                            fontSize: 11, color: AppColors.primary)),
                  ),
                ]),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Users sheet
// ─────────────────────────────────────────────────────────────────────────────
class _UsersSheet extends StatelessWidget {
  const _UsersSheet();

  @override
  Widget build(BuildContext context) {
    return _SheetBase(
      title: "Community Users",
      child: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('users').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _emptyState("No users registered yet.");
          }
          return Column(
            children: docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return _UserItem(docId: doc.id, data: d);
            }).toList(),
          );
        },
      ),
    );
  }
}

class _UserItem extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _UserItem({required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    final role = data['role'] ?? 'communityUser';
    final isResearcher = role == 'researcher';
    final roleColor =
        isResearcher ? AppColors.primaryDark : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.accentBg,
          child: Icon(
            isResearcher ? Icons.science : Icons.person,
            color: roleColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['username'] ?? 'Unknown',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  data['email'] ?? '—',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isResearcher ? "Researcher" : "Community User",
                    style: TextStyle(
                        fontSize: 10,
                        color: roleColor,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ]),
        ),
        IconButton(
          icon:
              const Icon(Icons.edit_outlined, color: AppColors.primary),
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) =>
                _EditUserSheet(docId: docId, data: data),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit user sheet
// ─────────────────────────────────────────────────────────────────────────────
class _EditUserSheet extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _EditUserSheet({required this.docId, required this.data});

  @override
  State<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends State<_EditUserSheet> {
  late final TextEditingController _usernameController;
  late final TextEditingController _contactController;
  late final TextEditingController _provinceController;
  late String _role;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _usernameController =
        TextEditingController(text: widget.data['username'] ?? '');
    _contactController =
        TextEditingController(text: widget.data['contact'] ?? '');
    _provinceController =
        TextEditingController(text: widget.data['province'] ?? '');
    _role = widget.data['role'] ?? 'communityUser';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _contactController.dispose();
    _provinceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _db.collection('users').doc(widget.docId).update({
        'username': _usernameController.text.trim(),
        'contact': _contactController.text.trim(),
        'province': _provinceController.text.trim(),
        'role': _role,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User updated successfully")),
        );
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = "Failed to update: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7FAF8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSoft,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.primarySoft.withOpacity(0.15),
              ),
              child: Column(children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primarySoft,
                  child: Icon(Icons.edit, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text("Edit User",
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    )),
                const SizedBox(height: 4),
                Text(
                  widget.data['email'] ?? '',
                  style: GoogleFonts.lato(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ]),
            ),

            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEC),
                        borderRadius: BorderRadius.circular(12),
                        border: const Border(
                            left: BorderSide(
                                color: Color(0xFFE74C3C), width: 4)),
                      ),
                      child: Text(_error!,
                          style: const TextStyle(
                              color: Color(0xFF9B2335),
                              fontSize: 13)),
                    ),

                  CustomTextField(
                    label: "Username",
                    hint: "Enter username",
                    icon: Icons.person_outline,
                    controller: _usernameController,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: "Contact",
                    hint: "Phone number",
                    icon: Icons.phone_outlined,
                    controller: _contactController,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: "Province",
                    hint: "e.g. Free State",
                    icon: Icons.map_outlined,
                    controller: _provinceController,
                  ),
                  const SizedBox(height: 14),

                  // Role selector
                  Text("User Role",
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.primaryDark)),
                  const SizedBox(height: 6),
                  CustomDropdown(
                    value: _role,
                    items: const [
                      DropdownMenuItem(
                          value: 'communityUser',
                          child: Text('Community User')),
                      DropdownMenuItem(
                          value: 'researcher',
                          child: Text('Researcher')),
                    ],
                    onChanged: (v) => setState(() => _role = v!),
                  ),

                  // Role change warning
                  if (_role == 'researcher') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(10),
                        border: const Border(
                            left: BorderSide(
                                color: Colors.orange, width: 3)),
                      ),
                      child: const Text(
                        "Researcher role grants access to the analytics dashboard, species register, all reports, and user management.",
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF856404)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Save button — same style as AddReportScreen
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _saving
                            ? Colors.grey
                            : AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50)),
                      ),
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: Text(
                        _saving ? "Saving…" : "Save Changes",
                        style: GoogleFonts.lato(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 16),
                        side: const BorderSide(
                            color: AppColors.primaryDark, width: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close,
                          color: AppColors.primaryDark),
                      label: Text("Cancel",
                          style: GoogleFonts.lato(
                              color: AppColors.primaryDark)),
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Live alerts list (inline on dashboard)
// ─────────────────────────────────────────────────────────────────────────────
class _LiveAlertsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('degradation_alerts')
          .where('notificationStatus', isEqualTo: 'Pending')
          .orderBy('alertDate', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyState("No active alerts — all species are stable.");
        }
        return Column(
          children: docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final index =
                (d['degradationIndex'] as num?)?.toDouble() ?? 0.0;
            final color =
                index >= 0.75 ? const Color(0xFFE74C3C) : const Color(0xFFF39C12);
            final severity = index >= 0.75
                ? 'Critical'
                : index >= 0.5
                    ? 'High'
                    : 'Moderate';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border(left: BorderSide(color: color, width: 4)),
                boxShadow: const [
                  BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.04),
                      blurRadius: 8)
                ],
              ),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d['speciesName'] ?? '—',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark)),
                        const SizedBox(height: 2),
                        Text(
                          "${d['degradedCount'] ?? 0} Degraded classifications · ${d['locationArea'] ?? '—'}",
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(severity,
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ]),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live health table (inline on dashboard)
// ─────────────────────────────────────────────────────────────────────────────
class _LiveHealthTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('species').snapshots(),
      builder: (context, speciesSnap) {
        if (speciesSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final species = speciesSnap.data?.docs ?? [];
        if (species.isEmpty) {
          return _emptyState("No species in the register yet.");
        }
        return StreamBuilder<QuerySnapshot>(
          stream: _db.collection('plant_reports').snapshots(),
          builder: (context, reportsSnap) {
            final reports = reportsSnap.data?.docs ?? [];

            // Build per-species stats from reports
            Map<String, Map<String, dynamic>> statsMap = {};
            for (final doc in reports) {
              final d = doc.data() as Map<String, dynamic>;
              final name = d['speciesName'] ?? '';
              if (name.isEmpty) continue;
              statsMap.putIfAbsent(
                  name, () => {'count': 0, 'health': [], 'trend': []});
              statsMap[name]!['count'] =
                  (statsMap[name]!['count'] as int) + 1;
              if (d['healthStatus'] != null) {
                (statsMap[name]!['health'] as List)
                    .add(d['healthStatus']);
              }
              if (d['trendDirection'] != null) {
                (statsMap[name]!['trend'] as List)
                    .add(d['trendDirection']);
              }
            }

            Color statusColor(String s) {
              if (s == 'Healthy') return const Color(0xFF27AE60);
              if (s == 'Degraded') return const Color(0xFFE74C3C);
              return const Color(0xFFF39C12);
            }

            Color trendColor(String t) {
              if (t == 'Improving') return const Color(0xFF27AE60);
              if (t == 'Declining') return const Color(0xFFE74C3C);
              return Colors.grey;
            }

            String dominantValue(List items) {
              if (items.isEmpty) return '—';
              final freq = <String, int>{};
              for (final v in items) {
                freq[v as String] = (freq[v] ?? 0) + 1;
              }
              return freq.entries
                  .reduce((a, b) => a.value >= b.value ? a : b)
                  .key;
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: const BoxDecoration(
                      color: AppColors.accentBg,
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(14)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                            flex: 3,
                            child: Text("Species",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                        Expanded(
                            child: Text("Reports",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                        Expanded(
                            child: Text("Status",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                        Expanded(
                            child: Text("Trend",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                      ],
                    ),
                  ),

                  ...species.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final name = d['name'] ?? '—';
                    final stats = statsMap[name] ??
                        {'count': 0, 'health': [], 'trend': []};
                    final count = stats['count'] as int;
                    final health = dominantValue(stats['health'] as List);
                    final trend = dominantValue(stats['trend'] as List);

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: const BoxDecoration(
                        border: Border(
                            top: BorderSide(
                                color: AppColors.borderSoft)),
                      ),
                      child: Row(children: [
                        Expanded(
                            flex: 3,
                            child: Text(name,
                                style:
                                    const TextStyle(fontSize: 12))),
                        Expanded(
                            child: Text("$count",
                                style:
                                    const TextStyle(fontSize: 12))),
                        Expanded(
                          child: Text(health,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor(health))),
                        ),
                        Expanded(
                          child: Text(trend,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: trendColor(trend))),
                        ),
                      ]),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live damage breakdown (inline on dashboard)
// ─────────────────────────────────────────────────────────────────────────────
class _LiveDamageBreakdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('plant_reports').snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final freq = <String, int>{};
        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final labels = d['damageLabels'];
          if (labels is List) {
            for (final l in labels) {
              freq[l as String] = (freq[l] ?? 0) + 1;
            }
          }
        }

        if (freq.isEmpty) {
          return _emptyState("No damage data yet.");
        }

        final sorted = freq.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final max = sorted.first.value.toDouble();

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(
            children: sorted.take(6).map((e) {
              final ratio = e.value / max;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key,
                            style: const TextStyle(fontSize: 12)),
                        Text("${e.value}",
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: AppColors.accentBg,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          ratio >= 0.7
                              ? const Color(0xFFE74C3C)
                              : ratio >= 0.4
                                  ? const Color(0xFFF39C12)
                                  : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────
Widget _emptyState(String message) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(message,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
      ),
    );