import 'package:flutter/material.dart';

import '../tuning_model.dart';

class DynamicHeadstock extends StatelessWidget {
  final TuningPreset preset;
  final InstrumentString? selectedString;
  final Function(InstrumentString) onStringSelected;

  const DynamicHeadstock({
    super.key,
    required this.preset,
    required this.selectedString,
    required this.onStringSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Wood-ish background container for the "Headstock" area
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: preset.style == HeadstockStyle.oneWay
          ? _buildOneWayLayout()
          : _buildTwoWayLayout(),
    );
  }

  // --- LAYOUTS ---

  // Ibanez/Fender Style: Neck on left, all pegs on right
  Widget _buildOneWayLayout() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The "Wood" Headstock Shape
        Container(
          width: 60,
          height: preset.strings.length * 50.0 + 20,
          decoration: BoxDecoration(
            color: const Color(0xFF3E2723), // Dark Wood
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [Color(0xFF5D4037), Color(0xFF3E2723)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // The Pegs
        Column(
          children: preset.strings.map((s) => _buildPeg(s, true)).toList(),
        ),
      ],
    );
  }

  // Gibson Style: Neck in middle, pegs on both sides
  Widget _buildTwoWayLayout() {
    // Split strings: Half left, Half right
    // If 7 strings: 4 Left, 3 Right
    int midPoint = (preset.strings.length / 2).ceil();
    var leftStrings = preset.strings.sublist(0, midPoint);
    var rightStrings = preset.strings.sublist(midPoint);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Pegs
        Column(children: leftStrings.map((s) => _buildPeg(s, false)).toList()),
        // The "Wood" Headstock Shape
        Container(
          width: 80, // Wider for 3+3 style
          height: (midPoint * 60.0) + 20,
          decoration: BoxDecoration(
            color: const Color(0xFF3E2723),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
              bottom: Radius.circular(4),
            ),
            gradient: const LinearGradient(
              colors: [Color(0xFF5D4037), Color(0xFF3E2723)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: const Center(
            child: Text(
              "Notefy",
              style: TextStyle(
                color: Colors.white24,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
        // Right Pegs
        Column(children: rightStrings.map((s) => _buildPeg(s, true)).toList()),
      ],
    );
  }

  // --- PEG WIDGET ---
  Widget _buildPeg(InstrumentString string, bool isRightSide) {
    bool isSelected = selectedString == string;

    return GestureDetector(
      onTap: () => onStringSelected(string),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Line connecting peg to headstock (String visualization)
            if (isRightSide)
              Container(width: 15, height: 2, color: Colors.grey),

            // The Peg Circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Colors.greenAccent
                    : const Color(0xFF2D2D44),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white24,
                  width: 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.5),
                          blurRadius: 10,
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Text(
                  string.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),

            if (!isRightSide)
              Container(width: 15, height: 2, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
