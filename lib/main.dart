import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:notefy/seismograph_painter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// Local module imports
import 'audio_engine.dart';
import 'dynamic_headstock.dart';
import 'tuning_editor.dart';
import 'tuning_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFF16213E)),
        textTheme: const TextTheme(bodyMedium: TextStyle(fontFamily: 'Roboto')),
      ),
      home: TunerScreen(),
    );
  }
}

// Instrument definitions
enum TuningMode { chromatic, guitar, piano }

// Piano key definition
class PianoKey {
  final String name;
  final int octave;
  final double frequency;
  final int keyNumber;
  final bool isBlack;

  const PianoKey(
    this.name,
    this.octave,
    this.frequency,
    this.keyNumber,
    this.isBlack,
  );
  String get fullName => "$name$octave";
}

// Generate all 88 piano keys
List<PianoKey> generatePianoKeys() {
  List<PianoKey> keys = [];
  const noteNames = [
    "C",
    "C#",
    "D",
    "D#",
    "E",
    "F",
    "F#",
    "G",
    "G#",
    "A",
    "A#",
    "B",
  ];
  const blackKeyPattern = [
    false,
    true,
    false,
    true,
    false,
    false,
    true,
    false,
    true,
    false,
    true,
    false,
  ];

  int keyNumber = 1;
  for (int i = 9; i < 12; i++) {
    int midiNote = 21 + (i - 9);
    double freq = 440.0 * pow(2, (midiNote - 69) / 12);
    keys.add(PianoKey(noteNames[i], 0, freq, keyNumber++, blackKeyPattern[i]));
  }
  for (int octave = 1; octave <= 7; octave++) {
    for (int i = 0; i < 12; i++) {
      int midiNote = 12 + (octave * 12) + i;
      double freq = 440.0 * pow(2, (midiNote - 69) / 12);
      keys.add(
        PianoKey(noteNames[i], octave, freq, keyNumber++, blackKeyPattern[i]),
      );
    }
  }
  double freqC8 = 440.0 * pow(2, (108 - 69) / 12);
  keys.add(PianoKey("C", 8, freqC8, keyNumber, false));
  return keys;
}

final List<PianoKey> pianoKeys = generatePianoKeys();

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});
  @override
  _TunerScreenState createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final _audioRecorder = FlutterAudioCapture();
  final _engine = AudioEngine();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // State
  double _currentPitch = 0.0;
  String _note = "--";
  int _octave = 0;
  double _cents = 0.0;
  String _status = "Initializing...";
  bool _isRecording = false;
  bool _isInitialized = false;

  final List<double> _trailPositions = [];
  static const int _maxTrailPoints = 150;

  TuningMode _tuningMode = TuningMode.chromatic;

  // --- GUITAR STATE ---
  TuningPreset _currentGuitarPreset = TuningPreset.standard6String();
  InstrumentString? _targetString;

  // NEW: Store user created presets
  List<TuningPreset> _customPresets = [];

  // Piano State
  PianoKey? _selectedPianoKey;
  final ScrollController _pianoScrollController = ScrollController();

  // Animation
  bool _wasRecordingBeforePause = false;
  bool _isInStandby = false;
  Timer? _standbyTimer;
  late AnimationController _standbyAnimationController;
  late Animation<double> _standbyAnimation;
  late AnimationController _scrollAnimationController;
  double _scrollOffset = 0.0;
  double _displayedCents = 0.0;
  double _targetCents = 0.0;
  static const double _lerpSpeed = 0.15;
  double _lastCentsBeforeStandby = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _standbyAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _standbyAnimation = CurvedAnimation(
      parent: _standbyAnimationController,
      curve: Curves.easeOutCubic,
    );
    _standbyAnimationController.addListener(() {
      if (mounted) setState(() {});
    });

    _scrollAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..repeat();
    _scrollAnimationController.addListener(() {
      if (mounted) {
        _scrollOffset += 0.8;
        _updateDisplayedCents();
        _addTrailPoint();
        setState(() {});
      }
    });

    _initAudio();
    _loadState();
  }

  // --- PERSISTENCE LOGIC ---

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load Custom Presets List
    final List<String>? customListJson = prefs.getStringList(
      'custom_presets_list',
    );
    if (customListJson != null) {
      try {
        _customPresets = customListJson
            .map((str) => TuningPreset.fromJson(jsonDecode(str)))
            .toList();
      } catch (e) {
        print("Error loading custom presets: $e");
      }
    }

    // 2. Load Mode
    final modeIndex = prefs.getInt('tuning_mode');
    if (modeIndex != null) {
      setState(() => _tuningMode = TuningMode.values[modeIndex]);
    }

    // 3. Load Current Preset (Active)
    final String? presetJson = prefs.getString('guitar_preset');
    if (presetJson != null) {
      try {
        setState(() {
          _currentGuitarPreset = TuningPreset.fromJson(jsonDecode(presetJson));
        });
      } catch (e) {
        print("Error loading active preset: $e");
      }
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();

    // Save Mode
    await prefs.setInt('tuning_mode', _tuningMode.index);

    // Save Active Preset
    await prefs.setString(
      'guitar_preset',
      jsonEncode(_currentGuitarPreset.toJson()),
    );

    // Save Custom List
    final List<String> customJsonList = _customPresets
        .map((p) => jsonEncode(p.toJson()))
        .toList();
    await prefs.setStringList('custom_presets_list', customJsonList);
  }

  // --- APP LOGIC ---

  void _updateDisplayedCents() {
    if (_isInStandby) {
      _displayedCents = _displayedCents * (1 - _lerpSpeed);
      if (_displayedCents.abs() < 0.1) _displayedCents = 0.0;
    } else {
      _displayedCents =
          _displayedCents + (_targetCents - _displayedCents) * _lerpSpeed;
    }
  }

  void _addTrailPoint() {
    if (_isRecording) {
      _trailPositions.insert(0, _displayedCents);
      while (_trailPositions.length > _maxTrailPoints) {
        _trailPositions.removeLast();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_isRecording) {
        _wasRecordingBeforePause = true;
        _stopCapture();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_wasRecordingBeforePause && _isInitialized) {
        _wasRecordingBeforePause = false;
        _startCapture();
      }
    }
  }

  Future<void> _initAudio() async {
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      try {
        await _audioRecorder.init();
        _isInitialized = true;
        setState(() => _status = "Tap to Start");
      } catch (e) {
        setState(() => _status = "Init error: $e");
      }
    } else {
      setState(() => _status = "Microphone permission denied");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pianoScrollController.dispose();
    _standbyTimer?.cancel();
    _standbyAnimationController.dispose();
    _scrollAnimationController.dispose();
    if (_isRecording) _audioRecorder.stop();
    _engine.dispose();
    super.dispose();
  }

  Future<void> _startCapture() async {
    if (!_isInitialized) return;
    _trailPositions.clear();
    _resetStandby();

    try {
      await _audioRecorder.start(
        (data) {
          double pitch = _engine.processAudioFloat32(data);
          if (pitch > 20 && pitch < 5000) {
            _onPitchDetected(pitch);
          } else {
            _onNoPitchDetected();
          }
        },
        onError,
        sampleRate: 44100,
        bufferSize: 8192,
      );
      WakelockPlus.enable();
      setState(() {
        _isRecording = true;
        _status = "Listening...";
      });
    } catch (e) {
      setState(() => _status = "Error: $e");
    }
  }

  void onError(Object e) => setState(() => _status = "Error: $e");

  Future<void> _stopCapture() async {
    try {
      await _audioRecorder.stop();
    } catch (e) {
      /* ignore */
    }
    WakelockPlus.disable();
    _standbyTimer?.cancel();
    _resetStandby();
    setState(() {
      _isRecording = false;
      _status = "Paused";
      _note = "--";
      _currentPitch = 0.0;
      _cents = 0.0;
    });
  }

  void _onPitchDetected(double pitch) {
    _standbyTimer?.cancel();
    if (_isInStandby) {
      _isInStandby = false;
      _standbyAnimationController.reset();
    }
    _calculateNote(pitch);
  }

  void _onNoPitchDetected() {
    if (_standbyTimer == null || !_standbyTimer!.isActive) {
      if (!_isInStandby && _note != "--") {
        _standbyTimer = Timer(const Duration(milliseconds: 800), () {
          if (mounted && _isRecording) _enterStandby();
        });
      }
    }
  }

  void _enterStandby() {
    if (!mounted) return;
    setState(() {
      _lastCentsBeforeStandby = _displayedCents;
      _isInStandby = true;
    });
    _standbyAnimationController.forward();
  }

  void _resetStandby() {
    _standbyTimer?.cancel();
    _isInStandby = false;
    _standbyAnimationController.reset();
    _lastCentsBeforeStandby = 0.0;
  }

  void _calculateNote(double freq) {
    if (freq <= 0) return;

    double midi = 12 * (log(freq / 440.0) / log(2)) + 69;
    int midiRounded = midi.round();
    double cents = (midi - midiRounded) * 100;

    int octave = (midiRounded / 12).floor() - 1;
    int noteIndex = midiRounded % 12;
    String noteName = NOTE_NAMES[noteIndex];

    // Guitar Target Logic
    if (_tuningMode == TuningMode.guitar && _targetString != null) {
      double targetFreq = _targetString!.frequency;
      double rawCents = 1200 * (log(freq / targetFreq) / log(2));
      cents = rawCents.clamp(-100.0, 100.0);
      if (rawCents.abs() <= 200) {
        noteName = _targetString!.note;
        octave = _targetString!.octave;
      }
    }

    // Piano Target Logic
    if (_tuningMode == TuningMode.piano && _selectedPianoKey != null) {
      double targetFreq = _selectedPianoKey!.frequency;
      double rawCents = 1200 * (log(freq / targetFreq) / log(2));
      cents = rawCents.clamp(-100.0, 100.0);
      if (rawCents.abs() <= 200) {
        noteName = _selectedPianoKey!.name;
        octave = _selectedPianoKey!.octave;
      }
    }

    if (mounted) {
      _targetCents = cents;
      setState(() {
        _currentPitch = freq;
        _note = noteName;
        _octave = octave;
        _cents = cents;
      });
    }
  }

  Color _getTuningColor() {
    double absCents = _cents.abs();
    if (absCents < 5) return Colors.greenAccent;
    if (absCents < 15) return Colors.yellowAccent;
    return Colors.redAccent;
  }

  String _getTuningStatus() {
    if (!_isRecording || _note == "--") return "";
    double absCents = _cents.abs();
    if (absCents < 5) return "In Tune";
    if (_cents > 0) return "Sharp";
    return "Flat";
  }

  // --- PRESET MANAGEMENT ---

  Future<void> _setTuningMode(TuningMode mode) async {
    // If the user is switching to the Piano tuner, show a friendly warning dialog
    if (mode == TuningMode.piano) {
      final bool? acknowledged = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
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
          );
        },
      );

      // If the user didn't acknowledge, close the drawer and abort switching
      if (acknowledged != true) {
        Navigator.pop(context);
        return;
      }
    }

    setState(() {
      _tuningMode = mode;
      _targetString = null;
      _selectedPianoKey = null;
      _trailPositions.clear();
    });

    if (mode == TuningMode.guitar) {
      _engine.setTuningMode(TuningModeNative.guitar);
    } else if (mode == TuningMode.piano) {
      _engine.setTuningMode(TuningModeNative.piano);
    } else {
      _engine.setTuningMode(TuningModeNative.chromatic);
    }

    _saveState();
    Navigator.pop(context);
  }

  void _openEditor() async {
    final editedPreset = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TuningEditor(initialPreset: _currentGuitarPreset),
      ),
    );

    if (editedPreset != null && editedPreset is TuningPreset) {
      setState(() {
        _currentGuitarPreset = editedPreset;
        _targetString = null;
        _trailPositions.clear();

        // Update the preset in the list if it exists
        int index = _customPresets.indexWhere((p) => p.id == editedPreset.id);
        if (index != -1) {
          _customPresets[index] = editedPreset;
        }
      });
      _saveState();
    }
  }

  void _createNewPreset() {
    // 1. Create a new default preset
    var newPreset = TuningPreset.standard6String();
    newPreset.id = DateTime.now().millisecondsSinceEpoch
        .toString(); // Unique ID
    newPreset.name = "Custom Tuning ${_customPresets.length + 1}";

    setState(() {
      _customPresets.add(newPreset);
      _currentGuitarPreset = newPreset;
    });

    // 2. Save
    _saveState();

    // 3. Close the bottom sheet and open editor
    Navigator.pop(context); // Close sheet
    _openEditor(); // Open editor immediately
  }

  void _deletePreset(TuningPreset preset) {
    setState(() {
      _customPresets.removeWhere((p) => p.id == preset.id);
      if (_currentGuitarPreset.id == preset.id) {
        _currentGuitarPreset = TuningPreset.standard6String(); // Fallback
      }
    });
    _saveState();
    Navigator.pop(context); // Close sheet
  }

  void _showPresetSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Select Preset",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),

              // New Button
              ListTile(
                leading: const Icon(
                  Icons.add_circle,
                  color: Colors.greenAccent,
                ),
                title: const Text(
                  "Create New Preset",
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: _createNewPreset,
              ),
              const Divider(color: Colors.white24),

              Expanded(
                child: ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "Factory Presets",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                    ListTile(
                      title: const Text(
                        "Standard 6-String",
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        setState(
                          () => _currentGuitarPreset =
                              TuningPreset.standard6String(),
                        );
                        _saveState();
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      title: const Text(
                        "7-String Standard (B)",
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        setState(
                          () => _currentGuitarPreset =
                              TuningPreset.standard7String(),
                        );
                        _saveState();
                        Navigator.pop(context);
                      },
                    ),

                    if (_customPresets.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          "My Presets",
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                      ..._customPresets.map(
                        (preset) => ListTile(
                          title: Text(
                            preset.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.white24,
                              size: 20,
                            ),
                            onPressed: () => _deletePreset(preset),
                          ),
                          onTap: () {
                            setState(() => _currentGuitarPreset = preset);
                            _saveState();
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white70),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          _tuningMode == TuningMode.chromatic
              ? "Chromatic"
              : _tuningMode == TuningMode.guitar
              ? "Guitar"
              : "Piano",
          style: const TextStyle(color: Colors.white70, fontSize: 18),
        ),
        centerTitle: true,
      ),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: _tuningMode == TuningMode.guitar
            ? _buildGuitarTunerBody()
            : _tuningMode == TuningMode.piano
            ? _buildPianoTunerBody()
            : _buildChromaticTunerBody(),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.music_note, color: Colors.greenAccent, size: 32),
                ),
                const SizedBox(height: 12),
                const Text("Notefy", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                // --- BETA LABEL HERE ---
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.amber.withOpacity(0.5))),
                  child: const Text("v1.0.0 (Public Beta)", style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          _buildDrawerItem(Icons.graphic_eq, "Chromatic", "Detect any note", TuningMode.chromatic),
          _buildDrawerItem(Icons.music_note, "Guitar / Strings", "Custom tunings & Strings", TuningMode.guitar),
          _buildDrawerItem(Icons.piano, "Piano", "Full range (A0-C8)", TuningMode.piano),
          
          const Divider(color: Colors.white24),
          
          // --- FEEDBACK LINK ---
          ListTile(
            leading: const Icon(Icons.bug_report, color: Colors.white54),
            title: const Text("Report a Bug", style: TextStyle(color: Colors.white70)),
            onTap: () {
                // You can add url_launcher here later to open GitHub Issues or Email
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please email bugs to sabakandashvili2004@gmail.com")));
            },
          )
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title,
    String sub,
    TuningMode mode,
  ) {
    bool isSelected = _tuningMode == mode;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.greenAccent : Colors.white54,
      ),
      title: Text(
        title,
        style: TextStyle(color: isSelected ? Colors.greenAccent : Colors.white),
      ),
      subtitle: Text(
        sub,
        style: const TextStyle(color: Colors.white38, fontSize: 12),
      ),
      selected: isSelected,
      selectedTileColor: Colors.greenAccent.withOpacity(0.1),
      onTap: () => _setTuningMode(mode),
    );
  }

  Widget _buildChromaticTunerBody() {
    String detectedNote = _isRecording && _note != "--" && !_isInStandby
        ? "$_note$_octave"
        : "--";
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          detectedNote,
          style: TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.bold,
            color: _isRecording && _note != "--" && !_isInStandby
                ? _getTuningColor()
                : Colors.white38,
          ),
        ),
        if (_isRecording && _currentPitch > 0 && !_isInStandby)
          Text(
            "${_currentPitch.toStringAsFixed(1)} Hz",
            style: const TextStyle(color: Colors.white38, fontSize: 16),
          ),
        const SizedBox(height: 20),
        Expanded(child: _buildSeismograph(targetNote: "")),
        _buildTuningStatusBar(),
        const SizedBox(height: 20),
        _buildControls(),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildGuitarTunerBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white54),
                onPressed: _openEditor,
              ),
              InkWell(
                onTap: _showPresetSelector,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        _currentGuitarPreset.name,
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.greenAccent,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DynamicHeadstock(
                preset: _currentGuitarPreset,
                selectedString: _targetString,
                onStringSelected: (str) {
                  setState(() {
                    _targetString = str;
                    _trailPositions.clear();
                    if (!_isRecording && _isInitialized) _startCapture();
                  });
                },
              ),
            ),
          ),
        ),
        if (_targetString != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              "Target: ${_targetString!.name} (${_targetString!.frequency.toStringAsFixed(1)} Hz)",
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              "Select a string to tune",
              style: TextStyle(color: Colors.white30, fontSize: 14),
            ),
          ),
        Expanded(
          flex: 5,
          child: _buildSeismograph(targetNote: _targetString?.name ?? ""),
        ),
        _buildTuningStatusBar(),
        const SizedBox(height: 10),
        _buildControls(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPianoTunerBody() {
    return Column(
      children: [
        const SizedBox(height: 10),
        _buildPianoKeyboard(),
        const SizedBox(height: 10),
        if (_selectedPianoKey != null) ...[
          Text(
            "Target: Key #${_selectedPianoKey!.keyNumber} - ${_selectedPianoKey!.fullName} (${_selectedPianoKey!.frequency.toStringAsFixed(2)} Hz)",
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ] else ...[
          const Text(
            "Scroll and tap a key to tune",
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
        const SizedBox(height: 10),
        Expanded(
          child: _buildSeismograph(
            targetNote: _selectedPianoKey?.fullName ?? "",
          ),
        ),
        _buildTuningStatusBar(),
        const SizedBox(height: 10),
        _buildControls(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSeismograph({required String targetNote}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: SeismographPainter(
            trailPositions: _trailPositions,
            targetNote: targetNote,
            isActive: _isRecording,
            currentCents: _displayedCents,
            currentNote: _note,
            currentOctave: _octave,
            isInStandby: _isInStandby,
            standbyProgress: _standbyAnimation.value,
            scrollOffset: _scrollOffset,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }

  Widget _buildTuningStatusBar() {
    String status = _getTuningStatus();
    String centsText = _cents >= 0
        ? "+${_cents.toStringAsFixed(1)}"
        : _cents.toStringAsFixed(1);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                _isRecording && _note != "--" && !_isInStandby
                    ? centsText
                    : "--",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _isRecording && _note != "--" && !_isInStandby
                      ? _getTuningColor()
                      : Colors.white38,
                ),
              ),
              const Text(
                "cents",
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          Container(width: 1, height: 40, color: Colors.white12),
          Column(
            children: [
              Text(
                status.isEmpty || _isInStandby ? "--" : status,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _isRecording && _note != "--" && !_isInStandby
                      ? _getTuningColor()
                      : Colors.white38,
                ),
              ),
              const Text(
                "status",
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return GestureDetector(
      onTap: _isRecording ? _stopCapture : _startCapture,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isRecording ? Colors.red : Colors.greenAccent,
          boxShadow: [
            BoxShadow(
              color: (_isRecording ? Colors.red : Colors.greenAccent)
                  .withOpacity(0.4),
              blurRadius: 16,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Icon(
          _isRecording ? Icons.stop : Icons.mic,
          size: 32,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildPianoKeyboard() {
    final whiteKeys = pianoKeys.where((k) => !k.isBlack).toList();
    final blackKeys = pianoKeys.where((k) => k.isBlack).toList();
    const double whiteW = 44.0, whiteH = 120.0, blackW = 28.0, blackH = 75.0;
    return Container(
      height: whiteH + 20,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: SingleChildScrollView(
        controller: _pianoScrollController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: whiteKeys.length * whiteW,
          height: whiteH + 20,
          child: Stack(
            children: [
              Row(
                children: whiteKeys
                    .map((key) => _buildWhiteKey(key, whiteW, whiteH))
                    .toList(),
              ),
              ...blackKeys.map((key) {
                int whiteIdx = _getWhiteKeyIndexBeforeBlackKey(key);
                double left = (whiteIdx + 1) * whiteW - (blackW / 2) - 1;
                return Positioned(
                  left: left,
                  top: 0,
                  child: _buildBlackKey(key, blackW, blackH),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWhiteKey(PianoKey key, double w, double h) {
    bool isSel = _selectedPianoKey == key;
    bool inTune = isSel && _isRecording && _cents.abs() < 5;
    return GestureDetector(
      onTap: () => _selectPianoKey(key),
      child: Container(
        width: w - 2,
        height: h,
        margin: const EdgeInsets.only(right: 2),
        decoration: BoxDecoration(
          color: isSel
              ? (inTune ? Colors.greenAccent : Colors.amber.shade200)
              : Colors.white,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              key.name,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "${key.octave}",
              style: const TextStyle(color: Colors.black54, fontSize: 10),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildBlackKey(PianoKey key, double w, double h) {
    bool isSel = _selectedPianoKey == key;
    bool inTune = isSel && _isRecording && _cents.abs() < 5;
    return GestureDetector(
      onTap: () => _selectPianoKey(key),
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: isSel
              ? (inTune ? Colors.green.shade700 : Colors.amber.shade700)
              : Colors.black,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
        ),
      ),
    );
  }

  int _getWhiteKeyIndexBeforeBlackKey(PianoKey blackKey) {
    final whiteKeys = pianoKeys.where((k) => !k.isBlack).toList();
    for (int i = 0; i < whiteKeys.length; i++) {
      final wk = whiteKeys[i];
      if (wk.octave == blackKey.octave) {
        if ((blackKey.name == "C#" && wk.name == "C") ||
            (blackKey.name == "D#" && wk.name == "D") ||
            (blackKey.name == "F#" && wk.name == "F") ||
            (blackKey.name == "G#" && wk.name == "G") ||
            (blackKey.name == "A#" && wk.name == "A"))
          return i;
      }
      if (blackKey.octave == 0 &&
          blackKey.name == "A#" &&
          wk.octave == 0 &&
          wk.name == "A")
        return i;
    }
    return 0;
  }

  void _selectPianoKey(PianoKey key) {
    setState(() {
      _selectedPianoKey = key;
      _trailPositions.clear();
    });
    if (!_isRecording && _isInitialized) _startCapture();
  }
}
