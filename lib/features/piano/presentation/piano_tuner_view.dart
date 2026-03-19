import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/record_button.dart';
import '../../../core/widgets/seismograph_widget.dart';
import '../../../core/widgets/tuning_status_bar.dart';
import '../../tuner/presentation/tuner_controller.dart';
import 'piano_calibration_screen.dart';
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

  void _showApproachInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceColor,
        title: const Text("How Piano Tuning Works"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Stretched Tuning & Inharmonicity",
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Unlike a guitar, piano strings are very stiff. This stiffness causes their overtones to be 'sharp'. If we tuned every note perfectly to its theoretical frequency, the piano would sound 'out of tune' with itself.",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                "Our Approach: Recording",
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Instead of asking you to measure string thickness or length (which is difficult and prone to error), we ask you to record a few keys. The app analyzes the exact overtones of your piano strings to build a mathematical model of its unique 'inharmonicity'.",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                "Calibration Steps",
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "1. Tap 'Calibrate' and follow the guide.\n2. Play the requested keys (A1 to A6).\n3. The app calculates the perfect 'Stretch' for all 88 keys based on these measurements.",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Got it"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final state = controller.state;
    final selectedKey = controller.selectedPianoKey;

    final isDefaultProfile = controller.pianoProfile.id == 'default_et';

    return Column(
      children: [
        const SizedBox(height: 10),

        // Calibration banner
        if (isDefaultProfile)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PianoCalibrationScreen(controller: controller),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.primaryAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Calibrate Stretched Tuning",
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          "Pianos are not tuned to equal temperament. Tap to set up.",
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.inTuneColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  "Using Profile: ${controller.pianoProfile.name}",
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 10),

        // Piano keyboard
        PianoKeyboard(
          selectedKey: selectedKey,
          keys: controller.stretchedPianoKeys,
          cents: state.cents,
          isRecording: state.isRecording,
          onKeySelected: (key) => controller.selectPianoKey(key),
          scrollController: _pianoScrollController,
        ),

        const SizedBox(height: 10),

        // Target key info and Setup button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: selectedKey != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Target: ${selectedKey.fullName}",
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${selectedKey.targetFrequency.toStringAsFixed(2)} Hz (Key #${selectedKey.keyNumber})",
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        "Select a key to tune",
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
              ),
              IconButton.filledTonal(
                onPressed: () => _showApproachInfo(context),
                icon: const Icon(Icons.info_outline),
                tooltip: "How it works",
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceColor,
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PianoCalibrationScreen(controller: controller),
                    ),
                  );
                },
                icon: const Icon(Icons.settings_suggest),
                tooltip: "Piano Calibration",
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceColor,
                  foregroundColor: AppColors.primaryAccent,
                ),
              ),
            ],
          ),
        ),

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
