import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/tuning_model.dart';
import '../../../core/services/audio_engine.dart';
import '../../piano/domain/piano_key.dart';
import '../data/audio_service.dart';
import '../data/tuner_repository.dart';
import '../domain/tuner_state.dart';
import '../domain/tuning_mode.dart';

/// Controller that manages tuner state and business logic
class TunerController extends ChangeNotifier {
  final AudioService _audioService = AudioService();
  final TunerRepository _repository = TunerRepository();

  // State
  TunerState _state = TunerState.initial;
  TuningMode _tuningMode = TuningMode.chromatic;

  // Trail data for seismograph
  final List<double> _trailPositions = [];
  double _displayedCents = 0.0;
  double _targetCents = 0.0;
  double _scrollOffset = 0.0;

  // Guitar state
  TuningPreset _currentPreset = TuningPreset.standard6String();
  InstrumentString? _targetString;
  List<TuningPreset> _customPresets = [];

  // Piano state
  PianoKey? _selectedPianoKey;

  // Standby state
  bool _isInStandby = false;
  Timer? _standbyTimer;
  double _standbyProgress = 0.0;

  // Haptic feedback state
  bool _wasInTune = false;
  static const double _inTuneThreshold = 5.0; // cents

  // Animation controllers (will be set by view)
  AnimationController? _standbyAnimationController;
  AnimationController? _scrollAnimationController;

  // Getters
  TunerState get state => _state;
  TuningMode get tuningMode => _tuningMode;
  List<double> get trailPositions => _trailPositions;
  double get displayedCents => _displayedCents;
  double get scrollOffset => _scrollOffset;
  bool get isInStandby => _isInStandby;
  double get standbyProgress => _standbyProgress;

  TuningPreset get currentPreset => _currentPreset;
  InstrumentString? get targetString => _targetString;
  List<TuningPreset> get customPresets => _customPresets;
  PianoKey? get selectedPianoKey => _selectedPianoKey;

  bool get isInitialized => _audioService.isInitialized;
  bool get isRecording => _audioService.isRecording;

  /// Initialize the controller
  Future<void> initialize() async {
    final success = await _audioService.initialize();
    _state = _state.copyWith(
      isInitialized: success,
      status: success ? "Tap to Start" : "Microphone permission denied",
    );
    await _loadSavedState();
    notifyListeners();
  }

  /// Set animation controllers from the view
  void setAnimationControllers({
    required AnimationController standbyController,
    required AnimationController scrollController,
  }) {
    _standbyAnimationController = standbyController;
    _scrollAnimationController = scrollController;

    _standbyAnimationController?.addListener(() {
      _standbyProgress = _standbyAnimationController?.value ?? 0.0;
      notifyListeners();
    });

    _scrollAnimationController?.addListener(_onScrollTick);
  }

  void _onScrollTick() {
    _scrollOffset += AppConstants.scrollSpeed;
    _updateDisplayedCents();
    _addTrailPoint();
    notifyListeners();
  }

  Future<void> _loadSavedState() async {
    _tuningMode = await _repository.loadTuningMode();
    _currentPreset =
        await _repository.loadGuitarPreset() ?? TuningPreset.standard6String();
    _customPresets = await _repository.loadCustomPresets();
  }

  Future<void> _saveState() async {
    await _repository.saveTuningMode(_tuningMode);
    await _repository.saveGuitarPreset(_currentPreset);
    await _repository.saveCustomPresets(_customPresets);
  }

  /// Start recording
  Future<void> startCapture() async {
    if (!_audioService.isInitialized) return;

    _trailPositions.clear();
    _resetStandby();

    final success = await _audioService.startCapture(
      onPitchDetected: _onPitchDetected,
      onNoPitch: _onNoPitchDetected,
      onError: _onError,
    );

    if (success) {
      _scrollAnimationController?.repeat();
      _state = _state.listening();
      notifyListeners();
    }
  }

  /// Stop recording
  Future<void> stopCapture() async {
    await _audioService.stopCapture();
    _scrollAnimationController?.stop();
    _standbyTimer?.cancel();
    _resetStandby();
    _state = _state.paused();
    notifyListeners();
  }

  void _onPitchDetected(double pitch) {
    _standbyTimer?.cancel();
    if (_isInStandby) {
      _isInStandby = false;
      _standbyAnimationController?.reset();
    }
    _calculateNote(pitch);
  }

  void _onNoPitchDetected() {
    if (_standbyTimer == null || !_standbyTimer!.isActive) {
      if (!_isInStandby && _state.note != "--") {
        _standbyTimer = Timer(
          const Duration(milliseconds: AppConstants.standbyDelayMs),
          _enterStandby,
        );
      }
    }
  }

  void _onError(Object error) {
    _state = _state.copyWith(status: "Error: $error");
    notifyListeners();
  }

  void _enterStandby() {
    _isInStandby = true;
    _standbyAnimationController?.forward();
    notifyListeners();
  }

  void _resetStandby() {
    _standbyTimer?.cancel();
    _isInStandby = false;
    _standbyAnimationController?.reset();
    _standbyProgress = 0.0;
  }

  void _calculateNote(double freq) {
    if (freq <= 0) return;

    double midi = 12 * (log(freq / TuningSettings.a4Reference) / log(2)) + 69;
    int midiRounded = midi.round();
    double cents = (midi - midiRounded) * 100;

    int octave = (midiRounded / 12).floor() - 1;
    int noteIndex = midiRounded % 12;
    String noteName = NOTE_NAMES[noteIndex];

    // Guitar Target Logic
    if (_tuningMode == TuningMode.guitar && _targetString != null) {
      double targetFreq = _targetString!.frequency;
      double rawCents = 1200 * (log(freq / targetFreq) / log(2));
      cents = rawCents.clamp(-100.0, 100.0);
      if (rawCents.abs() <= 200) {
        noteName = _targetString!.note;
        octave = _targetString!.octave;
      }
    }

    // Piano Target Logic
    if (_tuningMode == TuningMode.piano && _selectedPianoKey != null) {
      double targetFreq = _selectedPianoKey!.frequency;
      double rawCents = 1200 * (log(freq / targetFreq) / log(2));
      cents = rawCents.clamp(-100.0, 100.0);
      if (rawCents.abs() <= 200) {
        noteName = _selectedPianoKey!.name;
        octave = _selectedPianoKey!.octave;
      }
    }

    _targetCents = cents;

    // Haptic feedback when entering "in tune" zone (only when target note selected)
    final bool hasTarget =
        (_tuningMode == TuningMode.guitar && _targetString != null) ||
        (_tuningMode == TuningMode.piano && _selectedPianoKey != null);
    final bool isInTune = cents.abs() < _inTuneThreshold;
    if (hasTarget && isInTune && !_wasInTune) {
      HapticFeedback.mediumImpact();
    }
    _wasInTune = isInTune;

    _state = _state.copyWith(
      currentPitch: freq,
      note: noteName,
      octave: octave,
      cents: cents,
    );
    notifyListeners();
  }

  void _updateDisplayedCents() {
    if (_isInStandby) {
      _displayedCents = _displayedCents * (1 - AppConstants.centsLerpSpeed);
      if (_displayedCents.abs() < 0.1) _displayedCents = 0.0;
    } else {
      _displayedCents =
          _displayedCents +
          (_targetCents - _displayedCents) * AppConstants.centsLerpSpeed;
    }
  }

  void _addTrailPoint() {
    if (_audioService.isRecording) {
      _trailPositions.insert(0, _displayedCents);
      while (_trailPositions.length > AppConstants.maxTrailPoints) {
        _trailPositions.removeLast();
      }
    }
  }

  /// Set tuning mode
  Future<void> setTuningMode(TuningMode mode) async {
    _tuningMode = mode;
    _targetString = null;
    _selectedPianoKey = null;
    _trailPositions.clear();

    // Update native engine mode
    switch (mode) {
      case TuningMode.guitar:
        _audioService.setTuningMode(TuningModeNative.guitar);
        break;
      case TuningMode.piano:
        _audioService.setTuningMode(TuningModeNative.piano);
        break;
      case TuningMode.chromatic:
        _audioService.setTuningMode(TuningModeNative.chromatic);
        break;
    }

    await _saveState();
    notifyListeners();
  }

  /// Select a guitar string to tune
  void selectString(InstrumentString? string) {
    _targetString = string;
    _trailPositions.clear();
    if (string != null &&
        !_audioService.isRecording &&
        _audioService.isInitialized) {
      startCapture();
    }
    notifyListeners();
  }

  /// Select a piano key to tune
  void selectPianoKey(PianoKey? key) {
    _selectedPianoKey = key;
    _trailPositions.clear();
    if (key != null) {
      _audioService.setFrequencyRange(key.frequency * 0.7, key.frequency * 1.5);
      if (!_audioService.isRecording && _audioService.isInitialized) {
        startCapture();
      }
    }
    notifyListeners();
  }

  /// Set current preset
  void setPreset(TuningPreset preset) {
    _currentPreset = preset;
    _targetString = null;
    _trailPositions.clear();
    _saveState();
    notifyListeners();
  }

  /// Add a new custom preset
  void addCustomPreset(TuningPreset preset) {
    _customPresets.add(preset);
    _currentPreset = preset;
    _saveState();
    notifyListeners();
  }

  /// Update an existing preset
  void updatePreset(TuningPreset preset) {
    final index = _customPresets.indexWhere((p) => p.id == preset.id);
    if (index != -1) {
      _customPresets[index] = preset;
    }
    _currentPreset = preset;
    _targetString = null;
    _trailPositions.clear();
    _saveState();
    notifyListeners();
  }

  /// Delete a custom preset
  void deletePreset(TuningPreset preset) {
    _customPresets.removeWhere((p) => p.id == preset.id);
    if (_currentPreset.id == preset.id) {
      _currentPreset = TuningPreset.standard6String();
    }
    _saveState();
    notifyListeners();
  }

  @override
  void dispose() {
    _standbyTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}
