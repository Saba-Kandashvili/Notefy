import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/services/audio_engine.dart';
import '../../../core/models/tuning_model.dart';

class NoteInfo {
  final String name;
  final int octave;
  final double perfectFrequency;
  NoteInfo(this.name, this.octave, this.perfectFrequency);
}

class GeneratorController extends ChangeNotifier {
  final AudioEngine _audioEngine;
  
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  double _frequency = 440.0;
  double get frequency => _frequency;

  int _waveform = 0; // 0: Sine, 1: Square, 2: Sawtooth, 3: Triangle
  int get waveform => _waveform;

  bool _isAdvancedMode = false;
  bool get isAdvancedMode => _isAdvancedMode;

  double _sweepStartFreq = 440.0;
  double get sweepStartFreq => _sweepStartFreq;

  double _sweepEndFreq = 880.0;
  double get sweepEndFreq => _sweepEndFreq;

  double _sweepDurationSec = 5.0;
  double get sweepDurationSec => _sweepDurationSec;

  bool _loopSweep = false;
  bool get loopSweep => _loopSweep;

  bool _isSweeping = false;
  bool get isSweeping => _isSweeping;

  double get currentSweepFrequency => _isSweeping ? _audioEngine.synthGetFrequency() : _frequency;

  GeneratorController({AudioEngine? audioEngine})
      : _audioEngine = audioEngine ?? AudioEngine();

  String get closestNote {
    final info = closestNoteInfo;
    return info != null ? "${info.name}${info.octave}" : "--";
  }

  NoteInfo? get closestNoteInfo {
    double freq = currentSweepFrequency;
    if (freq <= 0) return null;
    double semitonesFromA4 = 12 * log(freq / TuningSettings.a4Reference) / ln2;
    int midiNote = semitonesFromA4.round() + 69;
    if (midiNote < 0) return null;
    int octave = (midiNote / 12).floor() - 1;
    int noteIdx = midiNote % 12;
    
    int semitones = midiNote - 69;
    double perfectFreq = TuningSettings.a4Reference * pow(2.0, semitones / 12.0);
    
    return NoteInfo(NOTE_NAMES[noteIdx], octave, perfectFreq);
  }

  void togglePlay() {
    if (_isPlaying) {
      _audioEngine.synthStop();
      _isPlaying = false;
      if (_isSweeping) {
        _isSweeping = false;
        _audioEngine.synthStopSweep();
      }
      if (_isAdvancedMode) {
        _frequency = _sweepStartFreq;
      }
    } else {
      double startFreq = _isAdvancedMode ? _sweepStartFreq : _frequency;
      _isPlaying = _audioEngine.synthStart(waveform: _waveform, frequency: startFreq);
      _frequency = startFreq;
    }
    notifyListeners();
  }

  void setFrequency(double freq) {
    _frequency = freq.clamp(20.0, 20000.0);
    if (_isPlaying && !_isAdvancedMode) {
      _audioEngine.synthSetFrequency(_frequency);
    }
    notifyListeners();
  }

  void setWaveform(int type) {
    _waveform = type;
    if (_isPlaying) {
      _audioEngine.synthSetWaveform(_waveform);
    }
    notifyListeners();
  }

  void setAdvancedMode(bool advanced) {
    _isAdvancedMode = advanced;
    if (_isPlaying) {
      _audioEngine.synthStop();
      _isPlaying = false;
    }
    notifyListeners();
  }

  void setSweepStart(double freq) {
    _sweepStartFreq = freq.clamp(20.0, 20000.0);
    setFrequency(_sweepStartFreq);
  }

  void setSweepEnd(double freq) {
    _sweepEndFreq = freq.clamp(20.0, 20000.0);
    notifyListeners();
  }

  void setSweepDuration(double sec) {
    _sweepDurationSec = sec.clamp(0.1, 60.0);
    notifyListeners();
  }

  void setLoopSweep(bool loop) {
    _loopSweep = loop;
    _audioEngine.synthSetLoop(loop);
    
    // If turning loop ON while technically "sweeping" but the engine has finished and stopped at the end frequency,
    // we should instantly restart the sweep so the loop takes effect immediately.
    if (loop && _isSweeping) {
      double currentFreq = _audioEngine.synthGetFrequency();
      if ((currentFreq - _sweepEndFreq).abs() < 1.0) {
        _audioEngine.synthSetFrequency(_sweepStartFreq);
        _audioEngine.synthSweep(
          endFreq: _sweepEndFreq, 
          durationSec: _sweepDurationSec, 
          loop: true
        );
      }
    }
    
    notifyListeners();
  }

  void startSweep() {
    double startFrom = _frequency;
    
    // Restart from beginning if audio is stopped, or if we are already at the end frequency
    if (!_isPlaying || (_frequency - _sweepEndFreq).abs() < 1.0) {
      startFrom = _sweepStartFreq;
    }

    if (!_isPlaying) {
      _isPlaying = _audioEngine.synthStart(waveform: _waveform, frequency: startFrom);
    } else {
      _audioEngine.synthSetFrequency(startFrom);
    }
    _frequency = startFrom;
    _isSweeping = true;
    _audioEngine.synthSweep(
      endFreq: _sweepEndFreq, 
      durationSec: _sweepDurationSec, 
      loop: _loopSweep
    );
    notifyListeners();
  }

  void stopSweep() {
    double stoppedAtFreq = _audioEngine.synthGetFrequency();
    if (stoppedAtFreq > 0) {
      _frequency = stoppedAtFreq;
    }
    _isSweeping = false;
    _audioEngine.synthStopSweep();
    notifyListeners();
  }

  @override
  void dispose() {
    _audioEngine.synthStop();
    super.dispose();
  }
}
