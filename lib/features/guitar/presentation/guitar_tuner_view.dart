import 'package:flutter/material.dart';
import 'package:notefy/features/guitar/presentation/tuning_editor.dart';
import 'package:notefy/features/guitar/presentation/widgets/dynamic_headstock.dart';

import '../../../core/models/tuning_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/record_button.dart';
import '../../../core/widgets/seismograph_widget.dart';
import '../../../core/widgets/tuning_status_bar.dart';
import '../../tuner/presentation/tuner_controller.dart';
import 'widgets/preset_selector.dart';

/// Guitar tuner view with headstock visualization
class GuitarTunerView extends StatelessWidget {
  final TunerController controller;

  const GuitarTunerView({super.key, required this.controller});

  void _openEditor(BuildContext context) async {
    final editedPreset = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TuningEditor(initialPreset: controller.currentPreset),
      ),
    );

    if (editedPreset != null && editedPreset is TuningPreset) {
      controller.updatePreset(editedPreset);
    }
  }

  void _showPresetSelector(BuildContext context) {
    PresetSelector.show(
      context,
      currentPreset: controller.currentPreset,
      customPresets: controller.customPresets,
      onPresetSelected: (preset) => controller.setPreset(preset),
      onCreateNew: () => _createNewPreset(context),
      onDeletePreset: (preset) => controller.deletePreset(preset),
    );
  }

  void _createNewPreset(BuildContext context) {
    final newPreset = TuningPreset.standard6String();
    newPreset.id = DateTime.now().millisecondsSinceEpoch.toString();
    newPreset.name = "Custom Tuning ${controller.customPresets.length + 1}";

    controller.addCustomPreset(newPreset);
    _openEditor(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final targetString = controller.targetString;

    return Column(
      children: [
        // Header with settings and preset selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.settings,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => _openEditor(context),
              ),
              InkWell(
                onTap: () => _showPresetSelector(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        controller.currentPreset.name,
                        style: const TextStyle(
                          color: AppColors.primaryAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: AppColors.primaryAccent,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),

        // Headstock visualization
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DynamicHeadstock(
                preset: controller.currentPreset,
                selectedString: targetString,
                onStringSelected: (str) => controller.selectString(str),
              ),
            ),
          ),
        ),

        // Target string info
        if (targetString != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              "Target: ${targetString.name} (${targetString.frequency.toStringAsFixed(1)} Hz)",
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              "Select a string to tune",
              style: TextStyle(color: AppColors.textDisabled, fontSize: 14),
            ),
          ),

        // Seismograph
        Expanded(
          flex: 5,
          child: SeismographWidget(
            trailPositions: controller.trailPositions,
            targetNote: targetString?.name ?? "",
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
