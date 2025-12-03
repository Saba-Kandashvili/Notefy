import 'dart:ffi' as ffi;
import 'dart:io';

// 1. Define the C function signature
// Returns Float, takes Pointer<Float>, Int, Int
typedef NativeDetectPitch =
    ffi.Float Function(
      ffi.Pointer<ffi.Float> audioData,
      ffi.Int32 length,
      ffi.Int32 sampleRate,
    );

// 2. Define the Dart function signature
typedef DartDetectPitch =
    double Function(
      ffi.Pointer<ffi.Float> audioData,
      int length,
      int sampleRate,
    );

class AudioEngine {
  late ffi.DynamicLibrary _lib;
  late DartDetectPitch _detectPitch;

  AudioEngine() {
    // 3. Load the library
    // On Android, the file is named "lib" + [project_name] + ".so"
    if (Platform.isAndroid) {
      _lib = ffi.DynamicLibrary.open("libnative_tuner.so");
    } else {
      // Setup for iOS/Mac/Windows later
      _lib = ffi.DynamicLibrary.process();
    }

    // 4. Look up the function
    _detectPitch = _lib
        .lookup<ffi.NativeFunction<NativeDetectPitch>>('detect_pitch')
        .asFunction();
  }

  // Wrapper to make it easy to call
  double getPitch(double dummyData) {
    // In the real app, you will pass a pointer to your audio buffer here.
    // For this test, we pass a null pointer just to see if the function runs.
    return _detectPitch(ffi.nullptr, 1024, 44100);
  }
}
