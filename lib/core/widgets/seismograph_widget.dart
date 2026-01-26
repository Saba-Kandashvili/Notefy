import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'seismograph_painter.dart';

/// Container widget for the seismograph visualization
class SeismographWidget extends StatelessWidget {
  final List<double> trailPositions;
  final String targetNote;
  final bool isActive;
  final double currentCents;
  final String currentNote;
  final int currentOctave;
  final bool isInStandby;
  final double standbyProgress;
  final double scrollOffset;

  const SeismographWidget({
    super.key,
    required this.trailPositions,
    required this.targetNote,
    required this.isActive,
    required this.currentCents,
    required this.currentNote,
    required this.currentOctave,
    this.isInStandby = false,
    this.standbyProgress = 0.0,
    this.scrollOffset = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: SeismographPainter(
            trailPositions: trailPositions,
            targetNote: targetNote,
            isActive: isActive,
            currentCents: currentCents,
            currentNote: currentNote,
            currentOctave: currentOctave,
            isInStandby: isInStandby,
            standbyProgress: standbyProgress,
            scrollOffset: scrollOffset,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}
