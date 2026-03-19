import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

/// Displays the current tuning status (cents deviation and status text)
class TuningStatusBar extends StatelessWidget {
  final double cents;
  final String note;
  final bool isRecording;
  final bool isInStandby;

  const TuningStatusBar({
    super.key,
    required this.cents,
    required this.note,
    required this.isRecording,
    required this.isInStandby,
  });

  Color _getTuningColor() {
    double absCents = cents.abs();
    if (absCents < AppConstants.inTuneThreshold) return AppColors.inTuneColor;
    if (absCents < AppConstants.closeThreshold) return AppColors.closeColor;
    return AppColors.outOfTuneColor;
  }

  String _getTuningStatus() {
    if (!isRecording || note == "--") return "";
    double absCents = cents.abs();
    if (absCents < AppConstants.inTuneThreshold) return "In Tune";
    if (cents > 0) return "Sharp";
    return "Flat";
  }

  @override
  Widget build(BuildContext context) {
    final isActive = isRecording && note != "--" && !isInStandby;
    final color = isActive ? _getTuningColor() : AppColors.textMuted;
    final status = _getTuningStatus();
    final centsText = cents >= 0
        ? "+${cents.toStringAsFixed(1)}"
        : cents.toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildColumn(
            value: isActive ? centsText : "--",
            label: "cents",
            color: color,
            fontSize: 20,
          ),
          Container(width: 1, height: 32, color: Colors.white12),
          _buildColumn(
            value: status.isEmpty || isInStandby ? "--" : status,
            label: "status",
            color: color,
            fontSize: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildColumn({
    required String value,
    required String label,
    required Color color,
    double fontSize = 24,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}
