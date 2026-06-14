import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/audio_generator.dart';
import '../../../tuner/presentation/tuner_controller.dart';

enum MatchStatus { waiting, correct, wrong }

class FretboardPracticeTab extends StatefulWidget {
  final TunerController controller;

  const FretboardPracticeTab({super.key, required this.controller});

  @override
  State<FretboardPracticeTab> createState() => _FretboardPracticeTabState();
}

class _FretboardPracticeTabState extends State<FretboardPracticeTab> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Standard guitar range: E2 (MIDI 40) to E6 (MIDI 88)
  final int minMidi = 40;
  final int maxMidi = 88;
  final List<String> noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
  
  int _targetMidi = 40;
  String get _targetNoteLabel {
    int octave = (_targetMidi ~/ 12) - 1;
    String note = noteNames[_targetMidi % 12];
    return "$note$octave";
  }

  MatchStatus _status = MatchStatus.waiting;
  String _detectedNoteLabel = "";
  
  bool _isPlaying = false;
  Timer? _advanceTimer;
  String? _notesDirPath;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onPitchDetected);
    _initAudio();
  }

  Future<void> _initAudio() async {
    _notesDirPath = await AudioGenerator.ensureNotesGenerated();
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _audioPlayer.dispose();
    widget.controller.removeListener(_onPitchDetected);
    if (widget.controller.isRecording) {
      widget.controller.stopCapture();
    }
    super.dispose();
  }

  void _onPitchDetected() {
    if (!_isPlaying || _status == MatchStatus.correct) return;
    
    final state = widget.controller.state;
    if (state.currentPitch <= 0 || state.confidence < 0.85) {
      if (_status != MatchStatus.waiting) {
        setState(() => _status = MatchStatus.waiting);
      }
      return;
    }

    final detectedLabel = "${state.note}${state.octave}";
    int noteIndex = noteNames.indexOf(state.note);
    if (noteIndex == -1) return;
    
    int detectedMidi = (state.octave + 1) * 12 + noteIndex;

    setState(() {
      _detectedNoteLabel = detectedLabel;
      
      // If within ~30 cents of the target note, it's correct
      if (detectedMidi == _targetMidi && state.cents.abs() < 30) {
        _status = MatchStatus.correct;
        _advanceTimer?.cancel();
        _advanceTimer = Timer(const Duration(milliseconds: 1500), () {
          _pickNextNote();
        });
      } else if (state.cents.abs() < 40) {
        // If it's a stable, clear wrong note, show red.
        _status = MatchStatus.wrong;
      }
    });
  }

  void _startPractice() {
    setState(() {
      _isPlaying = true;
    });
    if (!widget.controller.isRecording) {
      widget.controller.startCapture();
    }
    _pickNextNote();
  }

  void _stopPractice() {
    setState(() {
      _isPlaying = false;
      _status = MatchStatus.waiting;
      _detectedNoteLabel = "";
    });
    if (widget.controller.isRecording) {
      widget.controller.stopCapture();
    }
  }

  void _pickNextNote() {
    if (!mounted) return;
    
    final random = Random();
    setState(() {
      _targetMidi = minMidi + random.nextInt(maxMidi - minMidi + 1);
      _status = MatchStatus.waiting;
      _detectedNoteLabel = "";
    });
    
    _playTargetSound();
  }

  void _playTargetSound() {
    if (_notesDirPath == null) return;
    String filename = _targetNoteLabel.replaceAll('#', 's');
    _audioPlayer.play(DeviceFileSource('$_notesDirPath/$filename.wav'));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Fretboard Memorization",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            "Listen to the note and play it anywhere on the fretboard.",
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          
          if (_isPlaying) _buildGameCard() else _buildStartScreen(),
          
          const Spacer(),
          
          if (_isPlaying)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _playTargetSound,
                  icon: const Icon(Icons.volume_up, color: Colors.black),
                  label: const Text("Replay", style: TextStyle(color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _pickNextNote,
                  icon: const Icon(Icons.skip_next, color: Colors.black),
                  label: const Text("Skip", style: TextStyle(color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
          
          const SizedBox(height: 32),
          
          GestureDetector(
            onTap: _isPlaying ? _stopPractice : _startPractice,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              decoration: BoxDecoration(
                color: _isPlaying ? AppColors.errorAccent : AppColors.primaryAccent,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: (_isPlaying ? AppColors.errorAccent : AppColors.primaryAccent).withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                _isPlaying ? "STOP" : "START",
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartScreen() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: const Column(
        children: [
          Icon(Icons.music_note, size: 80, color: Colors.white24),
          SizedBox(height: 24),
          Text(
            "Press START to begin",
            style: TextStyle(color: Colors.white54, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard() {
    Color cardColor = AppColors.surfaceColor;
    Color shadowColor = Colors.transparent;
    
    if (_status == MatchStatus.correct) {
      cardColor = Colors.greenAccent.withValues(alpha: 0.2);
      shadowColor = Colors.greenAccent.withValues(alpha: 0.5);
    } else if (_status == MatchStatus.wrong) {
      cardColor = AppColors.errorAccent.withValues(alpha: 0.1);
      shadowColor = AppColors.errorAccent.withValues(alpha: 0.3);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _status == MatchStatus.correct 
              ? Colors.greenAccent 
              : (_status == MatchStatus.wrong ? AppColors.errorAccent : Colors.white10)
        ),
        boxShadow: [
          if (shadowColor != Colors.transparent)
            BoxShadow(
              color: shadowColor,
              blurRadius: 30,
              spreadRadius: 5,
            )
        ],
      ),
      child: Column(
        children: [
          const Text("PLAY", style: TextStyle(color: Colors.white54, letterSpacing: 2)),
          const SizedBox(height: 16),
          Text(
            _targetNoteLabel,
            style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _status == MatchStatus.waiting 
                  ? "Listening..." 
                  : "Heard: $_detectedNoteLabel",
              style: TextStyle(
                color: _status == MatchStatus.waiting ? Colors.white54 : Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
