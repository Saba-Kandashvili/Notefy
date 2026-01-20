import 'package:flutter/material.dart';

class SeismographPainter extends CustomPainter {
  final List<double> trailPositions; // List of cents values
  final String targetNote;
  final bool isActive;
  final double currentCents;
  final String currentNote;
  final int currentOctave;
  final bool isInStandby;
  final double standbyProgress;
  final double scrollOffset; // Continuous scroll offset in pixels

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

    // Background gradient
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF0D0D1A), const Color(0xFF151528)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw animated horizontal guide lines (scrolling upward)
    final guidePaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    const int numLines = 8; // More lines for smoother scrolling effect
    final lineSpacing = size.height / numLines;
    // Use modulo to wrap scroll offset smoothly
    final lineScrollOffset = scrollOffset % lineSpacing;

    for (int i = -1; i <= numLines; i++) {
      // Start from -1 to have lines entering from bottom
      double y = (i * lineSpacing) - lineScrollOffset;
      // Wrap around when line goes off the top
      if (y < 0) y += size.height + lineSpacing;
      if (y > size.height) continue;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guidePaint);
    }

    // Draw vertical center line (perfect pitch line)
    final centerLinePaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.6)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, size.height),
      centerLinePaint,
    );

    // Draw green zone around center (±5 cents = in tune)
    final greenZoneWidth = size.width * 0.05; // 5% of width for ±5 cents
    final greenZonePaint = Paint()..color = Colors.greenAccent.withOpacity(0.1);
    canvas.drawRect(
      Rect.fromLTWH(
        centerX - greenZoneWidth,
        0,
        greenZoneWidth * 2,
        size.height,
      ),
      greenZonePaint,
    );

    // Draw target note label at top center (only if there's a target)
    if (targetNote.isNotEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: targetNote,
          style: TextStyle(
            color: Colors.greenAccent.withOpacity(0.8),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(centerX - textPainter.width / 2, 10));
    }

    // Draw "FLAT" and "SHARP" labels
    final flatPainter = TextPainter(
      text: TextSpan(
        text: "← FLAT",
        style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    );
    flatPainter.layout();
    flatPainter.paint(canvas, Offset(20, size.height - 25));

    final sharpPainter = TextPainter(
      text: TextSpan(
        text: "SHARP →",
        style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    );
    sharpPainter.layout();
    sharpPainter.paint(
      canvas,
      Offset(size.width - sharpPainter.width - 20, size.height - 25),
    );

    // Always draw the bubble when active (even in standby)
    if (!isActive) return;

    // Calculate bubble position first (we need it for the trail)
    final bubbleY = size.height - 60;
    final currentX = centerX + (currentCents / 100) * (size.width / 2 - 40);

    // Determine bubble color based on state
    Color bubbleColor;
    if (isInStandby) {
      // Fade to a neutral cyan/blue color during standby
      bubbleColor = Color.lerp(
        _getColorForCents(currentCents),
        const Color(0xFF64B5F6), // Light blue for standby
        standbyProgress,
      )!;
    } else if (currentNote != "--") {
      bubbleColor = _getColorForCents(currentCents);
    } else {
      bubbleColor = const Color(0xFF64B5F6); // Default light blue
    }

    // Draw the trail that scrolls upward (seismograph effect)
    // Trail ALWAYS draws and starts exactly at the bubble
    if (trailPositions.isNotEmpty) {
      final trailLength = trailPositions.length;
      final trailHeight = size.height - 120; // Available height for trail

      final tracePaint = Paint()
        ..strokeWidth =
            3.5 // Thicker trail
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Draw trail from bubble upward - segment by segment for gradient effect
      for (int i = 0; i < trailLength - 1; i++) {
        final cents1 = trailPositions[i];
        final cents2 = trailPositions[i + 1];

        // Map cents to x positions
        final x1 = centerX + (cents1 / 100) * (size.width / 2 - 40);
        final x2 = centerX + (cents2 / 100) * (size.width / 2 - 40);

        // Y positions: index 0 is at bubble, higher indices go upward
        final y1 = bubbleY - (i / trailLength) * trailHeight;
        final y2 = bubbleY - ((i + 1) / trailLength) * trailHeight;

        // Skip if off screen
        if (y2 < 30) continue;

        // Fade out as trail goes up (older = more transparent)
        final age = i / trailLength;
        final segmentOpacity = (1.0 - age * 0.85).clamp(0.1, 1.0);

        // Use bubble color with fading opacity
        tracePaint.color = bubbleColor.withOpacity(segmentOpacity * 0.8);
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), tracePaint);
      }
    }

    // Draw the current position circle (floating note bubble)
    final currentY = bubbleY;

    // Glow effect (reduce during standby for subtle look)
    final glowOpacity = isInStandby ? 0.3 * (1 - standbyProgress * 0.5) : 0.3;
    final glowPaint = Paint()
      ..color = bubbleColor.withOpacity(glowOpacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(Offset(currentX, currentY), 30, glowPaint);

    // Main bubble
    final bubblePaint = Paint()
      ..color = bubbleColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(currentX, currentY), 25, bubblePaint);

    // Border (make it more prominent during standby)
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(isInStandby ? 0.7 : 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(currentX, currentY), 25, borderPaint);

    // Content inside bubble - show note or music symbol
    if (isInStandby) {
      // Show music note symbol (♪) when in standby - fade in as standby progresses
      final symbolOpacity = standbyProgress.clamp(0.0, 1.0);
      final notePainter = TextPainter(
        text: TextSpan(
          text: "♪",
          style: TextStyle(
            color: Colors.black.withOpacity(symbolOpacity),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      notePainter.layout();
      notePainter.paint(
        canvas,
        Offset(
          currentX - notePainter.width / 2,
          currentY - notePainter.height / 2,
        ),
      );

      // Fade out the note text during transition
      if (standbyProgress < 1.0 && currentNote != "--") {
        final noteOpacity = (1.0 - standbyProgress).clamp(0.0, 1.0);
        final noteTextPainter = TextPainter(
          text: TextSpan(
            text: "$currentNote$currentOctave",
            style: TextStyle(
              color: Colors.black.withOpacity(noteOpacity),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        noteTextPainter.layout();
        noteTextPainter.paint(
          canvas,
          Offset(
            currentX - noteTextPainter.width / 2,
            currentY - noteTextPainter.height / 2,
          ),
        );
      }
    } else if (currentNote != "--") {
      // Show current note when not in standby
      final noteOpacity = isInStandby ? 1.0 - standbyProgress : 1.0;
      final notePainter = TextPainter(
        text: TextSpan(
          text: "$currentNote$currentOctave",
          style: TextStyle(
            color: Colors.black.withOpacity(noteOpacity),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      notePainter.layout();
      notePainter.paint(
        canvas,
        Offset(
          currentX - notePainter.width / 2,
          currentY - notePainter.height / 2,
        ),
      );
    } else {
      // No pitch detected - show music note
      final notePainter = TextPainter(
        text: const TextSpan(
          text: "♪",
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      notePainter.layout();
      notePainter.paint(
        canvas,
        Offset(
          currentX - notePainter.width / 2,
          currentY - notePainter.height / 2,
        ),
      );
    }
  }

  Color _getColorForCents(double cents) {
    double absCents = cents.abs();
    if (absCents < 5) {
      return Colors.greenAccent;
    } else if (absCents < 15) {
      return Colors.yellowAccent;
    } else {
      return Colors.redAccent;
    }
  }

  @override
  bool shouldRepaint(SeismographPainter oldDelegate) {
    return true; // Always repaint for smooth animation
  }
}
