import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notefy/features/guitar/presentation/tuning_editor.dart';
import 'package:notefy/features/guitar/presentation/widgets/modern_headstock.dart';

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
    HapticFeedback.mediumImpact();
    final TextEditingController nameController = TextEditingController(
      text: "Custom Tuning ${controller.customPresets.length + 1}",
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "CREATE PRESET",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Give your custom tuning a name to get started.",
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryAccent, width: 1.5),
                ),
                prefixIcon: const Icon(Icons.edit_note_rounded, color: AppColors.primaryAccent),
              ),
              onSubmitted: (_) {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(ctx);
                  _finalizeCreatePreset(context, name);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                _finalizeCreatePreset(context, name);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            child: const Text("CREATE"),
          ),
        ],
      ),
    );
  }

  void _finalizeCreatePreset(BuildContext context, String name) {
    final newPreset = TuningPreset.standard6String();
    newPreset.id = DateTime.now().millisecondsSinceEpoch.toString();
    newPreset.name = name;

    controller.addCustomPreset(newPreset);
    _openEditor(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final targetString = controller.targetString;

    return Column(
      children: [
        // Header with edit and preset selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
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
                    vertical: 4,
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

        // String selector - scrollable modern design
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ModernHeadstock(
            preset: controller.currentPreset,
            selectedString: targetString,
            onStringSelected: (str) => controller.selectString(str),
            currentCents: state.cents,
            isRecording: state.isRecording,
          ),
        ),

        const SizedBox(height: 4),

        // Target string info - prominent note name and tiny frequency
        if (targetString != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  targetString.name,
                  style: const TextStyle(
                    color: AppColors.primaryAccent,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                  ),
                ),
                Text(
                  "${targetString.frequency.toStringAsFixed(1)} Hz",
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              "Select a string to tune",
              style: TextStyle(
                color: AppColors.textDisabled,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

        // Seismograph - takes remaining space
        Expanded(
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

        const SizedBox(height: 12),
      ],
    );
  }
}
