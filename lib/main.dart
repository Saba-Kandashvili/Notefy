import 'dart:math';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'audio_engine.dart';

void main() {
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
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFF16213E),
        ),
      ),
      home: TunerScreen(),
    );
  }
}

// Data point for the seismograph trace
class PitchPoint {
  final double cents; // -100 to +100 (distance from target)
  final String note;
  final int octave;
  final DateTime timestamp;

  PitchPoint(this.cents, this.note, this.octave, this.timestamp);
}

// Instrument definitions
enum TuningMode { chromatic, guitar, piano }

class GuitarString {
  final String name;
  final int octave;
  final double frequency;
  final int stringNumber;

  const GuitarString(this.name, this.octave, this.frequency, this.stringNumber);
  
  String get fullName => "$name$octave";
}

// Piano key definition
class PianoKey {
  final String name;      // Note name (C, C#, D, etc.)
  final int octave;       // Octave number
  final double frequency; // Frequency in Hz
  final int keyNumber;    // Key number 1-88
  final bool isBlack;     // Is this a black key?

  const PianoKey(this.name, this.octave, this.frequency, this.keyNumber, this.isBlack);
  
  String get fullName => "$name$octave";
}

// Generate all 88 piano keys (A0 to C8)
List<PianoKey> generatePianoKeys() {
  List<PianoKey> keys = [];
  
  // Note pattern: C, C#, D, D#, E, F, F#, G, G#, A, A#, B
  const noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
  const blackKeyPattern = [false, true, false, true, false, false, true, false, true, false, true, false];
  
  // A0 = 27.5 Hz, MIDI note 21
  // Formula: freq = 440 * 2^((midi - 69) / 12)
  
  int keyNumber = 1;
  
  // Piano starts at A0 (not C0), so we need to handle the first partial octave
  // A0, A#0, B0 (keys 1-3)
  for (int i = 9; i < 12; i++) { // A, A#, B in octave 0
    int midiNote = 21 + (i - 9); // MIDI 21 = A0
    double freq = 440.0 * pow(2, (midiNote - 69) / 12);
    keys.add(PianoKey(noteNames[i], 0, freq, keyNumber++, blackKeyPattern[i]));
  }
  
  // Full octaves 1-7 (C1 to B7)
  for (int octave = 1; octave <= 7; octave++) {
    for (int i = 0; i < 12; i++) {
      int midiNote = 12 + (octave * 12) + i; // C1 = MIDI 24
      double freq = 440.0 * pow(2, (midiNote - 69) / 12);
      keys.add(PianoKey(noteNames[i], octave, freq, keyNumber++, blackKeyPattern[i]));
    }
  }
  
  // Last note: C8 (key 88)
  double freqC8 = 440.0 * pow(2, (108 - 69) / 12); // MIDI 108 = C8
  keys.add(PianoKey("C", 8, freqC8, keyNumber, false));
  
  return keys;
}

final List<PianoKey> pianoKeys = generatePianoKeys();

const List<GuitarString> standardGuitarTuning = [
  GuitarString("E", 2, 82.41, 6),
  GuitarString("A", 2, 110.00, 5),
  GuitarString("D", 3, 146.83, 4),
  GuitarString("G", 3, 196.00, 3),
  GuitarString("B", 3, 246.94, 2),
  GuitarString("E", 4, 329.63, 1),
];

class TunerScreen extends StatefulWidget {
  @override
  _TunerScreenState createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  final _audioRecorder = FlutterAudioCapture();
  final _engine = AudioEngine();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  double _currentPitch = 0.0;
  String _note = "--";
  int _octave = 0;
  double _cents = 0.0;
  String _status = "Initializing...";
  bool _isRecording = false;
  bool _isInitialized = false;
  
  // Seismograph trace data
  final Queue<PitchPoint> _pitchHistory = Queue<PitchPoint>();
  static const int _maxHistoryPoints = 100;
  
  // Tuning mode
  TuningMode _tuningMode = TuningMode.chromatic;
  GuitarString? _selectedGuitarString;
  PianoKey? _selectedPianoKey;
  
  // Scroll controller for piano keyboard
  final ScrollController _pianoScrollController = ScrollController();
  
  bool _wasRecordingBeforePause = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAudio();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
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
        setState(() {
          _status = "Tap to Start";
        });
      } catch (e) {
        setState(() {
          _status = "Init error: $e";
        });
      }
    } else {
      setState(() {
        _status = "Microphone permission denied";
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pianoScrollController.dispose();
    if (_isRecording) {
      _audioRecorder.stop();
    }
    super.dispose();
  }

  Future<void> _startCapture() async {
    if (!_isInitialized) {
      setState(() {
        _status = "Not initialized yet";
      });
      return;
    }
    
    // Clear history when starting
    _pitchHistory.clear();
    
    try {
      await _audioRecorder.start(
        (data) {
          List<double> buffer = data.map((e) => e.toDouble()).toList();
          double pitch = _engine.processAudio(buffer);

          if (pitch > 20 && pitch < 5000) {
            _calculateNote(pitch);
          }
        }, 
        onError, 
        sampleRate: 44100, 
        bufferSize: 4096
      );
      setState(() {
        _isRecording = true;
        _status = "Listening...";
      });
    } catch (e) {
      setState(() {
        _status = "Error: $e";
      });
    }
  }
  
  void onError(Object e) {
    print(e);
    setState(() {
      _status = "Error: $e";
    });
  }

  Future<void> _stopCapture() async {
    try {
      await _audioRecorder.stop();
    } catch (e) {
      // Ignore stop errors
    }
    setState(() {
      _isRecording = false;
      _status = "Paused";
      _note = "--";
      _currentPitch = 0.0;
      _cents = 0.0;
    });
  }

  void _calculateNote(double freq) {
    if (freq <= 0) return;

    double midi = 12 * (log(freq / 440.0) / log(2)) + 69;
    int midiRounded = midi.round();
    double cents = (midi - midiRounded) * 100;

    const List<String> notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
    
    int octave = (midiRounded / 12).floor() - 1;
    int noteIndex = midiRounded % 12;
    String noteName = notes[noteIndex];

    // In guitar mode with a target string, calculate cents relative to target
    if (_tuningMode == TuningMode.guitar && _selectedGuitarString != null) {
      double targetFreq = _selectedGuitarString!.frequency;
      
      // Calculate cents difference from target frequency
      double rawCents = 1200 * (log(freq / targetFreq) / log(2));
      
      // Clamp to visible range but allow showing "way off" notes at the edges
      cents = rawCents.clamp(-100.0, 100.0);
      
      // In guitar mode, show the target note info, not the detected note
      // But if we're way off (>200 cents = 2 semitones), show detected note
      if (rawCents.abs() <= 200) {
        noteName = _selectedGuitarString!.name;
        octave = _selectedGuitarString!.octave;
      }
    }
    
    // In piano mode with a target key, calculate cents relative to target
    if (_tuningMode == TuningMode.piano && _selectedPianoKey != null) {
      double targetFreq = _selectedPianoKey!.frequency;
      
      // Calculate cents difference from target frequency
      double rawCents = 1200 * (log(freq / targetFreq) / log(2));
      
      // Clamp to visible range
      cents = rawCents.clamp(-100.0, 100.0);
      
      // Show target note info if close enough
      if (rawCents.abs() <= 200) {
        noteName = _selectedPianoKey!.name;
        octave = _selectedPianoKey!.octave;
      }
    }
    
    // Add to history for seismograph trace
    _pitchHistory.addLast(PitchPoint(cents, noteName, octave, DateTime.now()));
    while (_pitchHistory.length > _maxHistoryPoints) {
      _pitchHistory.removeFirst();
    }
    
    if (mounted) {
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
    if (absCents < 5) return "In Tune ✓";
    if (_cents > 0) return "Sharp ↑";
    return "Flat ↓";
  }

  void _setTuningMode(TuningMode mode) {
    setState(() {
      _tuningMode = mode;
      _selectedGuitarString = null;
      _selectedPianoKey = null;
      _pitchHistory.clear();
    });
    Navigator.pop(context);
  }

  void _selectGuitarString(GuitarString guitarString) {
    setState(() {
      _selectedGuitarString = guitarString;
      _pitchHistory.clear();
    });
    if (!_isRecording && _isInitialized) {
      _startCapture();
    }
  }

  void _selectPianoKey(PianoKey key) {
    setState(() {
      _selectedPianoKey = key;
      _pitchHistory.clear();
    });
    if (!_isRecording && _isInitialized) {
      _startCapture();
    }
  }

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
            ? "Chromatic Tuner" 
            : _tuningMode == TuningMode.guitar 
              ? "Guitar Tuner"
              : "Piano Tuner",
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
              gradient: LinearGradient(
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.music_note, color: Colors.greenAccent, size: 32),
                ),
                const SizedBox(height: 12),
                const Text(
                  "PreciseTuner",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Text(
                  "Select Instrument",
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ),
          _buildDrawerItem(
            icon: Icons.graphic_eq,
            title: "Chromatic",
            subtitle: "Detect any note",
            isSelected: _tuningMode == TuningMode.chromatic,
            onTap: () => _setTuningMode(TuningMode.chromatic),
          ),
          _buildDrawerItem(
            icon: Icons.music_note,
            title: "Guitar",
            subtitle: "Standard tuning (EADGBe)",
            isSelected: _tuningMode == TuningMode.guitar,
            onTap: () => _setTuningMode(TuningMode.guitar),
          ),
          _buildDrawerItem(
            icon: Icons.piano,
            title: "Piano",
            subtitle: "Full range (A0-C8)",
            isSelected: _tuningMode == TuningMode.piano,
            onTap: () => _setTuningMode(TuningMode.piano),
          ),
          const Divider(color: Colors.white24),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "Tip: For piano tuning, mute adjacent strings and tune one at a time.",
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.greenAccent : Colors.white54),
      title: Text(title, style: TextStyle(color: isSelected ? Colors.greenAccent : Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      selected: isSelected,
      selectedTileColor: Colors.greenAccent.withOpacity(0.1),
      onTap: onTap,
    );
  }

  Widget _buildChromaticTunerBody() {
    // In chromatic mode, just show detected note (no "target")
    String detectedNote = _isRecording && _note != "--" 
      ? "$_note$_octave" 
      : "--";
    
    return Column(
      children: [
        const SizedBox(height: 10),
        // Detected note display (large)
        Text(
          detectedNote,
          style: TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.bold,
            color: _isRecording && _note != "--" ? _getTuningColor() : Colors.white38,
          ),
        ),
        if (_isRecording && _currentPitch > 0)
          Text(
            "${_currentPitch.toStringAsFixed(1)} Hz",
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),
        const SizedBox(height: 10),
        // Seismograph visualization
        Expanded(
          child: _buildSeismograph(),
        ),
        // Tuning status
        _buildTuningStatusBar(),
        const SizedBox(height: 10),
        // Controls
        _buildControls(),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildGuitarTunerBody() {
    return Column(
      children: [
        const SizedBox(height: 10),
        // Guitar headstock
        _buildGuitarHeadstock(),
        const SizedBox(height: 10),
        // Target info
        if (_selectedGuitarString != null) ...[
          Text(
            "Target: ${_selectedGuitarString!.fullName} (${_selectedGuitarString!.frequency.toStringAsFixed(2)} Hz)",
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ] else ...[
          const Text(
            "Select a string to tune",
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
        const SizedBox(height: 10),
        // Seismograph visualization
        Expanded(
          child: _buildSeismograph(),
        ),
        // Tuning status
        _buildTuningStatusBar(),
        const SizedBox(height: 10),
        // Controls
        _buildControls(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPianoTunerBody() {
    return Column(
      children: [
        const SizedBox(height: 10),
        // Piano keyboard
        _buildPianoKeyboard(),
        const SizedBox(height: 10),
        // Target info
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
        // Seismograph visualization
        Expanded(
          child: _buildSeismograph(),
        ),
        // Tuning status
        _buildTuningStatusBar(),
        const SizedBox(height: 10),
        // Controls
        _buildControls(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPianoKeyboard() {
    // Get only white keys for positioning
    final whiteKeys = pianoKeys.where((k) => !k.isBlack).toList();
    final blackKeys = pianoKeys.where((k) => k.isBlack).toList();
    
    const double whiteKeyWidth = 44.0;
    const double whiteKeyHeight = 120.0;
    const double blackKeyWidth = 28.0;
    const double blackKeyHeight = 75.0;
    
    return Container(
      height: whiteKeyHeight + 20,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: SingleChildScrollView(
        controller: _pianoScrollController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: whiteKeys.length * whiteKeyWidth,
          height: whiteKeyHeight + 20,
          child: Stack(
            children: [
              // White keys layer
              Row(
                children: whiteKeys.map((key) {
                  bool isSelected = _selectedPianoKey == key;
                  bool isInTune = isSelected && _isRecording && _cents.abs() < 5;
                  
                  return GestureDetector(
                    onTap: () => _selectPianoKey(key),
                    child: Container(
                      width: whiteKeyWidth - 2,
                      height: whiteKeyHeight,
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: isSelected 
                          ? (isInTune ? Colors.greenAccent : Colors.amber.shade200)
                          : Colors.white,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                        border: Border.all(
                          color: isSelected ? Colors.amber : Colors.grey.shade400,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            key.name,
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.grey.shade700,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${key.octave}",
                            style: TextStyle(
                              color: isSelected ? Colors.black54 : Colors.grey.shade500,
                              fontSize: 9,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "${key.keyNumber}",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              // Black keys layer (positioned on top)
              ...blackKeys.map((key) {
                // Find the position based on white key before this black key
                int whiteKeyIndex = _getWhiteKeyIndexBeforeBlackKey(key);
                double leftPosition = (whiteKeyIndex + 1) * whiteKeyWidth - (blackKeyWidth / 2) - 1;
                
                bool isSelected = _selectedPianoKey == key;
                bool isInTune = isSelected && _isRecording && _cents.abs() < 5;
                
                return Positioned(
                  left: leftPosition,
                  top: 0,
                  child: GestureDetector(
                    onTap: () => _selectPianoKey(key),
                    child: Container(
                      width: blackKeyWidth,
                      height: blackKeyHeight,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isSelected
                            ? (isInTune 
                                ? [Colors.green.shade700, Colors.green.shade900]
                                : [Colors.amber.shade700, Colors.amber.shade900])
                            : [Colors.grey.shade800, Colors.black],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                        border: Border.all(
                          color: isSelected ? Colors.amber : Colors.black,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 4,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            key.name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey.shade400,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${key.keyNumber}",
                            style: TextStyle(
                              color: isSelected ? Colors.white70 : Colors.grey.shade500,
                              fontSize: 7,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  int _getWhiteKeyIndexBeforeBlackKey(PianoKey blackKey) {
    // Find the white key that comes before this black key
    final whiteKeys = pianoKeys.where((k) => !k.isBlack).toList();
    
    for (int i = 0; i < whiteKeys.length; i++) {
      final whiteKey = whiteKeys[i];
      // Black keys come after: C, D, F, G, A (C#, D#, F#, G#, A#)
      if (whiteKey.octave == blackKey.octave) {
        if (blackKey.name == "C#" && whiteKey.name == "C") return i;
        if (blackKey.name == "D#" && whiteKey.name == "D") return i;
        if (blackKey.name == "F#" && whiteKey.name == "F") return i;
        if (blackKey.name == "G#" && whiteKey.name == "G") return i;
        if (blackKey.name == "A#" && whiteKey.name == "A") return i;
      }
      // Handle A#0 which is in octave 0
      if (blackKey.octave == 0 && blackKey.name == "A#" && whiteKey.octave == 0 && whiteKey.name == "A") {
        return i;
      }
    }
    return 0;
  }

  Widget _buildSeismograph() {
    // Get target note display - only show for guitar/piano mode with selection
    String targetNote = "";
    if (_tuningMode == TuningMode.guitar && _selectedGuitarString != null) {
      targetNote = _selectedGuitarString!.fullName;
    } else if (_tuningMode == TuningMode.piano && _selectedPianoKey != null) {
      targetNote = _selectedPianoKey!.fullName;
    }
    // In chromatic mode, no target - just detecting notes
    
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
            pitchHistory: _pitchHistory.toList(),
            targetNote: targetNote,
            isActive: _isRecording,
            currentCents: _cents,
            currentNote: _note,
            currentOctave: _octave,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }

  Widget _buildTuningStatusBar() {
    String status = _getTuningStatus();
    String centsText = _cents >= 0 ? "+${_cents.toStringAsFixed(1)}" : _cents.toStringAsFixed(1);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
                _isRecording && _note != "--" ? "$centsText" : "--",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _isRecording && _note != "--" ? _getTuningColor() : Colors.white38,
                ),
              ),
              const Text(
                "cents",
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white12,
          ),
          Column(
            children: [
              Text(
                status.isEmpty ? "--" : status,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _isRecording && _note != "--" ? _getTuningColor() : Colors.white38,
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

  Widget _buildGuitarHeadstock() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D44),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          const Text(
            "Tap a string to tune",
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTunerPeg(standardGuitarTuning[0]),
                    _buildTunerPeg(standardGuitarTuning[1]),
                    _buildTunerPeg(standardGuitarTuning[2]),
                  ],
                ),
                const SizedBox(width: 16),
                Container(
                  width: 50,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A3728), Color(0xFF2E2218)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) {
                      return Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        color: index < 3 
                          ? Colors.amber.shade700 
                          : Colors.grey.shade400,
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTunerPeg(standardGuitarTuning[3]),
                    _buildTunerPeg(standardGuitarTuning[4]),
                    _buildTunerPeg(standardGuitarTuning[5]),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTunerPeg(GuitarString guitarString) {
    bool isSelected = _selectedGuitarString == guitarString;
    bool isInTune = isSelected && _isRecording && _cents.abs() < 5;
    
    return GestureDetector(
      onTap: () => _selectGuitarString(guitarString),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            guitarString.fullName,
            style: TextStyle(
              color: isSelected 
                ? (isInTune ? Colors.greenAccent : Colors.amber) 
                : Colors.white54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected 
                ? (isInTune ? Colors.greenAccent : Colors.amber)
                : const Color(0xFF4A4A5A),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.white24,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: (isInTune ? Colors.greenAccent : Colors.amber).withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ] : null,
            ),
            child: Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.black : Colors.white24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Column(
      children: [
        Text(
          _status,
          style: const TextStyle(fontSize: 14, color: Colors.white54),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _isRecording ? _stopCapture : _startCapture,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isRecording ? Colors.red : Colors.greenAccent,
              boxShadow: [
                BoxShadow(
                  color: (_isRecording ? Colors.red : Colors.greenAccent).withOpacity(0.4),
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
        ),
      ],
    );
  }
}

// Seismograph-style painter
class SeismographPainter extends CustomPainter {
  final List<PitchPoint> pitchHistory;
  final String targetNote;
  final bool isActive;
  final double currentCents;
  final String currentNote;
  final int currentOctave;

  SeismographPainter({
    required this.pitchHistory,
    required this.targetNote,
    required this.isActive,
    required this.currentCents,
    required this.currentNote,
    required this.currentOctave,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    // Background gradient
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF0D0D1A),
          const Color(0xFF151528),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    
    // Draw horizontal guide lines
    final guidePaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;
    
    for (int i = 1; i < 5; i++) {
      double y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guidePaint);
    }
    
    // Draw vertical center line (perfect pitch line)
    final centerLinePaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.6)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, size.height),
      centerLinePaint,
    );
    
    // Draw green zone around center (±5 cents = in tune)
    final greenZoneWidth = size.width * 0.05; // 5% of width for ±5 cents
    final greenZonePaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.1);
    canvas.drawRect(
      Rect.fromLTWH(centerX - greenZoneWidth, 0, greenZoneWidth * 2, size.height),
      greenZonePaint,
    );
    
    // Draw target note label at top center (only if there's a target)
    if (targetNote.isNotEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: targetNote,
          style: TextStyle(
            color: Colors.greenAccent.withOpacity(0.8),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(centerX - textPainter.width / 2, 10),
      );
    }
    
    // Draw "FLAT" and "SHARP" labels
    final flatPainter = TextPainter(
      text: TextSpan(
        text: "← FLAT",
        style: TextStyle(
          color: Colors.white.withOpacity(0.3),
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    flatPainter.layout();
    flatPainter.paint(canvas, Offset(20, size.height - 25));
    
    final sharpPainter = TextPainter(
      text: TextSpan(
        text: "SHARP →",
        style: TextStyle(
          color: Colors.white.withOpacity(0.3),
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    sharpPainter.layout();
    sharpPainter.paint(canvas, Offset(size.width - sharpPainter.width - 20, size.height - 25));
    
    if (!isActive || pitchHistory.isEmpty) return;
    
    // Draw the trace path
    final tracePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final path = Path();
    final pointSpacing = size.width / 100; // Spread points across width
    
    for (int i = 0; i < pitchHistory.length; i++) {
      final point = pitchHistory[i];
      // Map cents (-100 to +100) to x position
      // -100 cents = left edge, +100 cents = right edge
      final x = centerX + (point.cents / 100) * (size.width / 2 - 40);
      // y position based on time (older points at top, newer at bottom)
      final y = (i / pitchHistory.length) * (size.height - 80) + 40;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, tracePaint);
    
    // Draw the current position circle (floating note bubble)
    if (pitchHistory.isNotEmpty) {
      final lastPoint = pitchHistory.last;
      final currentX = centerX + (lastPoint.cents / 100) * (size.width / 2 - 40);
      final currentY = size.height - 60;
      
      // Determine color based on how in-tune we are
      Color bubbleColor;
      double absCents = lastPoint.cents.abs();
      if (absCents < 5) {
        bubbleColor = Colors.greenAccent;
      } else if (absCents < 15) {
        bubbleColor = Colors.yellowAccent;
      } else {
        bubbleColor = Colors.redAccent;
      }
      
      // Glow effect
      final glowPaint = Paint()
        ..color = bubbleColor.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
      canvas.drawCircle(Offset(currentX, currentY), 30, glowPaint);
      
      // Main bubble
      final bubblePaint = Paint()
        ..color = bubbleColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(currentX, currentY), 25, bubblePaint);
      
      // Border
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(currentX, currentY), 25, borderPaint);
      
      // Note text inside bubble
      final notePainter = TextPainter(
        text: TextSpan(
          text: "${lastPoint.note}${lastPoint.octave}",
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      notePainter.layout();
      notePainter.paint(
        canvas,
        Offset(currentX - notePainter.width / 2, currentY - notePainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(SeismographPainter oldDelegate) {
    return oldDelegate.pitchHistory.length != pitchHistory.length ||
        oldDelegate.isActive != isActive ||
        oldDelegate.currentCents != currentCents ||
        oldDelegate.targetNote != targetNote;
  }
}