import 'package:flutter/foundation.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/audio_engine.dart';

/// Callback for when pitch is detected
typedef PitchCallback = void Function(PitchResult result);

/// Callback for errors
typedef ErrorCallback = void Function(Object error);

/// Service responsible for audio capture and pitch detection
class AudioService {
  final FlutterAudioCapture _audioRecorder = FlutterAudioCapture();
  final AudioEngine _engine = AudioEngine();

  bool _isInitialized = false;
  bool _isRecording = false;

  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;

  /// Initialize audio capture (requests microphone permission)
  Future<bool> initialize() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      return false;
    }

    try {
      await _audioRecorder.init();
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Audio init error: $e');
      return false;
    }
  }

  /// Start capturing audio and detecting pitch
  Future<bool> startCapture({
    required PitchCallback onPitchDetected,
    required VoidCallback onNoPitch,
    required ErrorCallback onError,
    void Function(Float32List data)? onRawData,
  }) async {
    if (!_isInitialized) return false;

    try {
      await _audioRecorder.start(
        (Float32List data) {
          try {
            if (onRawData != null) onRawData(data);

            final result = _engine.processAudioFloat32WithConfidence(data);
            if (result.hasPitch &&
                result.frequency > AppConstants.minDetectableFrequency &&
                result.frequency < AppConstants.maxDetectableFrequency) {
              onPitchDetected(result);
            } else {
              onNoPitch();
            }
          } catch (e) {
            debugPrint('Audio processing error: $e');
            onNoPitch();
          }
        },
        (Object e) => onError(e),
        sampleRate: AppConstants.sampleRate,
        bufferSize: AppConstants.bufferSize,
      );

      WakelockPlus.enable();
      _isRecording = true;
      return true;
    } catch (e) {
      debugPrint('Start capture error: $e');
      return false;
    }
  }

  /// Stop capturing audio
  Future<void> stopCapture() async {
    try {
      await _audioRecorder.stop();
    } catch (e) {
      // Ignore stop errors
    }
    WakelockPlus.disable();
    _isRecording = false;
  }

  /// Detect inharmonicity coefficient B for a given expected fundamental frequency
  double detectInharmonicity(Float32List data, double expectedF1) {
    return _engine.detectInharmonicity(data, expectedF1);
  }

  /// Set the tuning mode (affects noise gate sensitivity)
  void setTuningMode(TuningModeNative mode) {
    _engine.setTuningMode(mode);
  }

  /// Set custom frequency range for detection
  void setFrequencyRange(double minFreq, double maxFreq) {
    _engine.setFrequencyRange(minFreq, maxFreq);
  }

  /// Reset frequency range to defaults
  void resetFrequencyRange() {
    _engine.resetFrequencyRange();
  }

  /// Dispose of resources
  void dispose() {
    if (_isRecording) {
      stopCapture();
    }
    _engine.dispose();
  }
}
