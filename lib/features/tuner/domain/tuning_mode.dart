/// Represents the different tuning modes available in the app
enum TuningMode {
  chromatic,
  guitar,
  piano,
  practice,
  generator;

  String get displayName {
    switch (this) {
      case TuningMode.chromatic:
        return 'Chromatic';
      case TuningMode.guitar:
        return 'Strings';
      case TuningMode.piano:
        return 'Piano';
      case TuningMode.practice:
        return 'Practice';
      case TuningMode.generator:
        return 'Generator';
    }
  }

  String get description {
    switch (this) {
      case TuningMode.chromatic:
        return 'Detect any note';
      case TuningMode.guitar:
        return 'Custom string tunings';
      case TuningMode.piano:
        return 'Full range (A0-C8)';
      case TuningMode.practice:
        return 'Bends, Chords & More';
      case TuningMode.generator:
        return 'Tone synthesizer';
    }
  }
}
