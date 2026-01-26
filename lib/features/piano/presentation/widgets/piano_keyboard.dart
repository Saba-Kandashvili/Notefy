import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/piano_key.dart';

/// Scrollable piano keyboard widget
class PianoKeyboard extends StatelessWidget {
  final PianoKey? selectedKey;
  final double cents;
  final bool isRecording;
  final void Function(PianoKey key) onKeySelected;
  final ScrollController? scrollController;

  static const double whiteKeyWidth = 44.0;
  static const double whiteKeyHeight = 120.0;
  static const double blackKeyWidth = 28.0;
  static const double blackKeyHeight = 75.0;

  const PianoKeyboard({
    super.key,
    required this.selectedKey,
    required this.cents,
    required this.isRecording,
    required this.onKeySelected,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final whiteKeys = pianoKeys.where((k) => !k.isBlack).toList();
    final blackKeys = pianoKeys.where((k) => k.isBlack).toList();

    return Container(
      height: whiteKeyHeight + 20,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: SingleChildScrollView(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: whiteKeys.length * whiteKeyWidth,
          height: whiteKeyHeight + 20,
          child: Stack(
            children: [
              // White keys
              Row(
                children: whiteKeys
                    .map(
                      (key) => _WhiteKey(
                        pianoKey: key,
                        isSelected: selectedKey == key,
                        isInTune:
                            selectedKey == key &&
                            isRecording &&
                            cents.abs() < 5,
                        onTap: () => onKeySelected(key),
                      ),
                    )
                    .toList(),
              ),
              // Black keys
              ...blackKeys.map((key) {
                final whiteIdx =
                    PianoKeyGenerator.getWhiteKeyIndexBeforeBlackKey(
                      key,
                      pianoKeys,
                    );
                final left =
                    (whiteIdx + 1) * whiteKeyWidth - (blackKeyWidth / 2) - 1;
                return Positioned(
                  left: left,
                  top: 0,
                  child: _BlackKey(
                    pianoKey: key,
                    isSelected: selectedKey == key,
                    isInTune:
                        selectedKey == key && isRecording && cents.abs() < 5,
                    onTap: () => onKeySelected(key),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhiteKey extends StatelessWidget {
  final PianoKey pianoKey;
  final bool isSelected;
  final bool isInTune;
  final VoidCallback onTap;

  const _WhiteKey({
    required this.pianoKey,
    required this.isSelected,
    required this.isInTune,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color keyColor;
    if (isSelected) {
      keyColor = isInTune ? AppColors.inTuneColor : Colors.amber.shade200;
    } else {
      keyColor = Colors.white;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: PianoKeyboard.whiteKeyWidth - 2,
        height: PianoKeyboard.whiteKeyHeight,
        margin: const EdgeInsets.only(right: 2),
        decoration: BoxDecoration(
          color: keyColor,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              pianoKey.name,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "${pianoKey.octave}",
              style: const TextStyle(color: Colors.black54, fontSize: 10),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _BlackKey extends StatelessWidget {
  final PianoKey pianoKey;
  final bool isSelected;
  final bool isInTune;
  final VoidCallback onTap;

  const _BlackKey({
    required this.pianoKey,
    required this.isSelected,
    required this.isInTune,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color keyColor;
    if (isSelected) {
      keyColor = isInTune ? Colors.green.shade700 : Colors.amber.shade700;
    } else {
      keyColor = Colors.black;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: PianoKeyboard.blackKeyWidth,
        height: PianoKeyboard.blackKeyHeight,
        decoration: BoxDecoration(
          color: keyColor,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
        ),
      ),
    );
  }
}
