import '../../../core/constants/app_constants.dart';

/// Represents the current state of the tuner
class TunerState {
  final double currentPitch;
  final String note;
  final int octave;
  final double cents;
  final String status;
  final bool isRecording;
  final bool isInitialized;
  final bool isInStandby;

  const TunerState({
    this.currentPitch = 0.0,
    this.note = "--",
    this.octave = 0,
    this.cents = 0.0,
    this.status = "Initializing...",
    this.isRecording = false,
    this.isInitialized = false,
    this.isInStandby = false,
  });

  /// Whether the tuner is actively detecting a valid note
  bool get isActive => isRecording && note != "--" && !isInStandby;

  /// Get the tuning status text
  String get tuningStatus {
    if (!isRecording || note == "--") return "";
    double absCents = cents.abs();
    if (absCents < AppConstants.inTuneThreshold) return "In Tune";
    if (cents > 0) return "Sharp";
    return "Flat";
  }

  /// Get the full note name (e.g., "A4")
  String get fullNoteName => note == "--" ? "--" : "$note$octave";

  /// Get formatted cents display (e.g., "+5.2" or "-3.1")
  String get centsDisplay {
    if (cents >= 0) {
      return "+${cents.toStringAsFixed(1)}";
    }
    return cents.toStringAsFixed(1);
  }

  /// Create a copy with modified values
  TunerState copyWith({
    double? currentPitch,
    String? note,
    int? octave,
    double? cents,
    String? status,
    bool? isRecording,
    bool? isInitialized,
    bool? isInStandby,
  }) {
    return TunerState(
      currentPitch: currentPitch ?? this.currentPitch,
      note: note ?? this.note,
      octave: octave ?? this.octave,
      cents: cents ?? this.cents,
      status: status ?? this.status,
      isRecording: isRecording ?? this.isRecording,
      isInitialized: isInitialized ?? this.isInitialized,
      isInStandby: isInStandby ?? this.isInStandby,
    );
  }

  /// Initial idle state
  static const TunerState initial = TunerState();

  /// State when paused
  TunerState paused() => copyWith(
    isRecording: false,
    status: "Paused",
    note: "--",
    currentPitch: 0.0,
    cents: 0.0,
  );

  /// State when listening
  TunerState listening() => copyWith(isRecording: true, status: "Listening...");
}
