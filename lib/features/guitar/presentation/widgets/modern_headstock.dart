import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/tuning_model.dart';
import '../../../../core/theme/app_theme.dart';

class ModernHeadstock extends StatefulWidget {
  final TuningPreset preset;
  final InstrumentString? selectedString;
  final Function(InstrumentString) onStringSelected;
  final double currentCents;
  final bool isRecording;

  const ModernHeadstock({
    super.key,
    required this.preset,
    required this.selectedString,
    required this.onStringSelected,
    this.currentCents = 0.0,
    this.isRecording = false,
  });

  @override
  State<ModernHeadstock> createState() => _ModernHeadstockState();
}

class _ModernHeadstockState extends State<ModernHeadstock> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = _getSelectedIndex();
    _pageController = PageController(
      viewportFraction: _getViewportFraction(),
      initialPage: _currentIndex,
    );
  }

  @override
  void didUpdateWidget(ModernHeadstock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedString != oldWidget.selectedString) {
      final newIndex = _getSelectedIndex();
      if (newIndex != _currentIndex) {
        _currentIndex = newIndex;
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
        );
      }
    }
  }

  int _getSelectedIndex() {
    if (widget.selectedString == null) return 0;
    final index = widget.preset.strings.indexOf(widget.selectedString!);
    return index != -1 ? index : 0;
  }

  double _getViewportFraction() {
    final count = widget.preset.strings.length;
    if (count <= 4) return 0.25;
    if (count <= 6) return 0.2;
    if (count <= 12) return 0.15;
    return 0.12;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110, // Reduced height
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background "fretboard" texture or gradient
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: CustomPaint(
                painter: _HeadstockBackgroundPainter(),
              ),
            ),
          ),

          // Strings PageView
          PageView.builder(
            controller: _pageController,
            itemCount: widget.preset.strings.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              widget.onStringSelected(widget.preset.strings[index]);
              HapticFeedback.lightImpact(); // Snappier haptic
            },
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_currentIndex != index) {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutBack, // Springier/Snappier
                    );
                  }
                },
                child: AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double value = 0.0;
                    if (_pageController.position.haveDimensions) {
                      value = index.toDouble() - (_pageController.page ?? 0);
                    } else {
                      value = index.toDouble() - _currentIndex.toDouble();
                    }

                    // Calculate scale and opacity based on distance from center
                    final double scale =
                        (1 - (value.abs() * 0.25)).clamp(0.7, 1.0);
                    final double opacity =
                        (1 - (value.abs() * 0.4)).clamp(0.2, 1.0);
                    final double translation = value * 8.0;

                    return Transform.translate(
                      offset: Offset(0, translation.abs() * 0.3),
                      child: Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity,
                          child: _ModernStringItem(
                            string: widget.preset.strings[index],
                            isSelected: widget.selectedString ==
                                widget.preset.strings[index],
                            isFocused: value.abs() < 0.5,
                            thickness: _getStringThickness(index),
                            stringColor: _getStringColor(index),
                            currentCents: widget.currentCents,
                            isRecording: widget.isRecording,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),

          // Selection indicator/overlay - Modern Green Rounded Outline
          IgnorePointer(
            child: Container(
              width: 60,
              height: 104, // Reduced height to fit new 110px container
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.primaryAccent.withValues(alpha: 0.6),
                  width: 2.0, // Slightly thinner for cleaner look
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryAccent.withValues(alpha: 0.15),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getStringThickness(int index) {
    final total = widget.preset.strings.length;
    // Bass strings are thicker
    return 2.5 + (total - 1 - index) * (total > 12 ? 0.2 : 0.8);
  }

  Color _getStringColor(int index) {
    final total = widget.preset.strings.length;
    final progress = index / (total > 1 ? total - 1 : 1);

    if (progress < 0.5) {
      return Color.lerp(
        const Color(0xFFD2B48C), // Tan/Bronze
        const Color(0xFFDAA520), // Goldenrod
        progress * 2,
      )!;
    } else {
      return Color.lerp(
        const Color(0xFFDAA520),
        const Color(0xFFC0C0C0), // Silver
        (progress - 0.5) * 2,
      )!;
    }
  }
}

class _ModernStringItem extends StatelessWidget {
  final InstrumentString string;
  final bool isSelected;
  final bool isFocused;
  final double thickness;
  final Color stringColor;
  final double currentCents;
  final bool isRecording;

  const _ModernStringItem({
    required this.string,
    required this.isSelected,
    required this.isFocused,
    required this.thickness,
    required this.stringColor,
    required this.currentCents,
    required this.isRecording,
  });

  @override
  Widget build(BuildContext context) {
    final bool active = isSelected && isRecording;
    Color statusColor = AppColors.primaryAccent;

    if (active) {
      if (currentCents.abs() < 5) {
        statusColor = AppColors.inTuneColor;
      } else if (currentCents.abs() < 20) {
        statusColor = AppColors.closeColor;
      } else {
        statusColor = AppColors.outOfTuneColor;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Note Label
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isSelected
                  ? statusColor
                  : Colors.white.withValues(alpha: 0.04),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? statusColor : Colors.white.withValues(alpha: 0.1),
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.25),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: Center(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: string.note,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    TextSpan(
                      text: string.octave.toString(),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.black.withValues(alpha: 0.6)
                            : Colors.white38,
                        fontWeight: FontWeight.bold,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Visual String
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Shadow/Glow
                if (isSelected)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: thickness + 12,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          statusColor.withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),

                // The String itself
                CustomPaint(
                  size: Size(thickness, double.infinity),
                  painter: _StringPainter(
                    color: stringColor,
                    thickness: thickness,
                    isWound: thickness > 3.8,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 2),

          // Frequency label (only when focused)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isFocused ? 0.6 : 0.0,
            child: Text(
              "${string.frequency.toStringAsFixed(1)}Hz",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StringPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool isWound;

  _StringPainter({
    required this.color,
    required this.thickness,
    required this.isWound,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Side-to-side gradient for 3D effect
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          color.withValues(alpha: 0.9),
          Colors.white.withValues(alpha: 0.4),
          color,
          color.withValues(alpha: 0.7),
        ],
        stops: const [0.0, 0.2, 0.6, 1.0],
      ).createShader(rect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(thickness / 2)),
      paint,
    );

    if (isWound) {
      // Very subtle winding texture
      final windingPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;

      final step = (thickness > 6) ? 2.5 : 2.0;
      for (double y = 0; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y + 0.5), windingPaint);
      }
    }

    // Specular highlight line (very thin)
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawLine(
      Offset(size.width * 0.2, 0),
      Offset(size.width * 0.2, size.height),
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _StringPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.thickness != thickness;
}

class _HeadstockBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Deep modern dark background
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1E1E2C),
          Color(0xFF12121A),
        ],
      ).createShader(rect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(24)),
      bgPaint,
    );

    // Subtle brushed metal / grain texture
    final random = Random(42);
    final grainPaint = Paint()..color = Colors.white.withValues(alpha: 0.01);
    for (int i = 0; i < 1500; i++) {
      canvas.drawCircle(
        Offset(random.nextDouble() * size.width,
            random.nextDouble() * size.height),
        0.5,
        grainPaint,
      );
    }

    // Modern "rail" lines
    final railPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, size.height * 0.3),
        Offset(size.width, size.height * 0.3), railPaint);
    canvas.drawLine(Offset(0, size.height * 0.7),
        Offset(size.width, size.height * 0.7), railPaint);

    // Subtle vertical dividers
    final dividerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 60) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), dividerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
