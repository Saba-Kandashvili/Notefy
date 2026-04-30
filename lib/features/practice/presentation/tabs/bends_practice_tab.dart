import 'dart:math';

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/record_button.dart';
import '../../../tuner/presentation/tuner_controller.dart';
import '../../domain/bend_models.dart';

class BendsPracticeTab extends StatefulWidget {
  final TunerController controller;

  const BendsPracticeTab({super.key, required this.controller});

  @override
  State<BendsPracticeTab> createState() => _BendsPracticeTabState();
}

class _BendsPracticeTabState extends State<BendsPracticeTab> {
  BendType _selectedBendType = BendType.full;
  CurveShape _selectedCurveShape = CurveShape.parabolic;
  ReferenceNote _selectedReferenceNote = ReferenceNote.g3;

  double? _referenceFrequency;
  DateTime? _startTime;
  bool _isBending = false;
  final double _durationMs = 2000.0; // 2 seconds total

  // Stability check for reference note
  int _stableFrames = 0;
  static const int _requiredStableFrames = 5; // Increased for better stability

  // Dynamic zoom state
  double _currentMaxCents = 300.0;

  // Smoothing for the real-time dot
  double _smoothedCents = 0.0;
  static const double _smoothingFactor = 0.3; // Slightly smoother than before

  // To store the path taken by the user
  List<Offset> _userPath = [];

  @override
  void initState() {
    super.initState();
    _currentMaxCents = _calculateMinMaxCents();
    widget.controller.addListener(_onPitchChanged);
    _setDetectionRange();
  }

  void _setDetectionRange() {
    // Set a narrow frequency range to improve stability and avoid jumps
    // Range is from 1 semitone below reference to 1 semitone above max bend
    final double refFreq = _selectedReferenceNote.frequency;
    final double minFreq = refFreq * pow(2, -100 / 1200);
    final double maxFreq = refFreq * pow(2, (_selectedBendType.steps * 200 + 100) / 1200);
    
    widget.controller.setFrequencyRange(minFreq, maxFreq);
  }

  double _calculateMinMaxCents() {
    return max(300.0, _selectedBendType.steps * 200 + 100);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPitchChanged);
    widget.controller.resetFrequencyRange();
    super.dispose();
  }

  void _onPitchChanged() {
    final state = widget.controller.state;
    // Increased confidence threshold and checking if it's within our expected range
    if (state.currentPitch <= 0 || state.confidence < 0.85) { 
      if (_isBending && _startTime != null) {
        final elapsed = DateTime.now().difference(_startTime!).inMilliseconds;
        // Keep session alive for a short dropout, otherwise reset
        if (elapsed > _durationMs + 500) {
          _resetSession();
        }
      } else {
        // Reset stability check if signal is lost
        _stableFrames = 0;
        setState(() {});
      }
      return;
    }

    // Calculate current cents relative to our SELECTED reference note
    final double refFreq = _selectedReferenceNote.frequency;
    double rawCents = 1200 * (log(state.currentPitch / refFreq) / log(2));

    // Apply EMA smoothing
    _smoothedCents = _smoothedCents + (rawCents - _smoothedCents) * _smoothingFactor;

    if (!_isBending) {
      // Check if user is playing the starting note stably
      // Within 25 cents of the target reference note
      if (rawCents.abs() < 25) {
        _stableFrames++;
        if (_stableFrames >= _requiredStableFrames) {
          _referenceFrequency = state.currentPitch; // Lock in the actual frequency they are playing
          // We don't reset _smoothedCents to 0 here because we want it to be relative to the THEORETICAL reference
          // Actually, let's keep it relative to theoretical reference so the 0 line is always the same.
        }
      } else {
        _stableFrames = 0;
        
        // If they are bending up from the reference, start session
        // They must have been stable at the reference note first (captured in _referenceFrequency)
        if (_referenceFrequency != null && rawCents > 30) {
           _startBending();
        }
      }
    } else {
      // Session in progress
      final elapsed = DateTime.now().difference(_startTime!).inMilliseconds;
      if (elapsed > _durationMs) {
        // End of session - keep showing for 2 seconds then auto-reset for repeat
        if (elapsed > _durationMs + 2000) {
          _resetSession();
        }
      } else {
        _userPath.add(Offset(elapsed / _durationMs, _smoothedCents));
      }
    }

    _updateZoom();
    setState(() {});
  }

  void _updateZoom() {
    double minMax = _calculateMinMaxCents();
    double targetCents = _selectedBendType.steps * 200;
    double centerY = targetCents / 2;

    // We want to ensure all points are within [centerY - currentMax/2, centerY + currentMax/2]
    double requiredHalfRange = targetCents / 2 + 50; // Minimum half range to see the whole parabola plus margin

    double extremeCentsUpper = _smoothedCents;
    double extremeCentsLower = _smoothedCents;
    for (var point in _userPath) {
      if (point.dy > extremeCentsUpper) extremeCentsUpper = point.dy;
      if (point.dy < extremeCentsLower) extremeCentsLower = point.dy;
    }

    requiredHalfRange = max(requiredHalfRange, (extremeCentsUpper - centerY).abs() + 50);
    requiredHalfRange = max(requiredHalfRange, (extremeCentsLower - centerY).abs() + 50);

    double targetMax = requiredHalfRange * 2;
    if (targetMax < minMax) targetMax = minMax;

    // Smoothly interpolate _currentMaxCents towards targetMax
    if (_currentMaxCents < targetMax) {
      _currentMaxCents = _currentMaxCents + (targetMax - _currentMaxCents) * 0.15;
    } else {
      _currentMaxCents = _currentMaxCents + (targetMax - _currentMaxCents) * 0.05;
    }
  }

  void _startBending() {
    _isBending = true;
    _startTime = DateTime.now();
    _userPath = [Offset(0, _smoothedCents)];
  }

  void _resetSession() {
    _isBending = false;
    _startTime = null;
    _referenceFrequency = null;
    _userPath = [];
    _smoothedCents = 0;
    _stableFrames = 0;
    _currentMaxCents = _calculateMinMaxCents();
  }

  Widget _buildReferenceNoteSelector() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: ReferenceNote.values.length,
        itemBuilder: (context, index) {
          final note = ReferenceNote.values[index];
          final isSelected = _selectedReferenceNote == note;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedReferenceNote = note;
              _resetSession();
              _setDetectionRange();
            }),
            child: Container(
              width: 60,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.warningAccent : AppColors.drawerBackground,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isSelected ? AppColors.warningAccent : Colors.white10,
                ),
              ),
              child: Center(
                child: Text(
                  note.label,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildReferenceNoteSelector(),
        _buildBendTypeSelector(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildGraph(),
          ),
        ),
        _buildCurveShapeSelector(),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RecordButton(
                    isRecording: widget.controller.isRecording,
                    onPressed: () {
                      if (widget.controller.isRecording) {
                        widget.controller.stopCapture();
                        _resetSession();
                      } else {
                        widget.controller.startCapture();
                      }
                    },
                    size: 56,
                  ),
                  const SizedBox(height: 4),
                  const Text("MIC", style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                ],
              ),
              const SizedBox(width: 32),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildManualTriggerButton(),
                  const SizedBox(height: 4),
                  const Text("RESET", style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualTriggerButton() {
    return GestureDetector(
      onTap: _resetSession,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.warningAccent,
          boxShadow: [
            BoxShadow(
              color: AppColors.warningAccent.withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Icon(
          Icons.refresh,
          size: 32,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildBendTypeSelector() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: BendType.values.length,
        itemBuilder: (context, index) {
          final type = BendType.values[index];
          final isSelected = _selectedBendType == type;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedBendType = type;
              _resetSession();
              _setDetectionRange();
            }),
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryAccent : AppColors.drawerBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primaryAccent : Colors.white10,
                ),
              ),
              child: Center(
                child: Text(
                  type.label,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurveShapeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: CurveShape.values.map((shape) {
          final isSelected = _selectedCurveShape == shape;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ChoiceChip(
              label: Text(shape.label),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _selectedCurveShape = shape);
              },
              selectedColor: AppColors.primaryAccent,
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }


  Widget _buildGraph() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          size: Size.infinite,
          painter: BendGraphPainter(
            bendType: _selectedBendType,
            curveShape: _selectedCurveShape,
            userPath: _userPath,
            isBending: _isBending,
            currentTime: _startTime != null
                ? DateTime.now().difference(_startTime!).inMilliseconds / _durationMs
                : 0,
            currentCents: _smoothedCents,
            maxCents: _currentMaxCents,
            baseMaxCents: _calculateMinMaxCents(),
          ),
        ),
      ),
    );
  }
}

class BendGraphPainter extends CustomPainter {
  final BendType bendType;
  final CurveShape curveShape;
  final List<Offset> userPath;
  final bool isBending;
  final double currentTime;
  final double? currentCents;
  final double maxCents;
  final double baseMaxCents;

  BendGraphPainter({
    required this.bendType,
    required this.curveShape,
    required this.userPath,
    required this.isBending,
    required this.currentTime,
    required this.maxCents,
    required this.baseMaxCents,
    this.currentCents,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final targetCents = bendType.steps * 200;
    final double centerY = targetCents / 2;
    final double centerX = 0.5;

    // Zoom factor based on vertical range. 1.0 means base view.
    final double zoomFactor = baseMaxCents / maxCents;

    // Mapping functions with uniform zoom
    double centsToY(double cents) {
      // Map centerY to center of screen, and scale by zoomFactor
      return (size.height / 2) - (cents - centerY) * (size.height / baseMaxCents) * zoomFactor;
    }

    double timeToX(double t) {
      // Map centerX to center of screen, and scale by zoomFactor
      // We assume at zoomFactor=1.0, t=0..1 fills size.width
      return (size.width / 2) + (t - centerX) * size.width * zoomFactor;
    }

    // Draw Grid
    _drawGrid(canvas, size, targetCents, maxCents, zoomFactor, centsToY, timeToX);

    // Draw Target Curve
    _drawTargetCurve(canvas, size, targetCents, zoomFactor, centsToY, timeToX);

    // Draw User Path
    _drawUserPath(canvas, size, centsToY, timeToX);

    // Current position and dot logic
    final double t = isBending && userPath.isNotEmpty 
        ? userPath.last.dx 
        : 0;
    
    final double cents = isBending && userPath.isNotEmpty 
        ? userPath.last.dy 
        : (currentCents ?? 0);
        
    final double x = timeToX(t);
    final double y = centsToY(cents);
    
    final dotPaint = Paint()
      ..color = AppColors.primaryAccent
      ..style = PaintingStyle.fill;
      
    canvas.drawCircle(Offset(x, y), 8, dotPaint);
    
    // Glow effect
    canvas.drawCircle(
      Offset(x, y),
      12,
      Paint()..color = AppColors.primaryAccent.withValues(alpha: 0.3),
    );
  }

  void _drawGrid(
    Canvas canvas, 
    Size size, 
    double targetCents, 
    double maxCents, 
    double zoomFactor,
    double Function(double) centsToY, 
    double Function(double) timeToX
  ) {
    final linePaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1.0;
      
    final zeroPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5;

    // Determine range to draw
    final double centerY = targetCents / 2;
    final double halfRangeCents = maxCents / 2;
    final double startCents = ((centerY - halfRangeCents) / 50).floor() * 50.0;
    final double endCents = ((centerY + halfRangeCents) / 50).ceil() * 50.0;

    // Horizontal lines for every 50 cents
    for (double c = startCents; c <= endCents; c += 50) {
      final y = centsToY(c);
      if (y < -20 || y > size.height + 20) continue; // Small margin for labels
      
      canvas.drawLine(Offset(-10, y), Offset(size.width + 10, y), c.abs() < 1e-9 ? zeroPaint : linePaint);

      // Label for main intervals (100 cents)
      if (c % 100 == 0) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: c == 0 ? 'Ref' : '${(c / 100).toStringAsFixed(0)} step',
            style: TextStyle(
              color: c == 0 ? Colors.white54 : Colors.white24,
              fontSize: 10,
              fontWeight: c == 0 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(5, y - 12));
      }
    }

    // Vertical lines for timing
    // Visible time range is 1.0 / zoomFactor centered on 0.5
    final double visibleTimeHalfRange = 0.5 / zoomFactor;
    final double startTime = ((0.5 - visibleTimeHalfRange) / 0.25).floor() * 0.25;
    final double endTime = ((0.5 + visibleTimeHalfRange) / 0.25).ceil() * 0.25;

    for (double t = startTime; t <= endTime; t += 0.25) {
      final x = timeToX(t);
      if (x < -10 || x > size.width + 10) continue;
      canvas.drawLine(Offset(x, -10), Offset(x, size.height + 10), linePaint);
    }
  }

  void _drawTargetCurve(
    Canvas canvas, 
    Size size, 
    double targetCents, 
    double zoomFactor,
    double Function(double) centsToY, 
    double Function(double) timeToX
  ) {
    final paint = Paint()
      ..color = AppColors.inTuneColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    bool first = true;

    // Use finer steps if we are zoomed in, coarser if zoomed out
    final double step = 0.01 / (zoomFactor < 1 ? zoomFactor : 1.0);
    
    for (double t = 0; t <= 1.0001; t += step) {
      double cents = 0;
      if (curveShape == CurveShape.linear) {
        if (t < 0.5) {
          cents = targetCents * (t / 0.5);
        } else {
          cents = targetCents * (1 - (t - 0.5) / 0.5);
        }
      } else {
        cents = -4 * targetCents * pow(t - 0.5, 2) + targetCents;
      }

      final x = timeToX(t);
      final y = centsToY(cents);

      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawUserPath(
    Canvas canvas, 
    Size size, 
    double Function(double) centsToY, 
    double Function(double) timeToX
  ) {
    if (userPath.isEmpty) return;

    final paint = Paint()
      ..color = AppColors.standbyColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    bool first = true;

    for (final point in userPath) {
      final x = timeToX(point.dx);
      final y = centsToY(point.dy);

      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BendGraphPainter oldDelegate) {
    return true; // Always repaint for smooth real-time dot and path updates
  }
}
