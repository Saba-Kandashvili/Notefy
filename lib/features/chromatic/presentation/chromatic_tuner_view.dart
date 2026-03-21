import 'package:flutter/material.dart';

import '../../../core/widgets/record_button.dart';
import '../../../core/widgets/seismograph_widget.dart';
import '../../../core/widgets/tuning_status_bar.dart';
import '../../tuner/presentation/tuner_controller.dart';
import 'widgets/chromatic_note_display.dart';

/// Chromatic tuner view - detects any note
class ChromaticTunerView extends StatelessWidget {
  final TunerController controller;

  const ChromaticTunerView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final state = controller.state;

    return Column(
      children: [
        const SizedBox(height: 10),

        // Modern Note Display with Gauge and Confidence
        ChromaticNoteDisplay(
          state: state,
          isInStandby: controller.isInStandby,
        ),

        const SizedBox(height: 10),

        // Seismograph - takes remaining space
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

        const SizedBox(height: 8),

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

        const SizedBox(height: 20),
      ],
    );
  }
}
