enum BendType {
  quarter(0.25, '1/4'),
  half(0.5, '1/2'),
  full(1.0, 'Full'),
  oneAndQuarter(1.25, '1 1/4'),
  oneAndHalf(1.5, '1 1/2');

  final double steps;
  final String label;

  const BendType(this.steps, this.label);
}

enum CurveShape {
  linear('Linear'),
  parabolic('Parabolic');

  final String label;

  const CurveShape(this.label);
}

enum ReferenceNote {
  e2(82.41, 'E2'),
  a2(110.00, 'A2'),
  d3(146.83, 'D3'),
  g3(196.00, 'G3'),
  b3(246.94, 'B3'),
  e4(329.63, 'E4'),
  a4(440.00, 'A4');

  final double frequency;
  final String label;

  const ReferenceNote(this.frequency, this.label);
}
