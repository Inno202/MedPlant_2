// widgets/platform_ticker.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class PlatformTicker extends StatefulWidget {
  const PlatformTicker({super.key});

  @override
  State<PlatformTicker> createState() => _PlatformTickerState();
}

class _PlatformTickerState extends State<PlatformTicker> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Delay scrolling until first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() async {
    // Ensure the controller is attached
    if (!_scrollController.hasClients) return;

    // Get scrollable width
    final maxExtent = _scrollController.position.maxScrollExtent;

    if (maxExtent == 0) return; // Nothing to scroll

    while (mounted) {
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(seconds: 30),
          curve: Curves.linear,
        );
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  final List<_TickerItem> items = const [
    _TickerItem(
        label: "Taveta Retail Market",
        price: "KES 50",
        change: "0%",
        changeType: ChangeType.neutral),
    _TickerItem(
        label: "🌿 Kale Khayega",
        price: "KES 70",
        change: "-13%",
        changeType: ChangeType.down),
    _TickerItem(
        label: "🌿 Spinach Wundanyi",
        price: "KES 80",
        change: "0%",
        changeType: ChangeType.neutral),
    _TickerItem(
        label: "🥬 Spinach Kitale",
        price: "KES 30",
        change: "-33%",
        changeType: ChangeType.down),
    _TickerItem(
        label: "Makutano Embu",
        price: "KES 45",
        change: "0%",
        changeType: ChangeType.neutral),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.borderSoft),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Label
          Container(
            padding: const EdgeInsets.only(right: 16),
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: Color(0xFFE0E0E0), width: 1),
              ),
            ),
            child: Text(
              "Latest Farm Product Market Prices",
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Scrollable ticker
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  ...items.map((item) => _TickerItemWidget(item: item)),
                  ...items.map((item) => _TickerItemWidget(item: item)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TickerItemWidget extends StatelessWidget {
  final _TickerItem item;

  const _TickerItemWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    Color changeColor;
    switch (item.changeType) {
      case ChangeType.down:
        changeColor = Colors.red;
        break;
      case ChangeType.neutral:
      default:
        changeColor = AppColors.accentBgDark;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Row(
        children: [
          Text(
            item.label,
            style: GoogleFonts.lato(fontSize: 14, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 4),
          Text(
            item.price,
            style: GoogleFonts.lato(
                fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 4),
          Text(
            item.change,
            style: GoogleFonts.lato(fontSize: 12, color: changeColor),
          ),
        ],
      ),
    );
  }
}

enum ChangeType { down, neutral }

class _TickerItem {
  final String label;
  final String price;
  final String change;
  final ChangeType changeType;

  const _TickerItem({
    required this.label,
    required this.price,
    required this.change,
    required this.changeType,
  });
}