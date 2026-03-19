import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Reusable record/stop button widget
class RecordButton extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onPressed;
  final double size;

  const RecordButton({
    super.key,
    required this.isRecording,
    required this.onPressed,
    this.size = 64.0,
  });

  @override
  Widget build(BuildContext context) {
    final color = isRecording ? Colors.red : AppColors.primaryAccent;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Icon(
          isRecording ? Icons.stop : Icons.mic,
          size: size * 0.45,
          color: Colors.black,
        ),
      ),
    );
  }
}
