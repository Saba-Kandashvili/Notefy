import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:fftea/fftea.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/audio_engine.dart';

class DataPoint {
  final double frequency;
  final double magnitudeDb;

  DataPoint(this.frequency, this.magnitudeDb);
}

class AnalyzerService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioEngine _engine = AudioEngine();
  StreamSubscription<Uint8List>? _audioStreamSubscription;

  bool _isRecording = false;
  final List<double> _recordingBuffer = [];

  Future<bool> initialize() async {
    return await _audioRecorder.hasPermission();
  }

  Future<void> startSweep(double durationSecs, InputDevice? selectedDevice) async {
    _recordingBuffer.clear();
    _isRecording = true;

    // Start Recording
    final stream = await _audioRecorder.startStream(RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 44100, // Standard high-res
      numChannels: 1,
      device: selectedDevice,
      autoGain: false,      // Need raw accuracy
      echoCancel: false,    // No processing!
      noiseSuppress: false, // Pure signal!
    ));

    _audioStreamSubscription = stream.listen((Uint8List data) {
      if (!_isRecording) return;
      final floatData = _convertToFloat32List(data);
      _recordingBuffer.addAll(floatData);
    });

    // Start Sweep
    _engine.synthStart(waveform: 0, frequency: 20.0); // Sine wave at 20Hz
    _engine.synthSweep(endFreq: 20000.0, durationSec: durationSecs, loop: false);

    // Wait for sweep to finish (+ half a sec padding to catch the tail)
    await Future.delayed(Duration(milliseconds: (durationSecs * 1000).toInt() + 500));

    await stopSweep();
  }

  Future<void> stopSweep() async {
    if (!_isRecording) return;
    _isRecording = false;
    _engine.synthStop();
    _engine.synthStopSweep();
    await _audioStreamSubscription?.cancel();
    await _audioRecorder.stop();
  }

  double getCurrentSweepFrequency() {
    return _engine.synthGetFrequency();
  }

  // Heavy task - run in isolate
  Future<List<DataPoint>> analyzeRecording(double sweepDuration) async {
    // Copy buffer so we don't accidentally mutate it on the main thread
    final buffer = List<double>.from(_recordingBuffer);
    if (buffer.isEmpty) return [];

    return await compute(_processFftOffline, {
      'buffer': buffer,
      'duration': sweepDuration,
    });
  }

  Float32List _convertToFloat32List(Uint8List pcm16Data) {
    final byteData = ByteData.view(pcm16Data.buffer, pcm16Data.offsetInBytes, pcm16Data.lengthInBytes);
    final floatList = Float32List(pcm16Data.lengthInBytes ~/ 2);
    for (int i = 0; i < floatList.length; i++) {
      floatList[i] = byteData.getInt16(i * 2, Endian.host) / 32768.0;
    }
    return floatList;
  }

  void dispose() {
    stopSweep();
    _audioRecorder.dispose();
    _engine.dispose();
  }
}

// Global top-level function for Isolate (compute)
List<DataPoint> _processFftOffline(Map<String, dynamic> args) {
  final List<double> buffer = args['buffer'];
  final double sweepDuration = args['duration'];
  
  final int sampleRate = 44100;
  final int chunkSize = 8192;
  
  if (buffer.length < chunkSize) return [];

  final int numBins = chunkSize ~/ 2;
  final window = Window.hanning(chunkSize);
  final stft = STFT(chunkSize, window);

  final int stepSize = chunkSize ~/ 2;
  final List<DataPoint> results = [];
  
  for (int i = 0; i < buffer.length - chunkSize; i += stepSize) {
    final double t = i / sampleRate;
    
    // Stop processing slightly before the end to avoid the loud "click" 
    // transient when the audio synthesizer abruptly stops.
    if (t > sweepDuration - 0.1) continue;
    
    // Calculate expected frequency at time t (Exponential sweep)
    final double expectedFreq = 20.0 * pow(20000.0 / 20.0, t / sweepDuration);
    
    // Create a tighter sliding bandpass window: +/- 20% of expected frequency.
    // The previous +/- 1 octave (0.5 to 2.0) was too wide at high frequencies (10kHz-20kHz),
    // which caused it to pick up broadband high-frequency noise and jump up.
    // +/- 20% is tight enough to block noise, but wide enough to easily catch up to ~500ms of Bluetooth latency.
    final int minBin = max(0, (expectedFreq * 0.8 * chunkSize / sampleRate).floor());
    final int maxBin = min(numBins - 1, (expectedFreq * 1.2 * chunkSize / sampleRate).ceil());
    
    final chunk = buffer.sublist(i, i + chunkSize);
    
    stft.run(chunk, (Float64x2List freqData) {
      double maxMagSq = 0;
      for (int bin = minBin; bin <= maxBin; bin++) {
        final val = freqData[bin];
        final magSq = val.x * val.x + val.y * val.y;
        if (magSq > maxMagSq) {
          maxMagSq = magSq;
        }
      }
      
      final mag = sqrt(maxMagSq);
      double magnitudeDb = -100.0;
      
      if (mag > 0.000001) {
        magnitudeDb = 20 * log(mag) / ln10;
      }
      
      if (magnitudeDb > -80.0) {
        results.add(DataPoint(expectedFreq, magnitudeDb));
      }
    });
  }

  return _smoothDataPoints(results);
}

List<DataPoint> _smoothDataPoints(List<DataPoint> data) {
  // Simple moving average to remove jitter
  final List<DataPoint> smoothed = [];
  final int windowSize = 5;

  for (int i = 0; i < data.length; i++) {
    int start = max(0, i - windowSize);
    int end = min(data.length - 1, i + windowSize);
    
    double sumDb = 0;
    int count = 0;
    for (int j = start; j <= end; j++) {
      sumDb += data[j].magnitudeDb;
      count++;
    }
    
    smoothed.add(DataPoint(data[i].frequency, sumDb / count));
  }
  
  // Further decimate points so the chart doesn't lag rendering thousands of points.
  // E.g., keeping only one point per N hz step, or just taking 300 points.
  if (smoothed.length > 500) {
    final int step = smoothed.length ~/ 300;
    final List<DataPoint> decimated = [];
    for (int i = 0; i < smoothed.length; i += step) {
      decimated.add(smoothed[i]);
    }
    return decimated;
  }

  return smoothed;
}
