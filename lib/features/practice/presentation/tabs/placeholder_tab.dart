import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class PlaceholderTab extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const PlaceholderTab({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: AppColors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
