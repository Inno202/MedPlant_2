// lib/screens/profile_screen.dart
//
// Profile tab.
//   Logged in → profile header (initials avatar, name, email, role),
//               live contribution stats, recent submissions, account
//               details (editable), role-specific shortcuts, password
//               reset, app links and logout.
//   Guest     → welcome card with Login / Register and app links.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:medplant/constants/app_colors.dart';
import 'package:medplant/core/layout/app_shell.dart';
import 'package:medplant/models/user_role.dart';
import 'package:medplant/providers/user_provider.dart';
import 'package:medplant/services/database_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: user.isLoggedIn && user.uid != null
                ? _LoggedInProfile(user: user)
                : const _GuestProfile(),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Logged in
// ═══════════════════════════════════════════════════════════════════════════
class _LoggedInProfile extends StatefulWidget {
  final UserProvider user;
  const _LoggedInProfile({required this.user});

  @override
  State<_LoggedInProfile> createState() => _LoggedInProfileState();
}

class _LoggedInProfileState extends State<_LoggedInProfile> {
  late final _db = FirebaseFirestore.instance;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _profileStream =
      _db.collection('users').doc(widget.user.uid).snapshots();
  // Single `where` (no orderBy) → no composite index needed; sorted below.
  Query<Map<String, dynamic>> get _myReports => _db
      .collection('plant_reports')
      .where('submittedBy', isEqualTo: widget.user.uid);
  // Separate streams for the two widgets that listen, so neither misses
  // the first snapshot.
  late final _statsReportsStream = _myReports.snapshots();
  late final _recentReportsStream = _myReports.snapshots();
  late final Future<Map<String, int>> _researcherStats =
      DatabaseService.getDashboardStats();

  bool get _isResearcher => widget.user.role == UserRole.researcher;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profileStream,
      builder: (context, snap) {
        final profile = snap.data?.data() ?? const <String, dynamic>{};
        final name = (profile['username'] as String?)?.trim().isNotEmpty == true
            ? profile['username'] as String
            : (widget.user.username?.isNotEmpty == true
                ? widget.user.username!
                : 'MedPlant user');
        final email = (profile['email'] as String?) ?? widget.user.email ?? '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileHeader(
              name: name,
              email: email,
              isResearcher: _isResearcher,
              onEdit: () => _openEditSheet(context, profile),
            ),
            const SizedBox(height: 16),
            _buildStats(),
            const SizedBox(height: 20),
            _Section(
              title: _isResearcher ? 'Researcher tools' : 'Quick actions',
              children: _isResearcher
                  ? [
                      _ActionTile(
                        icon: Icons.dashboard_rounded,
                        title: 'Analytics Dashboard',
                        subtitle: 'Species, alerts and ML pipeline status',
                        onTap: () => context.go('/researcher/dashboard'),
                      ),
                      _ActionTile(
                        icon: Icons.fact_check_rounded,
                        title: 'Review Flagged Reports',
                        subtitle: 'Approve or decline unidentified submissions',
                        onTap: () => context.push('/approvereports'),
                      ),
                      _ActionTile(
                        icon: Icons.mail_rounded,
                        title: 'Contact Messages',
                        subtitle: 'Messages sent through Contact Us',
                        onTap: () => context.push('/contactmessages'),
                      ),
                    ]
                  : [
                      _ActionTile(
                        icon: Icons.add_a_photo_rounded,
                        title: 'Submit a Plant Report',
                        subtitle: 'Photograph and report a plant',
                        onTap: () => context.push('/addreport'),
                      ),
                      _ActionTile(
                        icon: Icons.description_rounded,
                        title: 'Observation Reports',
                        subtitle: 'Browse approved community reports',
                        onTap: () => context.go('/viewreports'),
                      ),
                      _ActionTile(
                        icon: Icons.auto_awesome,
                        title: 'Health Monitor',
                        subtitle: 'ML health and trend predictions',
                        onTap: () => context.go('/predictions'),
                      ),
                    ],
            ),
            if (!_isResearcher) ...[
              const SizedBox(height: 20),
              _buildRecentReports(),
            ],
            const SizedBox(height: 20),
            _Section(
              title: 'Account details',
              trailing: TextButton.icon(
                onPressed: () => _openEditSheet(context, profile),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit'),
              ),
              children: [
                _DetailRow(Icons.person_outline, 'Username', name),
                _DetailRow(Icons.email_outlined, 'Email', email),
                _DetailRow(Icons.phone_outlined, 'Contact',
                    profile['contact'] as String?),
                _DetailRow(Icons.map_outlined, 'Province',
                    profile['province'] as String?),
                _DetailRow(Icons.public, 'Country',
                    profile['country'] as String?),
                _DetailRow(Icons.place_outlined, 'Study area',
                    (profile['locationArea'] as String?) ??
                        'Thaba-Nchu, Free State'),
                _DetailRow(Icons.badge_outlined, 'Role',
                    _isResearcher ? 'Researcher' : 'Community User'),
              ],
            ),
            const SizedBox(height: 20),
            _Section(
              title: 'App',
              children: [
                _ActionTile(
                  icon: Icons.lock_reset,
                  title: 'Change password',
                  subtitle: 'We\'ll email you a reset link',
                  onTap: () => _sendPasswordReset(context, email),
                ),
                if (!_isResearcher)
                  _ActionTile(
                    icon: Icons.contact_mail_rounded,
                    title: 'Contact Us',
                    subtitle: 'Questions or feedback',
                    onTap: () => context.push('/contact'),
                  ),
                _ActionTile(
                  icon: Icons.info_rounded,
                  title: 'About MedPlant',
                  subtitle: 'The project and its partners',
                  onTap: () => context.push('/about'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => confirmAndLogout(context),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Log out',
                    style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text('MedPlant · v1.0.0',
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ),
          ],
        );
      },
    );
  }

  // ── Contribution stats ──────────────────────────────────────────────────
  Widget _buildStats() {
    if (_isResearcher) {
      return FutureBuilder<Map<String, int>>(
        future: _researcherStats,
        builder: (context, snap) {
          final d = snap.data;
          String v(String k) => d == null ? '–' : '${d[k] ?? 0}';
          return _StatsRow(stats: [
            _Stat('Species', v('registeredSpecies'), Icons.eco,
                AppColors.primary),
            _Stat('Pending', v('pendingReports'), Icons.hourglass_top,
                Colors.orange),
            _Stat('Alerts', v('activeAlerts'), Icons.warning_amber_rounded,
                const Color(0xFFE74C3C)),
          ]);
        },
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _statsReportsStream,
      builder: (context, snap) {
        final docs = snap.data?.docs;
        int count(bool Function(Map<String, dynamic>) test) =>
            docs?.where((d) => test(d.data())).length ?? 0;
        final total = docs?.length;
        final approved = count(DatabaseService.isReportVisible);
        final pending = count((d) => d['reviewStatus'] == 'pending');
        String show(int n) => total == null ? '–' : '$n';
        return _StatsRow(stats: [
          _Stat('Reports', total == null ? '–' : '$total',
              Icons.camera_alt_rounded, AppColors.primary),
          _Stat('Approved', show(approved), Icons.verified_rounded,
              const Color(0xFF27AE60)),
          _Stat('In review', show(pending), Icons.hourglass_top,
              Colors.orange),
        ]);
      },
    );
  }

  // ── Recent submissions (community users) ────────────────────────────────
  Widget _buildRecentReports() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _recentReportsStream,
      builder: (context, snap) {
        final docs = [...?snap.data?.docs];
        docs.sort((a, b) {
          final at = a.data()['submittedAt'];
          final bt = b.data()['submittedAt'];
          if (at is! Timestamp) return 1;
          if (bt is! Timestamp) return -1;
          return bt.compareTo(at);
        });
        final recent = docs.take(3).toList();

        return _Section(
          title: 'My recent submissions',
          children: [
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                    child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.eco,
                        size: 36, color: AppColors.primarySoft),
                    const SizedBox(height: 8),
                    const Text("You haven't submitted any reports yet.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.push('/addreport'),
                      child: const Text('Submit your first report'),
                    ),
                  ],
                ),
              )
            else
              ...recent.map((d) => _RecentReportTile(data: d.data())),
          ],
        );
      },
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────
  Future<void> _sendPasswordReset(BuildContext context, String email) async {
    if (email.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      messenger.showSnackBar(SnackBar(
        content: Text('Password reset link sent to $email'),
        backgroundColor: AppColors.primary,
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text("Couldn't send the reset email. Try again later.")));
    }
  }

  void _openEditSheet(BuildContext context, Map<String, dynamic> profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditProfileSheet(
        uid: widget.user.uid!,
        profile: profile,
        onSaved: (name) => widget.user.updateUsername(name),
      ),
    );
  }
}

// ── Header card ───────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final bool isResearcher;
  final VoidCallback onEdit;

  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.isResearcher,
    required this.onEdit,
  });

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 12, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white24,
            ),
            child: CircleAvatar(
              radius: 34,
              backgroundColor: Colors.white,
              child: Text(
                _initials,
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _chip(isResearcher ? Icons.science : Icons.people,
                        isResearcher ? 'Researcher' : 'Community User'),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit profile',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(text,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

// ── Stats ─────────────────────────────────────────────────────────────────
class _Stat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Stat(this.label, this.value, this.icon, this.color);
}

class _StatsRow extends StatelessWidget {
  final List<_Stat> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Column(
                children: [
                  Icon(stats[i].icon, color: stats[i].color, size: 22),
                  const SizedBox(height: 6),
                  Text(
                    stats[i].value,
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(stats[i].label,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  const _Section({required this.title, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(
                      height: 1, indent: 56, color: AppColors.accentBg),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.accentBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark)),
      subtitle: Text(subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final has = value != null && value!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primarySoft),
          const SizedBox(width: 20),
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(
              has ? value! : 'Not set',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: has ? AppColors.primaryDark : AppColors.textSecondary,
                fontStyle: has ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentReportTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RecentReportTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final status = (data['reviewStatus'] as String?) ?? 'approved';
    final (Color color, String label) = switch (status) {
      'pending' => (Colors.orange, 'In review'),
      'declined' => (const Color(0xFFE74C3C), 'Declined'),
      _ => (const Color(0xFF27AE60), 'Approved'),
    };
    final ts = data['submittedAt'];
    final date = ts is Timestamp
        ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}'
        : '';
    final imageUrl = (data['imageUrl'] as String?) ?? '';

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 44,
          height: 44,
          child: imageUrl.isEmpty
              ? Container(
                  color: AppColors.accentBg,
                  child: const Icon(Icons.eco, color: AppColors.primarySoft),
                )
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.accentBg,
                    child: const Icon(Icons.eco, color: AppColors.primarySoft),
                  ),
                ),
        ),
      ),
      title: Text(
        (data['location'] as String?) ?? 'Unknown location',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryDark),
      ),
      subtitle: Text(
        [if (date.isNotEmpty) date, (data['speciesName'] as String?) ?? '']
            .where((e) => e.isNotEmpty)
            .join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── Edit profile sheet ────────────────────────────────────────────────────
class _EditProfileSheet extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> profile;
  final ValueChanged<String> onSaved;

  const _EditProfileSheet({
    required this.uid,
    required this.profile,
    required this.onSaved,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _username =
      TextEditingController(text: widget.profile['username'] ?? '');
  late final _contact =
      TextEditingController(text: widget.profile['contact'] ?? '');
  late final _province =
      TextEditingController(text: widget.profile['province'] ?? '');
  late final _country =
      TextEditingController(text: widget.profile['country'] ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _username.dispose();
    _contact.dispose();
    _province.dispose();
    _country.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
        'username': _username.text.trim(),
        'contact': _contact.text.trim(),
        'province': _province.text.trim(),
        'country': _country.text.trim(),
      });
      widget.onSaved(_username.text.trim());
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(
        content: Text('Profile updated'),
        backgroundColor: AppColors.primary,
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(const SnackBar(
          content: Text("Couldn't save your changes. Please try again.")));
    }
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primarySoft, size: 20),
        filled: true,
        fillColor: const Color(0xFFFAFDFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Lift the sheet above the keyboard.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderSoft,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Edit profile',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  )),
              const SizedBox(height: 16),
              TextFormField(
                controller: _username,
                textInputAction: TextInputAction.next,
                decoration: _dec('Username', Icons.person_outline),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter a username'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contact,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: _dec('Contact number', Icons.phone_outlined),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _province,
                textInputAction: TextInputAction.next,
                decoration: _dec('Province', Icons.map_outlined),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _country,
                textInputAction: TextInputAction.done,
                decoration: _dec('Country', Icons.public),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save changes',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Guest
// ═══════════════════════════════════════════════════════════════════════════
class _GuestProfile extends StatelessWidget {
  const _GuestProfile();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryDark, AppColors.primary],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 14),
              Text('You\'re browsing as a guest',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 6),
              const Text(
                'Log in or create an account to submit plant reports and track your contributions.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.push('/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50)),
                      ),
                      child: const Text('Login',
                          style: TextStyle(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.push('/register'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50)),
                      ),
                      child: const Text('Register',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _Section(
          title: 'Explore',
          children: [
            _ActionTile(
              icon: Icons.description_rounded,
              title: 'Observation Reports',
              subtitle: 'Browse approved community reports',
              onTap: () => context.go('/viewreports'),
            ),
            _ActionTile(
              icon: Icons.auto_awesome,
              title: 'Health Monitor',
              subtitle: 'ML health and trend predictions',
              onTap: () => context.go('/predictions'),
            ),
            _ActionTile(
              icon: Icons.contact_mail_rounded,
              title: 'Contact Us',
              subtitle: 'Questions or feedback',
              onTap: () => context.push('/contact'),
            ),
            _ActionTile(
              icon: Icons.info_rounded,
              title: 'About MedPlant',
              subtitle: 'The project and its partners',
              onTap: () => context.push('/about'),
            ),
          ],
        ),
      ],
    );
  }
}
