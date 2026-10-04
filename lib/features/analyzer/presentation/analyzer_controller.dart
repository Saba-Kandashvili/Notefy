import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/analyzer_service.dart';

class AnalyzerController extends ChangeNotifier {
  final AnalyzerService _service;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isSweeping = false;
  bool get isSweeping => _isSweeping;

  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;

  double _sweepDuration = 10.0;
  double get sweepDuration => _sweepDuration;

  Timer? _sweepTimer;
  double _currentSweepFreq = 20.0;
  double get currentSweepFreq => _currentSweepFreq;

  List<DataPoint> _results = [];
  List<DataPoint> get results => _results;

  InputDevice? _selectedMicrophone;
  InputDevice? get selectedMicrophone => _selectedMicrophone;

  AnalyzerController({AnalyzerService? service}) : _service = service ?? AnalyzerService() {
    _init();
  }

  Future<void> _init() async {
    _isInitialized = await _service.initialize();
    notifyListeners();
  }

  void setDuration(double duration) {
    _sweepDuration = duration;
    notifyListeners();
  }

  void setMicrophone(InputDevice? device) {
    _selectedMicrophone = device;
    notifyListeners();
  }

  Future<void> startAnalysis() async {
    if (!_isInitialized || _isSweeping || _isAnalyzing) return;

    _results = [];
    _isSweeping = true;
    _currentSweepFreq = 20.0;
    
    final startTime = DateTime.now();
    _sweepTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final elapsed = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      if (elapsed > _sweepDuration) return;
      _currentSweepFreq = 20.0 * pow(20000.0 / 20.0, elapsed / _sweepDuration);
      notifyListeners();
    });
    
    notifyListeners();

    try {
      await _service.startSweep(_sweepDuration, _selectedMicrophone);
      
      _sweepTimer?.cancel();
      _isSweeping = false;
      _isAnalyzing = true;
      notifyListeners();

      _results = await _service.analyzeRecording(_sweepDuration);
    } catch (e) {
      debugPrint("Error during analysis: $e");
    } finally {
      _isSweeping = false;
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  Future<void> stopAnalysis() async {
    if (_isSweeping) {
      _sweepTimer?.cancel();
      await _service.stopSweep();
      _isSweeping = false;
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  List<FlSpot> getChartData() {
    return _results.map((point) => FlSpot(point.frequency, point.magnitudeDb)).toList();
  }

  Future<void> exportCsv() async {
    if (_results.isEmpty) return;

    StringBuffer sb = StringBuffer();
    sb.writeln("Frequency (Hz),Magnitude (dB)");
    for (var point in _results) {
      sb.writeln("${point.frequency.toStringAsFixed(2)},${point.magnitudeDb.toStringAsFixed(2)}");
    }

    String csvData = sb.toString();

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/frequency_response.csv';
    final file = File(path);
    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(path)], text: 'Frequency Response Data');
  }

  @override
  void dispose() {
    _sweepTimer?.cancel();
    _service.dispose();
    super.dispose();
  }
}
