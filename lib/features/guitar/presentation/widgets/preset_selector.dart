import 'package:flutter/material.dart';

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
      backgroundColor: AppColors.drawerBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Select Preset",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          // Create new button
          ListTile(
            leading: const Icon(
              Icons.add_circle,
              color: AppColors.primaryAccent,
            ),
            title: const Text(
              "Create New Preset",
              style: TextStyle(
                color: AppColors.primaryAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              onCreateNew();
            },
          ),
          const Divider(color: Colors.white24),

          Expanded(
            child: ListView(
              children: [
                // Factory presets section
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    "Factory Presets",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                _buildPresetTile(
                  context,
                  preset: TuningPreset.standard6String(),
                  title: "Standard 6-String",
                ),
                _buildPresetTile(
                  context,
                  preset: TuningPreset.standard7String(),
                  title: "7-String Standard (B)",
                ),

                // Custom presets section
                if (customPresets.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      "My Presets",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ...customPresets.map(
                    (preset) => _buildPresetTile(
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

  Widget _buildPresetTile(
    BuildContext context, {
    required TuningPreset preset,
    required String title,
    bool showDelete = false,
  }) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      trailing: showDelete
          ? IconButton(
              icon: const Icon(
                Icons.delete,
                color: AppColors.textDisabled,
                size: 20,
              ),
              onPressed: () {
                Navigator.pop(context);
                onDeletePreset(preset);
              },
            )
          : null,
      onTap: () {
        Navigator.pop(context);
        onPresetSelected(preset);
      },
    );
  }
}
