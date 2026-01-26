import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/record_button.dart';
import '../../../core/widgets/seismograph_widget.dart';
import '../../../core/widgets/tuning_status_bar.dart';
import '../../tuner/presentation/tuner_controller.dart';

/// Chromatic tuner view - detects any note
class ChromaticTunerView extends StatelessWidget {
  final TunerController controller;

  const ChromaticTunerView({super.key, required this.controller});

  Color _getTuningColor(double cents) {
    double absCents = cents.abs();
    if (absCents < 5) return AppColors.inTuneColor;
    if (absCents < 15) return AppColors.closeColor;
    return AppColors.outOfTuneColor;
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final isActive =
        state.isRecording && state.note != "--" && !controller.isInStandby;

    final detectedNote = isActive ? state.fullNoteName : "--";

    return Column(
      children: [
        const SizedBox(height: 20),

        // Large note display
        Text(
          detectedNote,
          style: TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.bold,
            color: isActive
                ? _getTuningColor(state.cents)
                : AppColors.textMuted,
          ),
        ),

        // Frequency display
        if (state.isRecording &&
            state.currentPitch > 0 &&
            !controller.isInStandby)
          Text(
            "${state.currentPitch.toStringAsFixed(1)} Hz",
            style: const TextStyle(color: AppColors.textMuted, fontSize: 16),
          ),

        const SizedBox(height: 20),

        // Seismograph
        Expanded(
          child: SeismographWidget(
            trailPositions: controller.trailPositions,
            targetNote: "",
            isActive: state.isRecording,
            currentCents: controller.displayedCents,
            currentNote: state.note,
            currentOctave: state.octave,
            isInStandby: controller.isInStandby,
            standbyProgress: controller.standbyProgress,
            scrollOffset: controller.scrollOffset,
          ),
        ),

        // Status bar
        TuningStatusBar(
          cents: state.cents,
          note: state.note,
          isRecording: state.isRecording,
          isInStandby: controller.isInStandby,
        ),

        const SizedBox(height: 20),

        // Record button
        RecordButton(
          isRecording: state.isRecording,
          onPressed: () {
            if (state.isRecording) {
              controller.stopCapture();
            } else {
              controller.startCapture();
            }
          },
        ),

        const SizedBox(height: 30),
      ],
    );
  }
}
