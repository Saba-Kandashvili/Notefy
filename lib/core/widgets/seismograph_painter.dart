import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SeismographPainter extends CustomPainter {
  final List<double> trailPositions;
  final String targetNote;
  final bool isActive;
  final double currentCents;
  final String currentNote;
  final int currentOctave;
  final bool isInStandby;
  final double standbyProgress;
  final double scrollOffset;

  SeismographPainter({
    required this.trailPositions,
    required this.targetNote,
    required this.isActive,
    required this.currentCents,
    required this.currentNote,
    required this.currentOctave,
    this.isInStandby = false,
    this.standbyProgress = 0.0,
    this.scrollOffset = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // 1. MODERN DEPTH BACKGROUND
    _drawBackground(canvas, size, rect);

    // 2. PERSPECTIVE GRID
    _drawPerspectiveGrid(canvas, size, centerX);

    // 3. CENTER PRECISION BEAM (LASER)
    _drawCenterBeam(canvas, size, centerX);

    // 4. FLAT / SHARP INDICATORS (MODERNIZED)
    _drawStatusLabels(canvas, size);

    if (!isActive) return;

    // 5. TRAJECTORY RENDERING
    final bubbleY = size.height - 60;
    final currentX = centerX + (currentCents / 100) * (size.width / 2 - 40);
    final bubbleColor = _getBubbleColor();

    _drawTrajectory(canvas, size, centerX, bubbleY, bubbleColor);

    // 6. PROBE (NOTE BUBBLE) & SONAR RIPPLES
    _drawProbe(canvas, currentX, bubbleY, bubbleColor, size.width);
  }

  void _drawBackground(Canvas canvas, Size size, Rect rect) {
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0D0D1A),
          Color(0xFF151528),
          Color(0xFF1A1A2E),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Subtle vignette
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.4)],
        stops: const [0.6, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignettePaint);
  }

  void _drawPerspectiveGrid(Canvas canvas, Size size, double centerX) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1.0;

    // Horizontal Lines (scrolling)
    const int numLines = 12;
    final lineSpacing = size.height / (numLines - 2);
    final lineScrollOffset = scrollOffset % lineSpacing;

    for (int i = -1; i <= numLines; i++) {
      double y = (i * lineSpacing) - lineScrollOffset;
      if (y < 0 || y > size.height) continue;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Vertical Perspective Lines
    for (double x = -size.width; x <= size.width * 2; x += 60) {
      // Simple perspective: lines converge towards a point above the screen
      final double topX = centerX + (x - centerX) * 0.4;
      canvas.drawLine(Offset(topX, 0), Offset(x, size.height), gridPaint);
    }
  }

  void _drawCenterBeam(Canvas canvas, Size size, double centerX) {
    final bool isCorrectNote = !isInStandby && currentCents.abs() < 5 && currentNote != "--";

    // Ambient Beam
    final beamPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          (isCorrectNote ? AppColors.inTuneColor : Colors.greenAccent).withValues(alpha: 0.15),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(centerX - 20, 0, 40, size.height));

    canvas.drawRect(Rect.fromLTWH(centerX - 15, 0, 30, size.height), beamPaint);

    // Core Laser Line
    final laserPaint = Paint()
      ..color = (isCorrectNote ? AppColors.inTuneColor : Colors.greenAccent).withValues(alpha: 0.4)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(centerX, 0), Offset(centerX, size.height), laserPaint);

    // Precision dots on the line
    final dotPaint = Paint()..color = laserPaint.color.withValues(alpha: 0.2);
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawCircle(Offset(centerX, y), 2, dotPaint);
    }
  }

  void _drawStatusLabels(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.2),
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 2.0,
    );

    final flatPainter = TextPainter(
      text: TextSpan(text: "FLAT", style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final sharpPainter = TextPainter(
      text: TextSpan(text: "SHARP", style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    flatPainter.paint(canvas, Offset(24, size.height - 30));
    sharpPainter.paint(canvas, Offset(size.width - sharpPainter.width - 24, size.height - 30));

    // Target note at top
    if (targetNote.isNotEmpty) {
      final targetPainter = TextPainter(
        text: TextSpan(
          text: "TARGET: $targetNote",
          style: TextStyle(
            color: AppColors.primaryAccent.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      targetPainter.paint(canvas, Offset(size.width / 2 - targetPainter.width / 2, 20));
    }
  }

  void _drawTrajectory(Canvas canvas, Size size, double centerX, double bubbleY, Color bubbleColor) {
    if (trailPositions.isEmpty) return;

    final trailLength = trailPositions.length;
    final trailHeight = size.height - 120;

    // Main Trajectory Path
    final path = Path();
    bool first = true;

    for (int i = 0; i < trailLength; i++) {
      final cents = trailPositions[i];
      final x = centerX + (cents / 100) * (size.width / 2 - 40);
      final y = bubbleY - (i / trailLength) * trailHeight;

      if (y < 40) break;

      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }

    // Outer Glow Path
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          bubbleColor.withValues(alpha: 0.3),
          bubbleColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, glowPaint);

    // Inner Core Path
    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          bubbleColor.withValues(alpha: 0.8),
          bubbleColor.withValues(alpha: 0.1),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, corePaint);
  }

  void _drawProbe(Canvas canvas, double x, double y, Color color, double width) {
    // 0. SCAN BEAM (Subtle horizontal glow at sensor level)
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.08),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, y - 20, width, 40));
    canvas.drawRect(Rect.fromLTWH(0, y - 20, width, 40), scanPaint);

    // 1. SONAR RIPPLES (Dynamic expanding rings)
    final rippleProgress = (DateTime.now().millisecondsSinceEpoch % 2000) / 2000.0;
    for (int i = 0; i < 2; i++) {
      final double progress = (rippleProgress + (i * 0.5)) % 1.0;
      final double rippleRadius = 25 + (progress * 40);
      final double rippleOpacity = (1.0 - progress) * 0.3;

      final ripplePaint = Paint()
        ..color = color.withValues(alpha: rippleOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      
      canvas.drawCircle(Offset(x, y), rippleRadius, ripplePaint);
    }

    // 2. GLOW
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(Offset(x, y), 35, glowPaint);

    // 3. OUTER RING
    final outerRingPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(x, y), 28, outerRingPaint);

    // 4. MAIN PROBE BODY
    final probePaint = Paint()..color = color;
    canvas.drawCircle(Offset(x, y), 22, probePaint);

    // 5. INNER SHINE
    final shinePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.4),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(x, y), radius: 22));
    canvas.drawCircle(Offset(x, y), 22, shinePaint);

    // 6. NOTE TEXT
    _drawProbeText(canvas, x, y);
  }

  void _drawProbeText(Canvas canvas, double x, double y) {
    String text = "";
    double opacity = 1.0;

    if (isInStandby) {
      text = "♪";
      opacity = standbyProgress.clamp(0.0, 1.0);
    } else if (currentNote != "--") {
      text = "$currentNote$currentOctave";
    } else {
      text = "♪";
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black.withValues(alpha: opacity),
          fontSize: text == "♪" ? 22 : 14,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
  }

  Color _getBubbleColor() {
    if (isInStandby) {
      return Color.lerp(
        _getColorForCents(currentCents),
        AppColors.standbyColor,
        standbyProgress,
      )!;
    }
    if (currentNote == "--") return AppColors.standbyColor;
    return _getColorForCents(currentCents);
  }

  Color _getColorForCents(double cents) {
    double absCents = cents.abs();
    if (absCents < 5) return AppColors.inTuneColor;
    if (absCents < 20) return AppColors.closeColor;
    return AppColors.outOfTuneColor;
  }

  @override
  bool shouldRepaint(SeismographPainter oldDelegate) => true;
}
