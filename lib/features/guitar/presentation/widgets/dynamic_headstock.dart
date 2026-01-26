import 'package:flutter/material.dart';

import '../../../../core/models/tuning_model.dart';
import '../../../../core/theme/app_theme.dart';

/// A fully dynamic string selector that always fits the available space.
/// Scales automatically for any number of strings (1-48+), no scrolling needed.
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
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF252538), Color(0xFF1E1E2C)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: List.generate(preset.strings.length, (index) {
          final string = preset.strings[index];
          final isSelected = selectedString == string;
          final stringCount = preset.strings.length;

          // String thickness scales with count (thicker bass strings)
          final maxThickness = stringCount <= 6
              ? 5.0
              : (stringCount <= 12 ? 4.0 : 3.0);
          final thicknessRange = stringCount <= 6
              ? 3.0
              : (stringCount <= 12 ? 2.0 : 1.5);
          final thickness =
              maxThickness - (index / stringCount) * thicknessRange;

          return Expanded(
            child: _StringButton(
              string: string,
              isSelected: isSelected,
              thickness: thickness,
              onTap: () => onStringSelected(string),
              index: index,
              total: stringCount,
            ),
          );
        }),
      ),
    );
  }
}

class _StringButton extends StatelessWidget {
  final InstrumentString string;
  final bool isSelected;
  final double thickness;
  final VoidCallback onTap;
  final int index;
  final int total;

  const _StringButton({
    required this.string,
    required this.isSelected,
    required this.thickness,
    required this.onTap,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    // Font size scales with string count
    final noteFontSize = total <= 4
        ? 18.0
        : (total <= 8 ? 14.0 : (total <= 16 ? 11.0 : 9.0));
    final octaveFontSize = total <= 4
        ? 12.0
        : (total <= 8 ? 10.0 : (total <= 16 ? 8.0 : 7.0));
    final showOctave = total <= 16; // Hide octave for very dense layouts

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Note label at top
            Flexible(
              flex: 2,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(
                    horizontal: total <= 6 ? 8 : (total <= 12 ? 5 : 3),
                    vertical: total <= 6 ? 4 : 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.inTuneColor
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(total <= 8 ? 8 : 4),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.inTuneColor
                          : Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.inTuneColor.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    string.note,
                    style: TextStyle(
                      fontSize: noteFontSize,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            // Visual string line
            Expanded(
              flex: 3,
              child: Center(
                child: Container(
                  width: thickness,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(thickness / 2),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isSelected
                          ? [
                              AppColors.inTuneColor,
                              AppColors.inTuneColor.withValues(alpha: 0.6),
                            ]
                          : [
                              _getStringColor(index, total),
                              _getStringColor(
                                index,
                                total,
                              ).withValues(alpha: 0.4),
                            ],
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.inTuneColor.withValues(
                                alpha: 0.5,
                              ),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            // Octave number at bottom (hidden for very dense layouts)
            if (showOctave)
              Flexible(
                flex: 1,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${string.octave}',
                    style: TextStyle(
                      fontSize: octaveFontSize,
                      color: isSelected
                          ? AppColors.inTuneColor
                          : Colors.white.withValues(alpha: 0.5),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStringColor(int index, int total) {
    if (total <= 1) return const Color(0xFFB8860B);

    // Bass strings are more bronze/copper, treble strings are more silver
    final progress = index / (total - 1);

    if (progress < 0.5) {
      // Bass strings - bronze/copper
      return Color.lerp(
        const Color(0xFFCD853F), // Peru/bronze
        const Color(0xFFB8860B), // Dark goldenrod
        progress * 2,
      )!;
    } else {
      // Treble strings - silver/steel
      return Color.lerp(
        const Color(0xFFB8860B),
        const Color(0xFFC0C0C0), // Silver
        (progress - 0.5) * 2,
      )!;
    }
  }
}
