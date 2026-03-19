import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../tuner/presentation/tuner_controller.dart';
import '../domain/piano_key.dart';
import '../domain/piano_tuning_profile.dart';

class PianoCalibrationScreen extends StatefulWidget {
  final TunerController controller;

  const PianoCalibrationScreen({super.key, required this.controller});

  @override
  State<PianoCalibrationScreen> createState() => _PianoCalibrationScreenState();
}

class _PianoCalibrationScreenState extends State<PianoCalibrationScreen> {
  int _currentStep = 0;
  final List<int> _keysToMeasure = [21, 33, 45, 57, 69, 81]; // A1, A2, A3, A4, A5, A6
  PianoType _selectedType = PianoType.upright;
  final TextEditingController _nameController = TextEditingController(text: "My Piano");
  bool _isFinalizing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.startCalibration();
      _selectCurrentKey();
    });
  }

  void _selectCurrentKey() {
    final key = pianoKeys.firstWhere((k) => k.keyNumber == _keysToMeasure[_currentStep]);
    widget.controller.selectPianoKey(key);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final selectedKey = controller.selectedPianoKey;
        final lastB = controller.lastDetectedB;

        return Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          appBar: AppBar(
            backgroundColor: AppColors.surfaceColor,
            title: const Text("Piano Calibration"),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                controller.stopCalibration();
                Navigator.pop(context);
              },
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_isFinalizing) ...[
                  LinearProgressIndicator(
                    value: (_currentStep) / _keysToMeasure.length,
                    backgroundColor: AppColors.surfaceColor,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryAccent),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    "Step ${_currentStep + 1} of ${_keysToMeasure.length}",
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Play ${selectedKey?.fullName ?? ''}",
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: lastB > 0 ? AppColors.primaryAccent.withOpacity(0.5) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Inharmonicity (B)",
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          lastB > 0 ? lastB.toStringAsFixed(6) : "Listening...",
                          style: TextStyle(
                            color: lastB > 0 ? AppColors.primaryAccent : AppColors.textSecondary,
                            fontSize: 24,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    "Play the note steadily until a value appears. For best results, use a quiet room.",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: lastB > 0 ? _nextStep : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      disabledBackgroundColor: AppColors.surfaceColor,
                    ),
                    child: Text(_currentStep < _keysToMeasure.length - 1 ? "Next Note" : "Analyze Piano"),
                  ),
                ] else ...[
                  const Text(
                    "Calibration Complete",
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Select Piano Type:",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _TypeChip(
                        label: "Upright",
                        isSelected: _selectedType == PianoType.upright,
                        onTap: () => setState(() => _selectedType = PianoType.upright),
                      ),
                      _TypeChip(
                        label: "Baby Grand",
                        isSelected: _selectedType == PianoType.babyGrand,
                        onTap: () => setState(() => _selectedType = PianoType.babyGrand),
                      ),
                      _TypeChip(
                        label: "Full Grand",
                        isSelected: _selectedType == PianoType.grand,
                        onTap: () => setState(() => _selectedType = PianoType.grand),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: "Profile Name",
                      labelStyle: TextStyle(color: AppColors.primaryAccent),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.surfaceColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primaryAccent),
                      ),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text("Save and Apply"),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _nextStep() {
    widget.controller.captureCalibrationMeasurement();
    if (_currentStep < _keysToMeasure.length - 1) {
      setState(() {
        _currentStep++;
        _selectCurrentKey();
      });
    } else {
      setState(() {
        _isFinalizing = true;
      });
    }
  }

  void _saveProfile() {
    widget.controller.finalizeCalibration(_nameController.text, _selectedType);
    Navigator.pop(context);
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryAccent : AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryAccent : AppColors.textSecondary.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
