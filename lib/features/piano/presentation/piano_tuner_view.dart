import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/record_button.dart';
import '../../../core/widgets/seismograph_widget.dart';
import '../../../core/widgets/tuning_status_bar.dart';
import '../../tuner/presentation/tuner_controller.dart';
import 'widgets/piano_keyboard.dart';

/// Piano tuner view with scrollable keyboard
class PianoTunerView extends StatefulWidget {
  final TunerController controller;

  const PianoTunerView({super.key, required this.controller});

  @override
  State<PianoTunerView> createState() => _PianoTunerViewState();
}

class _PianoTunerViewState extends State<PianoTunerView> {
  final ScrollController _pianoScrollController = ScrollController();

  @override
  void dispose() {
    _pianoScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final state = controller.state;
    final selectedKey = controller.selectedPianoKey;

    return Column(
      children: [
        const SizedBox(height: 10),

        // Piano keyboard
        PianoKeyboard(
          selectedKey: selectedKey,
          cents: state.cents,
          isRecording: state.isRecording,
          onKeySelected: (key) => controller.selectPianoKey(key),
          scrollController: _pianoScrollController,
        ),

        const SizedBox(height: 10),

        // Target key info
        if (selectedKey != null) ...[
          Text(
            "Target: Key #${selectedKey.keyNumber} - ${selectedKey.fullName} (${selectedKey.frequency.toStringAsFixed(2)} Hz)",
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ] else ...[
          const Text(
            "Scroll and tap a key to tune",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],

        const SizedBox(height: 10),

        // Seismograph
        Expanded(
          child: SeismographWidget(
            trailPositions: controller.trailPositions,
            targetNote: selectedKey?.fullName ?? "",
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

        const SizedBox(height: 10),

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
