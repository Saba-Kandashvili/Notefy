import 'dart:math';

import '../../../core/models/tuning_model.dart';

/// Represents a piano key with all its properties
class PianoKey {
  final String name;
  final int octave;
  final double frequency;
  final int keyNumber;
  final bool isBlack;

  const PianoKey(
    this.name,
    this.octave,
    this.frequency,
    this.keyNumber,
    this.isBlack,
  );

  String get fullName => "$name$octave";
}

/// Generates all 88 piano keys with their frequencies
class PianoKeyGenerator {
  static const _noteNames = [
    "C",
    "C#",
    "D",
    "D#",
    "E",
    "F",
    "F#",
    "G",
    "G#",
    "A",
    "A#",
    "B",
  ];

  static const _blackKeyPattern = [
    false,
    true,
    false,
    true,
    false,
    false,
    true,
    false,
    true,
    false,
    true,
    false,
  ];

  /// Generate all 88 piano keys
  static List<PianoKey> generate() {
    List<PianoKey> keys = [];
    int keyNumber = 1;

    // A0, A#0, B0 (keys 1-3)
    for (int i = 9; i < 12; i++) {
      int midiNote = 21 + (i - 9);
      double freq = TuningSettings.a4Reference * pow(2, (midiNote - 69) / 12);
      keys.add(
        PianoKey(_noteNames[i], 0, freq, keyNumber++, _blackKeyPattern[i]),
      );
    }

    // Octaves 1-7 (keys 4-87)
    for (int octave = 1; octave <= 7; octave++) {
      for (int i = 0; i < 12; i++) {
        int midiNote = 12 + (octave * 12) + i;
        double freq = TuningSettings.a4Reference * pow(2, (midiNote - 69) / 12);
        keys.add(
          PianoKey(
            _noteNames[i],
            octave,
            freq,
            keyNumber++,
            _blackKeyPattern[i],
          ),
        );
      }
    }

    // C8 (key 88)
    double freqC8 = TuningSettings.a4Reference * pow(2, (108 - 69) / 12);
    keys.add(PianoKey("C", 8, freqC8, keyNumber, false));

    return keys;
  }

  /// Get the index of the white key before a given black key
  static int getWhiteKeyIndexBeforeBlackKey(
    PianoKey blackKey,
    List<PianoKey> allKeys,
  ) {
    final whiteKeys = allKeys.where((k) => !k.isBlack).toList();
    for (int i = 0; i < whiteKeys.length; i++) {
      final wk = whiteKeys[i];
      if (wk.octave == blackKey.octave) {
        if ((blackKey.name == "C#" && wk.name == "C") ||
            (blackKey.name == "D#" && wk.name == "D") ||
            (blackKey.name == "F#" && wk.name == "F") ||
            (blackKey.name == "G#" && wk.name == "G") ||
            (blackKey.name == "A#" && wk.name == "A")) {
          return i;
        }
      }
      if (blackKey.octave == 0 &&
          blackKey.name == "A#" &&
          wk.octave == 0 &&
          wk.name == "A") {
        return i;
      }
    }
    return 0;
  }
}

/// Singleton list of all piano keys
final List<PianoKey> pianoKeys = PianoKeyGenerator.generate();
