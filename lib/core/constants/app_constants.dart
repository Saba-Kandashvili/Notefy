/// App-wide constants
class AppConstants {
  AppConstants._();

  // Audio configuration
  static const int sampleRate = 44100;
  static const int bufferSize = 8192;

  // Pitch detection bounds
  static const double minDetectableFrequency = 20.0;
  static const double maxDetectableFrequency = 5000.0;

  // Tuning thresholds (in cents)
  static const double inTuneThreshold = 5.0;
  static const double closeThreshold = 15.0;

  // Seismograph configuration
  static const int maxTrailPoints = 150;
  static const double scrollSpeed = 0.8;
  static const double centsLerpSpeed = 0.15;

  // Standby configuration
  static const int standbyDelayMs = 800;
  static const int standbyAnimationDurationMs = 600;

  // App info
  static const String appName = 'Notefy';
  static const String appVersion = 'v1.1.2 (Public Beta)';
  static const String supportEmail = 'sabakandashvili2004@gmail.com';
}
