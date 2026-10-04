import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import 'generator_controller.dart';

class GeneratorView extends StatefulWidget {
  const GeneratorView({super.key});

  @override
  State<GeneratorView> createState() => _GeneratorViewState();
}

class _GeneratorViewState extends State<GeneratorView> with SingleTickerProviderStateMixin {
  late GeneratorController _controller;
  late Ticker _ticker;
  late TextEditingController _freqTextController;
  late FocusNode _freqFocusNode;

  @override
  void initState() {
    super.initState();
    _controller = GeneratorController();
    _controller.addListener(_onControllerChange);
    
    _freqTextController = TextEditingController(text: _controller.frequency.toStringAsFixed(1));
    _freqFocusNode = FocusNode();
    _freqFocusNode.addListener(() {
      if (!_freqFocusNode.hasFocus) {
        final double? val = double.tryParse(_freqTextController.text);
        if (val != null) {
          _controller.setFrequency(val);
        }
        _freqTextController.text = _controller.frequency.toStringAsFixed(1);
      }
    });

    // Ticker to continuously update the UI during a sweep
    _ticker = createTicker((_) {
      if (_controller.isPlaying && _controller.isAdvancedMode) {
        if (!_freqFocusNode.hasFocus) {
          double displayFreq = _controller.isSweeping ? _controller.currentSweepFrequency : _controller.frequency;
          _freqTextController.text = displayFreq.toStringAsFixed(1);
        }
        setState(() {});
      }
    });
    _ticker.start();
  }

  void _onControllerChange() {
    if (mounted) {
      if (!_freqFocusNode.hasFocus) {
        _freqTextController.text = _controller.frequency.toStringAsFixed(1);
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _freqTextController.dispose();
    _freqFocusNode.dispose();
    _controller.removeListener(_onControllerChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildModeToggle(),
        Expanded(
          child: _controller.isAdvancedMode 
              ? _buildAdvancedMode() 
              : _buildSimpleMode(),
        ),
      ],
    );
  }

  Widget _buildModeToggle() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Simple", style: TextStyle(color: Colors.white70)),
          Switch(
            value: _controller.isAdvancedMode,
            activeColor: AppColors.primaryAccent,
            onChanged: (val) => _controller.setAdvancedMode(val),
          ),
          const Text("Sweep", style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildSimpleMode() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildWaveformSelector(),
        const Spacer(),
        _buildFrequencyDisplay(),
        const SizedBox(height: 16),
        _buildNoteDisplay(),
        const Spacer(),
        _buildFrequencySlider(),
        const SizedBox(height: 32),
        _buildPlayButton(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildAdvancedMode() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          _buildWaveformSelector(),
          const SizedBox(height: 16),
          _buildFrequencyDisplay(),
          const SizedBox(height: 8),
          _buildNoteDisplay(),
          const SizedBox(height: 16),
          
          // Settings Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2C),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: CompactNumberInput(label: "Start Freq", unit: "Hz", value: _controller.sweepStartFreq, onChanged: (v) => _controller.setSweepStart(v))),
                    const SizedBox(width: 16),
                    Expanded(child: CompactNumberInput(label: "End Freq", unit: "Hz", value: _controller.sweepEndFreq, onChanged: (v) => _controller.setSweepEnd(v))),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(height: 1, color: Colors.white10),
                ),
                Row(
                  children: [
                    Expanded(child: CompactNumberInput(label: "Duration", unit: "sec", value: _controller.sweepDurationSec, onChanged: (v) => _controller.setSweepDuration(v))),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text("Loop", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                          Switch(
                            value: _controller.loopSweep,
                            activeColor: AppColors.primaryAccent,
                            onChanged: (val) => _controller.setLoopSweep(val),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Sweep and Play controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Play/Stop Audio Button
              Column(
                children: [
                  _buildPlayButton(),
                  const SizedBox(height: 8),
                  Text(_controller.isPlaying ? "STOP AUDIO" : "PLAY AUDIO", style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                ],
              ),
              
              // Sweep Start/Stop Button
              Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_controller.isSweeping) {
                        _controller.stopSweep();
                      } else {
                        _controller.startSweep();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _controller.isSweeping ? Colors.orange.withOpacity(0.2) : Colors.blueAccent.withOpacity(0.2),
                        border: Border.all(
                          color: _controller.isSweeping ? Colors.orange : Colors.blueAccent,
                          width: 2,
                        ),
                        boxShadow: [
                          if (_controller.isSweeping)
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.5),
                              blurRadius: 15,
                              spreadRadius: 1,
                            )
                        ],
                      ),
                      child: Icon(
                        _controller.isSweeping ? Icons.pause_rounded : Icons.double_arrow_rounded,
                        size: 32,
                        color: _controller.isSweeping ? Colors.orange : Colors.blueAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_controller.isSweeping ? "STOP SWEEP" : "START SWEEP", style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }



  Widget _buildWaveformSelector() {
    return ToggleButtons(
      isSelected: [
        _controller.waveform == 0,
        _controller.waveform == 1,
        _controller.waveform == 2,
        _controller.waveform == 3,
      ],
      onPressed: (index) => _controller.setWaveform(index),
      color: Colors.white54,
      selectedColor: Colors.black,
      fillColor: AppColors.primaryAccent,
      borderRadius: BorderRadius.circular(12),
      constraints: const BoxConstraints(minHeight: 56, minWidth: 72),
      children: const [
        WaveformIcon(type: 0),
        WaveformIcon(type: 1),
        WaveformIcon(type: 2),
        WaveformIcon(type: 3),
      ],
    );
  }

  Widget _buildFrequencyDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primaryAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primaryAccent.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          IntrinsicWidth(
            child: TextField(
              controller: _freqTextController,
              focusNode: _freqFocusNode,
              readOnly: _controller.isAdvancedMode,
              onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w200,
                color: Colors.white,
                letterSpacing: 2,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
              ),
              onSubmitted: (val) {
                _freqFocusNode.unfocus();
              },
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            "Hz",
            style: TextStyle(
              fontSize: 24,
              color: AppColors.primaryAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteDisplay() {
    final info = _controller.closestNoteInfo;
    if (info == null) {
      return const Text(
        "Closest Note: --",
        style: TextStyle(
          fontSize: 20,
          color: AppColors.textSecondary,
          letterSpacing: 1.5,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 20,
          color: AppColors.textSecondary,
          letterSpacing: 1.5,
          fontFamily: 'Roboto', // Make sure it inherits the default or specify one
        ),
        children: [
          const TextSpan(text: "Closest Note: "),
          TextSpan(
            text: info.name,
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          WidgetSpan(
            child: Transform.translate(
              offset: const Offset(0, 4),
              child: Text(
                info.octave.toString(),
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          TextSpan(text: " (${info.perfectFrequency.toStringAsFixed(2)} Hz)"),
        ],
      ),
    );
  }

  Widget _buildFrequencySlider() {
    // Logarithmic slider implementation
    double minLog = log(20.0);
    double maxLog = log(20000.0);
    double valLog = log(_controller.frequency);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: SliderTheme(
        data: SliderThemeData(
          activeTrackColor: AppColors.primaryAccent,
          inactiveTrackColor: AppColors.primaryAccent.withOpacity(0.2),
          thumbColor: AppColors.primaryAccent,
          overlayColor: AppColors.primaryAccent.withOpacity(0.2),
          trackHeight: 4.0,
        ),
        child: Slider(
          value: valLog,
          min: minLog,
          max: maxLog,
          onChanged: (val) {
            double freq = exp(val);
            _controller.setFrequency(freq);
          },
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: () => _controller.togglePlay(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _controller.isPlaying ? AppColors.inTuneColor.withOpacity(0.2) : AppColors.primaryAccent.withOpacity(0.2),
          border: Border.all(
            color: _controller.isPlaying ? AppColors.inTuneColor : AppColors.primaryAccent,
            width: 2,
          ),
          boxShadow: [
            if (_controller.isPlaying)
              BoxShadow(
                color: AppColors.inTuneColor.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 2,
              )
          ],
        ),
        child: Icon(
          _controller.isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
          size: 48,
          color: _controller.isPlaying ? AppColors.inTuneColor : AppColors.primaryAccent,
        ),
      ),
    );
  }
}

class WaveformIcon extends StatelessWidget {
  final int type;

  const WaveformIcon({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? Colors.white;
    return SizedBox(
      width: 28,
      height: 28,
      child: CustomPaint(
        painter: _WaveformPainter(type: type, color: color),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final int type;
  final Color color;

  _WaveformPainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final w = size.width;
    final h = size.height;
    final midY = h / 2;

    switch (type) {
      case 0: // Sine
        path.moveTo(0, midY);
        path.quadraticBezierTo(w * 0.25, -h * 0.1, w * 0.5, midY);
        path.quadraticBezierTo(w * 0.75, h * 1.1, w, midY);
        break;
      case 1: // Square
        path.moveTo(0, midY);
        path.lineTo(0, h * 0.2);
        path.lineTo(w * 0.5, h * 0.2);
        path.lineTo(w * 0.5, h * 0.8);
        path.lineTo(w, h * 0.8);
        path.lineTo(w, midY);
        break;
      case 2: // Sawtooth
        path.moveTo(0, h * 0.8);
        path.lineTo(w * 0.5, h * 0.2);
        path.lineTo(w * 0.5, h * 0.8);
        path.lineTo(w, h * 0.2);
        break;
      case 3: // Triangle
        path.moveTo(0, midY);
        path.lineTo(w * 0.25, h * 0.2);
        path.lineTo(w * 0.75, h * 0.8);
        path.lineTo(w, midY);
        break;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color;
  }
}

class CompactNumberInput extends StatefulWidget {
  final String label;
  final String unit;
  final double value;
  final ValueChanged<double> onChanged;

  const CompactNumberInput({
    Key? key,
    required this.label,
    required this.unit,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<CompactNumberInput> createState() => _CompactNumberInputState();
}

class _CompactNumberInputState extends State<CompactNumberInput> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toStringAsFixed(1));
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _saveValue();
      }
    });
  }

  @override
  void didUpdateWidget(covariant CompactNumberInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.value != widget.value) {
      _controller.text = widget.value.toStringAsFixed(1);
    }
  }

  void _saveValue() {
    final d = double.tryParse(_controller.text);
    if (d != null) {
      widget.onChanged(d);
    }
    // Always format back to exactly match the internal state
    _controller.text = widget.value.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.primaryAccent, fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onSubmitted: (val) => _focusNode.unfocus(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(widget.unit, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
