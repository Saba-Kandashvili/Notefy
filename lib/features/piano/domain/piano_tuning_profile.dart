import 'dart:math';

enum PianoType { upright, babyGrand, grand, custom }

/// Represents a piano tuning profile with measured inharmonicity values
class PianoTuningProfile {
  final String id;
  final String name;
  final Map<int, double> measurements; // keyNumber -> B coefficient
  final DateTime createdAt;
  final PianoType pianoType;

  PianoTuningProfile({
    required this.id,
    required this.name,
    required this.measurements,
    required this.createdAt,
    this.pianoType = PianoType.custom,
  });

  /// Default profile (Equal Temperament, B=0)
  factory PianoTuningProfile.equalTemperament() {
    return PianoTuningProfile(
      id: 'default_et',
      name: 'Equal Temperament (Standard)',
      measurements: {},
      createdAt: DateTime.now(),
      pianoType: PianoType.custom,
    );
  }

  /// Create a profile from JSON
  factory PianoTuningProfile.fromJson(Map<String, dynamic> json) {
    final measurements = (json['measurements'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(int.parse(key), value as double),
    );
    return PianoTuningProfile(
      id: json['id'],
      name: json['name'],
      measurements: measurements,
      createdAt: DateTime.parse(json['createdAt']),
      pianoType: PianoType.values.firstWhere(
        (e) => e.name == (json['pianoType'] ?? 'custom'),
        orElse: () => PianoType.custom,
      ),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'measurements': measurements.map((key, value) => MapEntry(key.toString(), value)),
      'createdAt': createdAt.toIso8601String(),
      'pianoType': pianoType.name,
    };
  }
}

/// Helper to calculate stretched frequencies based on a profile
class StretchCalculator {
  /// Calculate stretched frequencies for all 88 keys
  static Map<int, double> calculateStretchedFrequencies(
    PianoTuningProfile profile,
    double a4Reference,
  ) {
    if (profile.measurements.isEmpty) {
      // Equal Temperament
      final Map<int, double> freqs = {};
      for (int n = 1; n <= 88; n++) {
        freqs[n] = a4Reference * pow(2, (n - 49) / 12);
      }
      return freqs;
    }

    // 1. Fit B(n) curve
    // Inharmonicity model: ln(B) = alpha * n + beta
    // We use linear regression on available measurements
    double sumX = 0, sumY = 0, sumXX = 0, sumXY = 0;
    int count = 0;
    profile.measurements.forEach((n, b) {
      if (b > 0) {
        double x = n.toDouble();
        double y = log(b);
        sumX += x;
        sumY += y;
        sumXX += x * x;
        sumXY += x * y;
        count++;
      }
    });

    double alpha, beta;
    double defaultAlpha;
    switch (profile.pianoType) {
      case PianoType.upright:
        defaultAlpha = 0.045;
        break;
      case PianoType.babyGrand:
        defaultAlpha = 0.038;
        break;
      case PianoType.grand:
        defaultAlpha = 0.032;
        break;
      case PianoType.custom:
      default:
        defaultAlpha = 0.035;
    }

    if (count >= 2) {
      alpha = (count * sumXY - sumX * sumY) / (count * sumXX - sumX * sumX);
      beta = (sumY - alpha * sumX) / count;
      // Guard against crazy slopes from noisy measurements
      if (alpha < 0.01 || alpha > 0.08) alpha = defaultAlpha;
    } else if (count == 1) {
      alpha = defaultAlpha;
      beta = log(profile.measurements.values.first) - alpha * profile.measurements.keys.first;
    } else {
      alpha = defaultAlpha;
      double guessB49 = (profile.pianoType == PianoType.upright) ? 0.0004 : 0.00015;
      beta = log(guessB49) - alpha * 49;
    }

    double getB(int n) => exp(alpha * n + beta);

    // 2. Calculate cents deviation from ET
    final Map<int, double> centsDeviation = {};
    centsDeviation[49] = 0.0; // A4 is reference

    // Calculate upwards (49 to 88)
    for (int n = 49; n < 88; n++) {
      // Octave matching rule (4:2)
      // c(n+12) - c(n) = 1200 * log2( sqrt(1 + 16B(n)) / sqrt(1 + 4B(n+12)) )
      // For each semitone, we take 1/12th of the octave stretch
      // This is an approximation of a smooth curve
      double octaveStretch = 1200 * (0.5 * log(1 + 16 * getB(n)) / ln2 - 0.5 * log(1 + 4 * getB(n + 12)) / ln2);
      centsDeviation[n + 1] = (centsDeviation[n] ?? 0) + (octaveStretch / 12);
    }

    // Calculate downwards (49 down to 1)
    for (int n = 49; n > 1; n--) {
      double octaveStretch = 1200 * (0.5 * log(1 + 16 * getB(n - 12 > 0 ? n - 12 : 1)) / ln2 - 0.5 * log(1 + 4 * getB(n)) / ln2);
      centsDeviation[n - 1] = (centsDeviation[n] ?? 0) - (octaveStretch / 12);
    }

    // 3. Convert to frequencies
    final Map<int, double> freqs = {};
    for (int n = 1; n <= 88; n++) {
      double etFreq = a4Reference * pow(2, (n - 49) / 12);
      freqs[n] = etFreq * pow(2, (centsDeviation[n] ?? 0) / 1200);
    }

    return freqs;
  }
}
