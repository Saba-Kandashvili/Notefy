import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart'; // Helper for allocating memory

typedef NativeDetectPitch = ffi.Float Function(ffi.Pointer<ffi.Float>, ffi.Int32, ffi.Int32);
typedef DartDetectPitch = double Function(ffi.Pointer<ffi.Float>, int, int);

class AudioEngine {
  late ffi.DynamicLibrary _lib;
  late DartDetectPitch _detectPitch;

  AudioEngine() {
    if (Platform.isAndroid) {
      _lib = ffi.DynamicLibrary.open("libnative_tuner.so");
    } else {
      _lib = ffi.DynamicLibrary.process();
    }

    _detectPitch = _lib
        .lookup<ffi.NativeFunction<NativeDetectPitch>>('detect_pitch')
        .asFunction();
  }

  double processAudio(List<double> audioData) {
    if (audioData.isEmpty) return -1.0;

    // 1. Allocate C memory
    final pointer = calloc<ffi.Float>(audioData.length);

    // 2. Copy Dart data to C memory
    // (This loop is the bottleneck, we can optimize later with Float32List)
    for (var i = 0; i < audioData.length; i++) {
      pointer[i] = audioData[i];
    }

    // 3. Call C++
    final result = _detectPitch(pointer, audioData.length, 44100);

    // 4. Free memory
    calloc.free(pointer);

    return result;
  }
}