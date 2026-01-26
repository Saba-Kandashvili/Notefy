import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../chromatic/presentation/chromatic_tuner_view.dart';
import '../../guitar/presentation/guitar_tuner_view.dart';
import '../../piano/presentation/piano_tuner_view.dart';
import '../domain/tuning_mode.dart';
import 'tuner_controller.dart';
import 'widgets/app_drawer.dart';

/// Main tuner screen that hosts all tuning modes
class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TunerController _controller;
  late AnimationController _standbyAnimationController;
  late AnimationController _scrollAnimationController;

  bool _wasRecordingBeforePause = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = TunerController();

    // Setup animation controllers
    _standbyAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: AppConstants.standbyAnimationDurationMs,
      ),
    );

    _scrollAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    );

    // Connect controllers
    _controller.setAnimationControllers(
      standbyController: _standbyAnimationController,
      scrollController: _scrollAnimationController,
    );

    // Listen for state changes
    _controller.addListener(_onControllerChanged);

    // Initialize
    _controller.initialize();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_controller.isRecording) {
        _wasRecordingBeforePause = true;
        _controller.stopCapture();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_wasRecordingBeforePause && _controller.isInitialized) {
        _wasRecordingBeforePause = false;
        _controller.startCapture();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
    _standbyAnimationController.dispose();
    _scrollAnimationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleModeChange(TuningMode mode) async {
    // Show warning for Piano mode (experimental)
    if (mode == TuningMode.piano) {
      final acknowledged = await _showPianoWarningDialog();
      if (acknowledged != true) {
        Navigator.pop(context);
        return;
      }
    }

    await _controller.setTuningMode(mode);
    if (mounted) Navigator.pop(context);
  }

  Future<bool?> _showPianoWarningDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Heads up — Piano tuner (Experimental)"),
        content: const Text(
          "The piano tuner is currently under development and may produce inaccurate results. "
          "If you proceed, please double-check your tuning by ear or with a trusted reference. "
          "Press 'Acknowledge' to continue, or 'Cancel' to return to your previous tuner.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Acknowledge"),
          ),
        ],
      ),
    );
  }

  void _showBugReportSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Please email bugs to ${AppConstants.supportEmail}"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppColors.textSecondary),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(_controller.tuningMode.displayName),
      ),
      drawer: AppDrawer(
        currentMode: _controller.tuningMode,
        onModeSelected: _handleModeChange,
        onReportBug: _showBugReportSnackbar,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_controller.tuningMode) {
      case TuningMode.chromatic:
        return ChromaticTunerView(controller: _controller);
      case TuningMode.guitar:
        return GuitarTunerView(controller: _controller);
      case TuningMode.piano:
        return PianoTunerView(controller: _controller);
    }
  }
}
