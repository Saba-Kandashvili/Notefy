import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/tuning_model.dart';
import '../../../../core/theme/app_theme.dart';

/// Bottom sheet for selecting guitar tuning presets
class PresetSelector extends StatelessWidget {
  final TuningPreset currentPreset;
  final List<TuningPreset> customPresets;
  final void Function(TuningPreset preset) onPresetSelected;
  final VoidCallback onCreateNew;
  final void Function(TuningPreset preset) onDeletePreset;

  const PresetSelector({
    super.key,
    required this.currentPreset,
    required this.customPresets,
    required this.onPresetSelected,
    required this.onCreateNew,
    required this.onDeletePreset,
  });

  static void show(
    BuildContext context, {
    required TuningPreset currentPreset,
    required List<TuningPreset> customPresets,
    required void Function(TuningPreset preset) onPresetSelected,
    required VoidCallback onCreateNew,
    required void Function(TuningPreset preset) onDeletePreset,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PresetSelector(
        currentPreset: currentPreset,
        customPresets: customPresets,
        onPresetSelected: onPresetSelected,
        onCreateNew: onCreateNew,
        onDeletePreset: onDeletePreset,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.scaffoldBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "SELECT PRESET",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Create new button - Modern Outlined Style
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
              onCreateNew();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.primaryAccent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryAccent.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline_rounded,
                      color: AppColors.primaryAccent, size: 22),
                  SizedBox(width: 10),
                  Text(
                    "CREATE NEW PRESET",
                    style: TextStyle(
                      color: AppColors.primaryAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Flexible(
            child: ListView(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              children: [
                // Factory presets section
                _buildSectionHeader("FACTORY PRESETS"),
                _buildPresetCard(
                  context,
                  preset: TuningPreset.standard6String(),
                  title: "Standard 6-String",
                ),
                _buildPresetCard(
                  context,
                  preset: TuningPreset.standard7String(),
                  title: "7-String Standard (B)",
                ),

                const SizedBox(height: 16),

                // Custom presets section
                if (customPresets.isNotEmpty) ...[
                  _buildSectionHeader("MY PRESETS"),
                  ...customPresets.map(
                    (preset) => _buildPresetCard(
                      context,
                      preset: preset,
                      title: preset.name,
                      showDelete: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildPresetCard(
    BuildContext context, {
    required TuningPreset preset,
    required String title,
    bool showDelete = false,
  }) {
    final isSelected = currentPreset.id == preset.id;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pop(context);
        onPresetSelected(preset);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryAccent.withValues(alpha: 0.1)
              : AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryAccent.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.05),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Selection indicator or icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryAccent
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSelected ? Icons.check_rounded : Icons.music_note_rounded,
                color: isSelected ? Colors.black : Colors.white24,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),

            // Preset Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${preset.strings.length} STRINGS",
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.primaryAccent.withValues(alpha: 0.6)
                          : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            if (showDelete)
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                  size: 20,
                ),
                onPressed: () => _confirmDelete(context, preset),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, TuningPreset preset) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Delete Preset?",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Are you sure you want to delete '${preset.name}'?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              onDeletePreset(preset);
            },
            child: const Text(
              "DELETE",
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
