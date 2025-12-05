import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// ============================================================================
// FFI Type Definitions for YIN Pitch Detection
// ============================================================================

// Standard pitch detection (returns frequency in Hz, or -1 if no pitch)
typedef NativeDetectPitch =
    ffi.Float Function(ffi.Pointer<ffi.Float>, ffi.Int32, ffi.Int32);
typedef DartDetectPitch = double Function(ffi.Pointer<ffi.Float>, int, int);

// Pitch detection with confidence output
typedef NativeDetectPitchWithConfidence =
    ffi.Float Function(
      ffi.Pointer<ffi.Float>,
      ffi.Int32,
      ffi.Int32,
      ffi.Pointer<ffi.Float>,
    );
typedef DartDetectPitchWithConfidence =
    double Function(ffi.Pointer<ffi.Float>, int, int, ffi.Pointer<ffi.Float>);

// Cleanup function
typedef NativeCleanup = ffi.Void Function();
typedef DartCleanup = void Function();

// ============================================================================
// Pitch Detection Result
// ============================================================================

class PitchResult {
  final double frequency; // Frequency in Hz (-1 if no pitch detected)
  final double confidence; // Confidence level 0.0 to 1.0

  const PitchResult(this.frequency, this.confidence);

  bool get hasPitch => frequency > 0;

  @override
  String toString() =>
      'PitchResult(freq: ${frequency.toStringAsFixed(2)} Hz, conf: ${(confidence * 100).toStringAsFixed(1)}%)';
}

// ============================================================================
// Audio Engine - YIN Pitch Detection
// ============================================================================

class AudioEngine {
  late ffi.DynamicLibrary _lib;
  late DartDetectPitch _detectPitch;
  late DartDetectPitchWithConfidence _detectPitchWithConfidence;
  DartCleanup? _cleanup;

  // Reusable buffer for audio data (avoids allocation every frame)
  ffi.Pointer<ffi.Float>? _audioBuffer;
  int _audioBufferSize = 0;

  // Reusable buffer for confidence output
  ffi.Pointer<ffi.Float>? _confidencePtr;

  // Default sample rate (can be overridden)
  int sampleRate = 44100;

  AudioEngine() {
    _loadLibrary();
  }

  void _loadLibrary() {
    if (Platform.isAndroid) {
      _lib = ffi.DynamicLibrary.open("libnative_tuner.so");
    } else if (Platform.isIOS) {
      _lib = ffi.DynamicLibrary.process();
    } else if (Platform.isMacOS) {
      _lib = ffi.DynamicLibrary.process();
    } else if (Platform.isWindows) {
      _lib = ffi.DynamicLibrary.open("native_tuner.dll");
    } else if (Platform.isLinux) {
      _lib = ffi.DynamicLibrary.open("libnative_tuner.so");
    } else {
      _lib = ffi.DynamicLibrary.process();
    }

    // Load the main pitch detection function
    _detectPitch = _lib
        .lookup<ffi.NativeFunction<NativeDetectPitch>>('detect_pitch')
        .asFunction();

    // Load the pitch detection with confidence function
    _detectPitchWithConfidence = _lib
        .lookup<ffi.NativeFunction<NativeDetectPitchWithConfidence>>(
          'detect_pitch_with_confidence',
        )
        .asFunction();

    // Try to load cleanup function (optional)
    try {
      _cleanup = _lib
          .lookup<ffi.NativeFunction<NativeCleanup>>('cleanup_pitch_detector')
          .asFunction();
    } catch (e) {
      _cleanup = null;
    }

    // Pre-allocate confidence pointer
    _confidencePtr = calloc<ffi.Float>(1);
  }

  /// Process audio data and return detected pitch frequency.
  /// Returns -1.0 if no pitch is detected.
  double processAudio(List<double> audioData) {
    if (audioData.isEmpty) return -1.0;

    // Ensure buffer is large enough
    _ensureBufferSize(audioData.length);

    // Copy data to native buffer
    _copyToNativeBuffer(audioData);

    // Call the YIN pitch detection
    final result = _detectPitch(_audioBuffer!, audioData.length, sampleRate);

    return result;
  }

  /// Process audio data and return pitch with confidence level.
  /// This is preferred for UI feedback as it shows detection reliability.
  PitchResult processAudioWithConfidence(List<double> audioData) {
    if (audioData.isEmpty) return const PitchResult(-1.0, 0.0);

    // Ensure buffer is large enough
    _ensureBufferSize(audioData.length);

    // Copy data to native buffer
    _copyToNativeBuffer(audioData);

    // Reset confidence
    _confidencePtr![0] = 0.0;

    // Call the YIN pitch detection with confidence
    final frequency = _detectPitchWithConfidence(
      _audioBuffer!,
      audioData.length,
      sampleRate,
      _confidencePtr!,
    );

    final confidence = _confidencePtr![0];

    return PitchResult(frequency, confidence);
  }

  /// Optimized version that takes Float32List directly (avoids conversion)
  double processAudioFloat32(Float32List audioData) {
    if (audioData.isEmpty) return -1.0;

    _ensureBufferSize(audioData.length);

    // Direct copy from Float32List is faster
    for (var i = 0; i < audioData.length; i++) {
      _audioBuffer![i] = audioData[i];
    }

    return _detectPitch(_audioBuffer!, audioData.length, sampleRate);
  }

  /// Optimized version with confidence that takes Float32List directly
  PitchResult processAudioFloat32WithConfidence(Float32List audioData) {
    if (audioData.isEmpty) return const PitchResult(-1.0, 0.0);

    _ensureBufferSize(audioData.length);

    for (var i = 0; i < audioData.length; i++) {
      _audioBuffer![i] = audioData[i];
    }

    _confidencePtr![0] = 0.0;

    final frequency = _detectPitchWithConfidence(
      _audioBuffer!,
      audioData.length,
      sampleRate,
      _confidencePtr!,
    );

    return PitchResult(frequency, _confidencePtr![0]);
  }

  void _ensureBufferSize(int requiredSize) {
    if (_audioBuffer == null || _audioBufferSize < requiredSize) {
      // Free old buffer if exists
      if (_audioBuffer != null) {
        calloc.free(_audioBuffer!);
      }
      // Allocate new buffer with some extra space to avoid frequent reallocations
      _audioBufferSize = (requiredSize * 1.5).toInt();
      _audioBuffer = calloc<ffi.Float>(_audioBufferSize);
    }
  }

  void _copyToNativeBuffer(List<double> audioData) {
    for (var i = 0; i < audioData.length; i++) {
      _audioBuffer![i] = audioData[i];
    }
  }

  /// Release native resources
  void dispose() {
    // Call native cleanup if available
    _cleanup?.call();

    // Free allocated memory
    if (_audioBuffer != null) {
      calloc.free(_audioBuffer!);
      _audioBuffer = null;
    }
    if (_confidencePtr != null) {
      calloc.free(_confidencePtr!);
      _confidencePtr = null;
    }
  }
}
