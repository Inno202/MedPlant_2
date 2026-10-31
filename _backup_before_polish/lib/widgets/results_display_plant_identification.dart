import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum ResultState { hidden, loading, identified, notIdentified }

class ResultDisplay extends StatelessWidget {
  final ResultState state;
  final String? plantName;
  final double? confidence;

  const ResultDisplay({
    super.key,
    required this.state,
    this.plantName,
    this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    if (state == ResultState.hidden) return const SizedBox();

    Color bgColor;
    Color borderColor;
    Widget content;

    switch (state) {
      case ResultState.loading:
        bgColor = const Color(0xFFE8F5EE);
        borderColor = AppColors.primary;

        content = Row(
          children: const [
            SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text("Identifying plant..."),
          ],
        );
        break;

      case ResultState.identified:
        bgColor = const Color(0xFFD4EDDA);
        borderColor = Colors.green;

        content = Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: plantName ?? "",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF155724),
                  ),
                  children: [
                    if (confidence != null)
                      TextSpan(
                        text: "  (${(confidence! * 100).toStringAsFixed(0)}%)",
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
        break;

      case ResultState.notIdentified:
        bgColor = const Color(0xFFFFF3CD);
        borderColor = Colors.orange;

        content = const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Plant could not be identified.",
                style: TextStyle(color: Color(0xFF856404)),
              ),
            ),
          ],
        );
        break;

      default:
        return const SizedBox();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: borderColor,
            width: 5,
          ),
        ),
      ),
      child: content,
    );
  }
}