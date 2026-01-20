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

class NoteUtils {
  // Get frequency from Note and Octave (e.g., "A", 4 -> 440.0)
  static double getFrequency(String noteName, int octave) {
    int noteIndex = NOTE_NAMES.indexOf(noteName);
    if (noteIndex == -1) return 0.0;
    int midiNote = 12 + (octave * 12) + noteIndex;
    return 440.0 * pow(2, (midiNote - 69) / 12);
  }

  // Calculate the next string down by a Perfect 4th (5 semitones)
  // Renamed from 'nextLowerString' for clarity
  static InstrumentString calculateNextLowerString(InstrumentString current) {
    int idx = NOTE_NAMES.indexOf(current.note);
    int newIdx = idx - 5;
    int newOct = current.octave;

    // Wrap around logic
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

  // Create a copy for editing
  InstrumentString copy() => InstrumentString(note: note, octave: octave);
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

  // --- FACTORY PRESETS ---

  // Named 'standard6String' for clarity
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

  // Renamed to match naming style
  static TuningPreset standard7String() => TuningPreset(
    id: "std_7",
    name: "7-String Standard (B)",
    style: HeadstockStyle.twoWay, // Usually 4+3 on 7-strings
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

  // Deep copy for the editor
  TuningPreset copy() {
    return TuningPreset(
      id: id,
      name: name,
      style: style,
      strings: strings.map((s) => s.copy()).toList(),
    );
  }
}
