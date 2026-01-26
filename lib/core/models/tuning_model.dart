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

  InstrumentString({required this.note, required this.octave}) {
    // Validate note name
    if (!NOTE_NAMES.contains(note)) {
      throw ArgumentError('Invalid note name: $note');
    }
    // Validate octave range (reasonable range for musical instruments)
    if (octave < 0 || octave > 9) {
      throw ArgumentError('Octave must be between 0 and 9, got: $octave');
    }
  }

  double get frequency => NoteUtils.getFrequency(note, octave);
  String get name => "$note$octave";

  /// Check if frequency is within reasonable range (20Hz - 20kHz)
  bool get isValidFrequency {
    final freq = frequency;
    return freq >= 20.0 && freq <= 20000.0;
  }

  InstrumentString copy() => InstrumentString(note: note, octave: octave);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstrumentString && note == other.note && octave == other.octave;

  @override
  int get hashCode => note.hashCode ^ octave.hashCode;

  // JSON Serialization
  Map<String, dynamic> toJson() => {'note': note, 'octave': octave};

  factory InstrumentString.fromJson(Map<String, dynamic> json) {
    final note = json['note'] as String? ?? 'A';
    final octave = json['octave'] as int? ?? 4;
    return InstrumentString(note: note, octave: octave);
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
  }) {
    // Validate at least one string
    if (strings.isEmpty) {
      throw ArgumentError('TuningPreset must have at least one string');
    }
    // Validate max strings (reasonable limit)
    if (strings.length > 12) {
      throw ArgumentError('TuningPreset cannot have more than 12 strings');
    }
    // Validate all strings have valid frequencies
    for (final s in strings) {
      if (!s.isValidFrequency) {
        throw ArgumentError('String ${s.name} has invalid frequency');
      }
    }
  }

  /// Check if all strings have valid frequencies
  bool get isValid => strings.every((s) => s.isValidFrequency);

  /// Get the lowest frequency in the preset
  double get lowestFrequency =>
      strings.map((s) => s.frequency).reduce((a, b) => a < b ? a : b);

  /// Get the highest frequency in the preset
  double get highestFrequency =>
      strings.map((s) => s.frequency).reduce((a, b) => a > b ? a : b);

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
