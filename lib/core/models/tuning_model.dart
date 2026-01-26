import 'dart:math';

// --- MATH UTILITIES ---
const List<String> NOTE_NAMES = [
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

/// Global tuning reference settings
class TuningSettings {
  /// A4 reference frequency in Hz (standard is 440Hz)
  /// Common alternatives: 432Hz ("Verdi tuning"), 442Hz, 443Hz (orchestral)
  static double a4Reference = 440.0;

  /// Set the A4 reference frequency (valid range: 420-460 Hz)
  static void setA4Reference(double freq) {
    if (freq >= 420.0 && freq <= 460.0) {
      a4Reference = freq;
    }
  }

  /// Reset to standard A4 = 440Hz
  static void resetA4Reference() {
    a4Reference = 440.0;
  }
}

class NoteUtils {
  static double getFrequency(String noteName, int octave) {
    int noteIndex = NOTE_NAMES.indexOf(noteName);
    if (noteIndex == -1) return 0.0;
    int midiNote = 12 + (octave * 12) + noteIndex;
    return TuningSettings.a4Reference * pow(2, (midiNote - 69) / 12);
  }

  static InstrumentString calculateNextLowerString(InstrumentString current) {
    int idx = NOTE_NAMES.indexOf(current.note);
    int newIdx = idx - 5;
    int newOct = current.octave;
    if (newIdx < 0) {
      newIdx += 12;
      newOct -= 1;
    }
    return InstrumentString(note: NOTE_NAMES[newIdx], octave: newOct);
  }
}

// --- DATA CLASSES ---

enum HeadstockStyle { oneWay, twoWay }

class InstrumentString {
  String note;
  int octave;

  InstrumentString({required this.note, required this.octave});

  double get frequency => NoteUtils.getFrequency(note, octave);
  String get name => "$note$octave";

  InstrumentString copy() => InstrumentString(note: note, octave: octave);

  // JSON Serialization
  Map<String, dynamic> toJson() => {'note': note, 'octave': octave};

  factory InstrumentString.fromJson(Map<String, dynamic> json) {
    return InstrumentString(note: json['note'], octave: json['octave']);
  }
}

class TuningPreset {
  String id;
  String name;
  HeadstockStyle style;
  List<InstrumentString> strings;

  TuningPreset({
    required this.id,
    required this.name,
    required this.style,
    required this.strings,
  });

  // Factory Presets
  static TuningPreset standard6String() => TuningPreset(
    id: "std_6",
    name: "Standard 6-String",
    style: HeadstockStyle.twoWay,
    strings: [
      InstrumentString(note: "E", octave: 2),
      InstrumentString(note: "A", octave: 2),
      InstrumentString(note: "D", octave: 3),
      InstrumentString(note: "G", octave: 3),
      InstrumentString(note: "B", octave: 3),
      InstrumentString(note: "E", octave: 4),
    ],
  );

  static TuningPreset standard7String() => TuningPreset(
    id: "std_7",
    name: "7-String Standard (B)",
    style: HeadstockStyle.twoWay,
    strings: [
      InstrumentString(note: "B", octave: 1),
      InstrumentString(note: "E", octave: 2),
      InstrumentString(note: "A", octave: 2),
      InstrumentString(note: "D", octave: 3),
      InstrumentString(note: "G", octave: 3),
      InstrumentString(note: "B", octave: 3),
      InstrumentString(note: "E", octave: 4),
    ],
  );

  TuningPreset copy() {
    return TuningPreset(
      id: id,
      name: name,
      style: style,
      strings: strings.map((s) => s.copy()).toList(),
    );
  }

  // JSON Serialization
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'style': style.index, // Save enum as int
    'strings': strings.map((s) => s.toJson()).toList(),
  };

  factory TuningPreset.fromJson(Map<String, dynamic> json) {
    return TuningPreset(
      id: json['id'],
      name: json['name'],
      style: HeadstockStyle.values[json['style']], // Restore enum from int
      strings: (json['strings'] as List)
          .map((item) => InstrumentString.fromJson(item))
          .toList(),
    );
  }
}
