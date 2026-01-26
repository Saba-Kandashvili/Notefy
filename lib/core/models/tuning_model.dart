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

  /// Calculate the next lower string, avoiding duplicates from existing strings.
  /// If we can't go lower, we go higher instead.
  static InstrumentString calculateNextLowerString(
    InstrumentString current, {
    List<InstrumentString>? existingStrings,
  }) {
    final existing = existingStrings ?? [];
    final existingNotes = existing.map((s) => '${s.note}${s.octave}').toSet();

    // Try going down by perfect 4th first
    int idx = NOTE_NAMES.indexOf(current.note);
    int newIdx = idx - 5;
    int newOct = current.octave;
    if (newIdx < 0) {
      newIdx += 12;
      newOct -= 1;
    }

    // If octave is valid and not a duplicate, use it
    if (newOct >= 0 &&
        !existingNotes.contains('${NOTE_NAMES[newIdx]}$newOct')) {
      return InstrumentString(note: NOTE_NAMES[newIdx], octave: newOct);
    }

    // Find the lowest existing note
    int lowestOctave = 9;
    int lowestNoteIdx = 11;
    for (final s in existing) {
      if (s.octave < lowestOctave ||
          (s.octave == lowestOctave &&
              NOTE_NAMES.indexOf(s.note) < lowestNoteIdx)) {
        lowestOctave = s.octave;
        lowestNoteIdx = NOTE_NAMES.indexOf(s.note);
      }
    }

    // Try each semitone going down from current lowest
    for (int semitone = 1; semitone <= 120; semitone++) {
      int tryIdx = lowestNoteIdx - semitone;
      int tryOct = lowestOctave;
      while (tryIdx < 0) {
        tryIdx += 12;
        tryOct -= 1;
      }
      if (tryOct >= 0) {
        final noteName = NOTE_NAMES[tryIdx % 12];
        if (!existingNotes.contains('$noteName$tryOct')) {
          return InstrumentString(note: noteName, octave: tryOct);
        }
      }
    }

    // If can't go lower, find highest and go up
    int highestOctave = 0;
    int highestNoteIdx = 0;
    for (final s in existing) {
      if (s.octave > highestOctave ||
          (s.octave == highestOctave &&
              NOTE_NAMES.indexOf(s.note) > highestNoteIdx)) {
        highestOctave = s.octave;
        highestNoteIdx = NOTE_NAMES.indexOf(s.note);
      }
    }

    // Try going up
    for (int semitone = 1; semitone <= 120; semitone++) {
      int tryIdx = highestNoteIdx + semitone;
      int tryOct = highestOctave;
      while (tryIdx >= 12) {
        tryIdx -= 12;
        tryOct += 1;
      }
      if (tryOct <= 9) {
        final noteName = NOTE_NAMES[tryIdx];
        if (!existingNotes.contains('$noteName$tryOct')) {
          return InstrumentString(note: noteName, octave: tryOct);
        }
      }
    }

    // Fallback (should never reach here with 120 notes range)
    return InstrumentString(note: 'A', octave: 4);
  }
}

// --- DATA CLASSES ---

/// @deprecated HeadstockStyle is no longer used - the UI auto-adapts to string count
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

  /// Check if frequency is within reasonable range (8Hz - 20kHz)
  /// 8Hz allows for sub-bass notes like C0 (~16Hz) with some margin
  bool get isValidFrequency {
    final freq = frequency;
    return freq >= 8.0 && freq <= 20000.0;
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
  @Deprecated('HeadstockStyle is no longer used - UI auto-adapts')
  HeadstockStyle style;
  List<InstrumentString> strings;

  TuningPreset({
    required this.id,
    required this.name,
    this.style = HeadstockStyle.twoWay, // Made optional with default
    required this.strings,
  }) {
    // Validate at least one string
    if (strings.isEmpty) {
      throw ArgumentError('TuningPreset must have at least one string');
    }
    // No upper limit - support any instrument (harpeji, harp, piano, etc.)
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
