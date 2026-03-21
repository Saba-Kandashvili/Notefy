import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../tuner/domain/tuner_state.dart';

class ChromaticNoteDisplay extends StatelessWidget {
  final TunerState state;
  final bool isInStandby;

  const ChromaticNoteDisplay({
    super.key,
    required this.state,
    required this.isInStandby,
  });

  Color _getTuningColor(double cents) {
    double absCents = cents.abs();
    if (absCents < 5) return AppColors.inTuneColor;
    if (absCents < 15) return AppColors.closeColor;
    return AppColors.outOfTuneColor;
  }

  @override
  Widget build(BuildContext context) {
    final isActive = state.isActive && !isInStandby;
    final tuningColor = isActive ? _getTuningColor(state.cents) : AppColors.textMuted;
    
    // Calculate estimated error % from confidence
    // In YIN, lower difference values mean higher confidence.
    // Our confidence is already 0.0 to 1.0.
    final double confidence = isActive ? state.confidence : 0.0;
    final double errorPercent = isActive ? (1.0 - confidence) * 100.0 : 0.0;

    // Pulse effect when in tune
    final bool isInTune = isActive && state.cents.abs() < 5;
    final double pulse = isInTune 
        ? 1.0 + 0.05 * sin(DateTime.now().millisecondsSinceEpoch / 200)
        : 1.0;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Circular Progress/Meter
            SizedBox(
              width: 220,
              height: 220,
              child: CustomPaint(
                painter: _TuningCirclePainter(
                  cents: state.cents,
                  isActive: isActive,
                  tuningColor: tuningColor,
                  confidence: confidence,
                ),
              ),
            ),

            // Note Name
            Transform.scale(
              scale: pulse,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isActive ? state.note : "--",
                    style: TextStyle(
                      fontSize: 84,
                      fontWeight: FontWeight.w900,
                      color: tuningColor,
                      letterSpacing: -4,
                      height: 1.0,
                      shadows: [
                        if (isInTune)
                          Shadow(
                            color: tuningColor.withValues(alpha: 0.5),
                            blurRadius: 20 * (pulse - 0.95),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    isActive ? state.octave.toString() : "",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: tuningColor.withValues(alpha: 0.5),
                      height: 0.8,
                    ),
                  ),
                ],
              ),
            ),

            // Cents indicator on the top
            Positioned(
              top: 15,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isActive ? 1.0 : 0.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: tuningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: tuningColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    state.centsDisplay,
                    style: TextStyle(
                      color: tuningColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Info Grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _InfoChip(
                label: "FREQUENCY",
                value: isActive ? "${state.currentPitch.toStringAsFixed(1)} Hz" : "-- Hz",
                icon: Icons.waves_rounded,
              ),
              _InfoChip(
                label: "EST. ERROR",
                value: isActive ? "${errorPercent.toStringAsFixed(1)} %" : "-- %",
                icon: Icons.error_outline_rounded,
                valueColor: isActive ? _getErrorColor(errorPercent) : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getErrorColor(double error) {
    if (error < 5) return AppColors.inTuneColor;
    if (error < 15) return AppColors.closeColor;
    return AppColors.outOfTuneColor;
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _TuningCirclePainter extends CustomPainter {
  final double cents;
  final bool isActive;
  final Color tuningColor;
  final double confidence;

  _TuningCirclePainter({
    required this.cents,
    required this.isActive,
    required this.tuningColor,
    required this.confidence,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // 1. Draw background track
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    
    canvas.drawCircle(center, radius - 10, trackPaint);

    if (!isActive) return;

    // 2. Draw accuracy arc (cents)
    // -50 to +50 cents covers the top 180 degrees
    final arcPaint = Paint()
      ..color = tuningColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final double startAngle = -pi - (pi / 4); // Start at roughly 8 o'clock
    final double sweepAngle = 1.5 * pi; // Sweep 270 degrees
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 10),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    // 3. Draw current cents needle/marker
    final needlePaint = Paint()
      ..color = tuningColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Map -50..50 cents to the sweep angle
    // center of sweep is top (-pi/2)
    final double normalizedCents = (cents / 50.0).clamp(-1.0, 1.0);
    final double needleAngle = -pi / 2 + (normalizedCents * (sweepAngle / 2));

    final Offset needleStart = Offset(
      center.dx + (radius - 20) * cos(needleAngle),
      center.dy + (radius - 20) * sin(needleAngle),
    );
    final Offset needleEnd = Offset(
      center.dx + (radius) * cos(needleAngle),
      center.dy + (radius) * sin(needleAngle),
    );
    canvas.drawLine(needleStart, needleEnd, needlePaint);

    // 4. Glow around needle
    final glowPaint = Paint()
      ..color = tuningColor.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(needleEnd, 6, glowPaint);

    // 5. Confidence Ring (Inner)
    final confidencePaint = Paint()
      ..color = AppColors.primaryAccent.withValues(alpha: confidence * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawCircle(center, radius - 30, confidencePaint);
    
    // Add some techy bits
    _drawTicks(canvas, center, radius - 10, startAngle, sweepAngle);
  }

  void _drawTicks(Canvas canvas, Offset center, double radius, double startAngle, double sweepAngle) {
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    for (int i = 0; i <= 10; i++) {
      final double angle = startAngle + (sweepAngle * (i / 10));
      final Offset p1 = Offset(
        center.dx + (radius - 15) * cos(angle),
        center.dy + (radius - 15) * sin(angle),
      );
      final Offset p2 = Offset(
        center.dx + (radius - 5) * cos(angle),
        center.dy + (radius - 5) * sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TuningCirclePainter oldDelegate) {
    return oldDelegate.cents != cents || 
           oldDelegate.isActive != isActive || 
           oldDelegate.confidence != confidence;
  }
}
