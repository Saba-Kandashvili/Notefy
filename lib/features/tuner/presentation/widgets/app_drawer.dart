import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/tuning_mode.dart';

/// Navigation drawer for the tuner app
class AppDrawer extends StatelessWidget {
  final TuningMode currentMode;
  final void Function(TuningMode mode) onModeSelected;
  final VoidCallback onReportBug;

  const AppDrawer({
    super.key,
    required this.currentMode,
    required this.onModeSelected,
    required this.onReportBug,
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
}
