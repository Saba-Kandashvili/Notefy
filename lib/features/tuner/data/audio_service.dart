import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
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
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioEngine _engine = AudioEngine();
  StreamSubscription<Uint8List>? _audioStreamSubscription;

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
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) return false;

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Audio init error: $e');
      return false;
    }
  }

  /// Get a list of available input devices (microphones)
  Future<List<InputDevice>> getAvailableMicrophones() async {
    if (!_isInitialized) return [];
    return await _audioRecorder.listInputDevices();
  }

  /// Helper to safely convert 16-bit PCM (Uint8List) to Float32List
  Float32List _convertToFloat32List(Uint8List pcm16Data) {
    final byteData = ByteData.view(pcm16Data.buffer, pcm16Data.offsetInBytes, pcm16Data.lengthInBytes);
    final floatList = Float32List(pcm16Data.lengthInBytes ~/ 2);
    // Use Endian.host because the record package outputs native PCM bytes
    for (int i = 0; i < floatList.length; i++) {
      floatList[i] = byteData.getInt16(i * 2, Endian.host) / 32768.0;
    }
    return floatList;
  }

  /// Start capturing audio and detecting pitch
  Future<bool> startCapture({
    required PitchCallback onPitchDetected,
    required VoidCallback onNoPitch,
    required ErrorCallback onError,
    void Function(Float32List data)? onRawData,
    InputDevice? selectedDevice,
  }) async {
    if (!_isInitialized) return false;
    
    // Stop any existing stream
    if (_isRecording) {
      await stopCapture();
    }

    try {
      final stream = await _audioRecorder.startStream(RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: AppConstants.sampleRate,
        numChannels: 1,
        device: selectedDevice,
        autoGain: true,        // Restored: boosts the decaying tail of a note for longer sustain
        echoCancel: false, 
        noiseSuppress: true,   // Restored: cuts background hiss that can confuse YIN
      ));

      Float32List floatBuffer = Float32List(AppConstants.bufferSize);
      int floatBufferIndex = 0;
      final int hopSize = AppConstants.bufferSize ~/ 2;

      _audioStreamSubscription = stream.listen(
        (Uint8List data) {
          try {
            final floatData = _convertToFloat32List(data);
            
            int offset = 0;
            while (offset < floatData.length) {
              final int remainingSpace = AppConstants.bufferSize - floatBufferIndex;
              int copyLength = floatData.length - offset;
              if (copyLength > remainingSpace) copyLength = remainingSpace;
              
              floatBuffer.setRange(floatBufferIndex, floatBufferIndex + copyLength, floatData, offset);
              floatBufferIndex += copyLength;
              offset += copyLength;
              
              if (floatBufferIndex >= AppConstants.bufferSize) {
                if (onRawData != null) {
                  onRawData(Float32List.fromList(floatBuffer));
                }

                final result = _engine.processAudioFloat32WithConfidence(floatBuffer);
                if (result.hasPitch &&
                    result.frequency > AppConstants.minDetectableFrequency &&
                    result.frequency < AppConstants.maxDetectableFrequency) {
                  onPitchDetected(result);
                } else {
                  onNoPitch();
                }
                
                // Reset index to 0. 
                // We previously used a 50% overlap, but this caused the UI's 
                // exponential moving average filter to converge twice as fast,
                // making the needle appear jittery. 0 overlap restores the old feel.
                floatBufferIndex = 0;
              }
            }
          } catch (e) {
            debugPrint('Audio processing error: $e');
            onNoPitch();
          }
        },
        onError: (e) => onError(e),
        cancelOnError: false,
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
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
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

  /// Track pitch for bends practice
  double trackBendPitch(Float32List audioData, double expectedFreq) {
    return _engine.trackBendPitch(audioData, expectedFreq);
  }

  /// Dispose of resources
  void dispose() {
    if (_isRecording) {
      stopCapture();
    }
    _audioRecorder.dispose();
    _engine.dispose();
  }
}
