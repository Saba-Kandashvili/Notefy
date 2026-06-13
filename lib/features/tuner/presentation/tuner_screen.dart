import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../chromatic/presentation/chromatic_tuner_view.dart';
import '../../guitar/presentation/guitar_tuner_view.dart';
import '../../piano/presentation/piano_tuner_view.dart';
import '../../practice/presentation/practice_view.dart';
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

    // Show warning for Practice mode (under construction)
    if (mode == TuningMode.practice) {
      final acknowledged = await _showPracticeWarningDialog();
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
        backgroundColor: const Color(0xFF2D2D44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Heads up — Piano tuner (Experimental)",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "The piano tuner is currently under development and may produce inaccurate results. "
          "If you proceed, please double-check your tuning by ear or with a trusted reference. "
          "Press 'Acknowledge' to continue, or 'Cancel' to return to your previous tuner.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            child: const Text("ACKNOWLEDGE"),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showPracticeWarningDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Heads up — Practice tab (Under Construction)",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Practice mode is heavily under construction and experimental right now. "
          "Some features may not work correctly yet. "
          "Press 'Continue' to enter anyway, or 'Cancel' to go back.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warningAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            child: const Text("CONTINUE"),
          ),
        ],
      ),
    );
  }

  void _showBugReportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.bug_report, color: AppColors.primaryAccent),
            const SizedBox(width: 12),
            const Text("Report a Bug", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Found a bug? Help us improve Notefy by sending a detailed description to:",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Clipboard.setData(
                  const ClipboardData(text: AppConstants.supportEmail),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("Email copied to clipboard!"),
                    backgroundColor: AppColors.inTuneColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppConstants.supportEmail,
                        style: TextStyle(
                          color: AppColors.primaryAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(Icons.copy, color: AppColors.primaryAccent, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Please include:\n• What you were doing\n• What went wrong\n• Your device model",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
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
        onReportBug: _showBugReportDialog,
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
      case TuningMode.practice:
        return PracticeView(controller: _controller);
    }
  }
}
