import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'audio_engine.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
      ),
      home: TunerScreen(),
    );
  }
}

class TunerScreen extends StatefulWidget {
  @override
  _TunerScreenState createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> with SingleTickerProviderStateMixin {
  final _audioRecorder = FlutterAudioCapture();
  final _engine = AudioEngine();
  
  double _currentPitch = 0.0;
  String _note = "--";
  int _octave = 0;
  double _cents = 0.0;
  String _status = "Tap to Start";
  bool _isRecording = false;
  
  // For smooth needle animation
  late AnimationController _needleController;
  double _targetNeedleAngle = 0.0;
  double _currentNeedleAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _initAudio();
    _needleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..addListener(() {
      setState(() {
        _currentNeedleAngle = _currentNeedleAngle + 
          (_targetNeedleAngle - _currentNeedleAngle) * _needleController.value;
      });
    });
  }

  Future<void> _initAudio() async {
    // Request permission first
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      // Initialize the audio capture plugin
      await _audioRecorder.init();
      setState(() {
        _status = "Tap to Start";
      });
    } else {
      setState(() {
        _status = "Microphone permission denied";
      });
    }
  }

  @override
  void dispose() {
    _needleController.dispose();
    if (_isRecording) {
      _audioRecorder.stop();
    }
    super.dispose();
  }

  Future<void> _startCapture() async {
    try {
      await _audioRecorder.start(
        (data) {
          // data is a Float32List (raw audio)
          List<double> buffer = data.map((e) => e.toDouble()).toList();
          
          // Pass to C++ Engine
          double pitch = _engine.processAudio(buffer);

          if (pitch > 20 && pitch < 5000) {
            _calculateNote(pitch);
          }
        }, 
        onError, 
        sampleRate: 44100, 
        bufferSize: 4096
      );
      setState(() {
        _isRecording = true;
        _status = "Listening...";
      });
    } catch (e) {
      setState(() {
        _status = "Error: $e";
      });
    }
  }
  
  void onError(Object e) {
    print(e);
    setState(() {
      _status = "Error: $e";
    });
  }

  Future<void> _stopCapture() async {
    await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _status = "Paused";
      _note = "--";
      _currentPitch = 0.0;
      _cents = 0.0;
      _targetNeedleAngle = 0.0;
    });
  }

  void _calculateNote(double freq) {
    if (freq <= 0) return;

    // MIDI Note number formula: Note = 12 * log2(f/440) + 69
    double midi = 12 * (log(freq / 440.0) / log(2)) + 69;
    int midiRounded = midi.round();
    
    // Calculate cents (how far off from the exact note)
    // 100 cents = 1 semitone
    double cents = (midi - midiRounded) * 100;

    const List<String> notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
    
    int octave = (midiRounded / 12).floor() - 1;
    int noteIndex = midiRounded % 12;
    String noteName = notes[noteIndex];

    // Update needle angle based on cents (-50 to +50 cents -> -45 to +45 degrees)
    double targetAngle = (cents / 50) * 45 * (pi / 180);
    
    if (mounted) {
      setState(() {
        _currentPitch = freq;
        _note = noteName;
        _octave = octave;
        _cents = cents;
        _targetNeedleAngle = targetAngle;
      });
      
      _needleController.forward(from: 0);
    }
  }

  Color _getTuningColor() {
    double absCents = _cents.abs();
    if (absCents < 5) return Colors.greenAccent;
    if (absCents < 15) return Colors.yellowAccent;
    return Colors.redAccent;
  }

  String _getTuningStatus() {
    if (!_isRecording || _note == "--") return "";
    double absCents = _cents.abs();
    if (absCents < 5) return "In Tune ✓";
    if (_cents > 0) return "Sharp ↑";
    return "Flat ↓";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Note Display
            _buildNoteDisplay(),
            const SizedBox(height: 20),
            // Tuning Meter
            _buildTuningMeter(),
            const SizedBox(height: 20),
            // Cents Display
            _buildCentsDisplay(),
            const SizedBox(height: 20),
            // Frequency Display
            _buildFrequencyDisplay(),
            const Spacer(),
            // Status and Controls
            _buildControls(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteDisplay() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _note,
              style: TextStyle(
                fontSize: 120,
                fontWeight: FontWeight.bold,
                color: _isRecording && _note != "--" ? _getTuningColor() : Colors.white54,
              ),
            ),
            if (_note != "--")
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  "$_octave",
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: _isRecording ? _getTuningColor() : Colors.white54,
                  ),
                ),
              ),
          ],
        ),
        Text(
          _getTuningStatus(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: _getTuningColor(),
          ),
        ),
      ],
    );
  }

  Widget _buildTuningMeter() {
    return SizedBox(
      height: 150,
      width: double.infinity,
      child: CustomPaint(
        painter: TuningMeterPainter(
          needleAngle: _currentNeedleAngle,
          tuningColor: _isRecording && _note != "--" ? _getTuningColor() : Colors.white38,
          isActive: _isRecording && _note != "--",
        ),
      ),
    );
  }

  Widget _buildCentsDisplay() {
    String centsText = _cents >= 0 ? "+${_cents.toStringAsFixed(1)}" : _cents.toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _isRecording && _note != "--" ? "$centsText cents" : "-- cents",
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w500,
          color: _isRecording && _note != "--" ? _getTuningColor() : Colors.white38,
        ),
      ),
    );
  }

  Widget _buildFrequencyDisplay() {
    return Text(
      _isRecording && _currentPitch > 0 
        ? "${_currentPitch.toStringAsFixed(1)} Hz" 
        : "-- Hz",
      style: const TextStyle(
        fontSize: 20,
        color: Colors.white54,
      ),
    );
  }

  Widget _buildControls() {
    return Column(
      children: [
        Text(
          _status,
          style: const TextStyle(fontSize: 16, color: Colors.white54),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _isRecording ? _stopCapture : _startCapture,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isRecording ? Colors.red : Colors.greenAccent,
              boxShadow: [
                BoxShadow(
                  color: (_isRecording ? Colors.red : Colors.greenAccent).withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              _isRecording ? Icons.stop : Icons.mic,
              size: 40,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}

// Custom painter for the tuning meter arc
class TuningMeterPainter extends CustomPainter {
  final double needleAngle;
  final Color tuningColor;
  final bool isActive;

  TuningMeterPainter({
    required this.needleAngle,
    required this.tuningColor,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.height - 20;

    // Draw the arc background
    final arcPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi + 0.3,
      pi - 0.6,
      false,
      arcPaint,
    );

    // Draw tick marks
    final tickPaint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 2;

    for (int i = -5; i <= 5; i++) {
      final angle = pi + (pi / 2) + (i * pi / 12);
      final innerRadius = i == 0 ? radius - 25 : radius - 15;
      final outerRadius = radius + 5;
      
      final start = Offset(
        center.dx + innerRadius * cos(angle),
        center.dy + innerRadius * sin(angle),
      );
      final end = Offset(
        center.dx + outerRadius * cos(angle),
        center.dy + outerRadius * sin(angle),
      );
      
      tickPaint.color = i == 0 ? Colors.greenAccent : Colors.white38;
      tickPaint.strokeWidth = i == 0 ? 3 : 2;
      canvas.drawLine(start, end, tickPaint);
    }

    // Draw the center green zone
    final greenZonePaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2 - 0.1,
      0.2,
      false,
      greenZonePaint,
    );

    // Draw the needle
    if (isActive) {
      final needlePaint = Paint()
        ..color = tuningColor
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      final needleEnd = Offset(
        center.dx + (radius - 10) * cos(-pi / 2 + needleAngle),
        center.dy + (radius - 10) * sin(-pi / 2 + needleAngle),
      );

      canvas.drawLine(center, needleEnd, needlePaint);

      // Draw needle center dot
      final dotPaint = Paint()
        ..color = tuningColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 8, dotPaint);
    }
  }

  @override
  bool shouldRepaint(TuningMeterPainter oldDelegate) {
    return oldDelegate.needleAngle != needleAngle ||
        oldDelegate.tuningColor != tuningColor ||
        oldDelegate.isActive != isActive;
  }
}