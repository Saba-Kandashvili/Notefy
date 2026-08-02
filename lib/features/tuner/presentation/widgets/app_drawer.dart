import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/tuning_mode.dart';

/// Navigation drawer for the tuner app
class AppDrawer extends StatelessWidget {
  final TuningMode currentMode;
  final void Function(TuningMode mode) onModeSelected;
  final VoidCallback onReportBug;

  final List<InputDevice> availableMicrophones;
  final InputDevice? selectedMicrophone;
  final void Function(InputDevice? device)? onMicrophoneSelected;

  const AppDrawer({
    super.key,
    required this.currentMode,
    required this.onModeSelected,
    required this.onReportBug,
    this.availableMicrophones = const [],
    this.selectedMicrophone,
    this.onMicrophoneSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(),
          _buildModeItem(
            context,
            icon: Icons.graphic_eq,
            mode: TuningMode.chromatic,
          ),
          _buildModeItem(
            context,
            icon: Icons.music_note,
            mode: TuningMode.guitar,
          ),
          _buildModeItem(context, icon: Icons.piano, mode: TuningMode.piano),
          _buildModeItem(
            context,
            icon: Icons.fitness_center,
            mode: TuningMode.practice,
          ),
          _buildModeItem(
            context,
            icon: Icons.waves,
            mode: TuningMode.generator,
          ),
          _buildModeItem(
            context,
            icon: Icons.analytics,
            mode: TuningMode.analyzer,
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(
              Icons.bug_report,
              color: AppColors.textSecondary,
            ),
            title: const Text(
              "Report a Bug",
              style: TextStyle(color: AppColors.textSecondary),
            ),
            onTap: () {
              Navigator.pop(context);
              onReportBug();
            },
          ),

          if (availableMicrophones.isNotEmpty) ...[
            const Divider(color: Colors.white24),
            _buildMicrophoneSelector(context),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return DrawerHeader(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.scaffoldBackground, AppColors.drawerBackground],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.music_note,
              color: AppColors.primaryAccent,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            AppConstants.appName,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.warningAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AppColors.warningAccent.withValues(alpha: 0.5),
              ),
            ),
            child: const Text(
              AppConstants.appVersion,
              style: TextStyle(
                color: AppColors.warningAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeItem(
    BuildContext context, {
    required IconData icon,
    required TuningMode mode,
  }) {
    final isSelected = currentMode == mode;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primaryAccent : AppColors.textSecondary,
      ),
      title: Text(
        mode.displayName,
        style: TextStyle(
          color: isSelected ? AppColors.primaryAccent : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        mode.description,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      selected: isSelected,
      selectedTileColor: AppColors.primaryAccent.withValues(alpha: 0.1),
      onTap: () => onModeSelected(mode),
    );
  }

  Widget _buildMicrophoneSelector(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
            child: Text(
              "AUDIO INPUT",
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showMicrophonePicker(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryAccent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryAccent.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryAccent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic_none_rounded,
                        color: AppColors.primaryAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedMicrophone?.label.isNotEmpty == true
                                ? selectedMicrophone!.label
                                : (selectedMicrophone != null
                                      ? "Device ${selectedMicrophone!.id}"
                                      : "Default System Mic"),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Tap to change source",
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.unfold_more_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMicrophonePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          decoration: BoxDecoration(
            color: AppColors.drawerBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: AppColors.primaryAccent.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle pill
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.graphic_eq_rounded,
                        color: AppColors.primaryAccent,
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Select Audio Source",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ...availableMicrophones.map((device) {
                  final isSelected = selectedMicrophone?.id == device.id;
                  final name = device.label.isNotEmpty
                      ? device.label
                      : "Device ${device.id}";

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (onMicrophoneSelected != null) {
                          onMicrophoneSelected!(device);
                        }
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        color: isSelected
                            ? AppColors.primaryAccent.withValues(alpha: 0.1)
                            : Colors.transparent,
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.mic_rounded
                                  : Icons.mic_none_rounded,
                              color: isSelected
                                  ? AppColors.primaryAccent
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.primaryAccent
                                      : AppColors.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primaryAccent,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
