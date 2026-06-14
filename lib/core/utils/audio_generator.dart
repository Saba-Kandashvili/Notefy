import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class AudioGenerator {
  static const int sampleRate = 44100;
  static const double duration = 1.5;
  static const double volume = 32767.0 * 0.5;
  static const List<String> noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

  /// Generates the WAV files in the app's document directory if they don't exist.
  /// Returns the path to the notes directory.
  static Future<String> ensureNotesGenerated() async {
    final dir = await getApplicationDocumentsDirectory();
    final notesDir = Directory('${dir.path}/notes');
    if (!await notesDir.exists()) {
      await notesDir.create(recursive: true);
    }

    for (int midi = 40; midi <= 88; midi++) {
      int octave = (midi ~/ 12) - 1;
      String noteName = noteNames[midi % 12];
      String filename = "$noteName$octave.wav".replaceAll('#', 's');
      File file = File('${notesDir.path}/$filename');
      
      if (!await file.exists()) {
        await _generateNoteFile(midi, file);
      }
    }
    
    return notesDir.path;
  }

  static Future<void> _generateNoteFile(int midi, File file) async {
    double freq = 440.0 * pow(2.0, (midi - 69) / 12.0);
    int numSamples = (sampleRate * duration).toInt();
    
    // WAV Header
    int byteRate = sampleRate * 1 * 2; 
    
    var dataBytes = BytesBuilder(copy: false);
    
    // Generate PCM data
    for (int i = 0; i < numSamples; i++) {
      double t = i / sampleRate;
      double envelope = exp(-t * 3.0);
      
      double fundamental = sin(2.0 * pi * freq * t);
      double harm1 = 0.5 * sin(2.0 * pi * freq * 2 * t);
      double harm2 = 0.25 * sin(2.0 * pi * freq * 3 * t);
      double harm3 = 0.125 * sin(2.0 * pi * freq * 4 * t);
      
      double signal = (fundamental + harm1 + harm2 + harm3) / 1.875;
      
      int value = (envelope * volume * signal).toInt();
      if (value > 32767) value = 32767;
      if (value < -32768) value = -32768;
      
      dataBytes.addByte(value & 0xFF);
      dataBytes.addByte((value >> 8) & 0xFF);
    }
    
    final rawData = dataBytes.takeBytes();
    
    var header = BytesBuilder();
    // RIFF chunk descriptor
    header.add("RIFF".codeUnits);
    _addInt32(header, 36 + rawData.length); // ChunkSize
    header.add("WAVE".codeUnits);
    
    // "fmt " sub-chunk
    header.add("fmt ".codeUnits);
    _addInt32(header, 16); // Subchunk1Size
    _addInt16(header, 1); // AudioFormat
    _addInt16(header, 1); // NumChannels
    _addInt32(header, sampleRate); // SampleRate
    _addInt32(header, byteRate); // ByteRate
    _addInt16(header, 2); // BlockAlign
    _addInt16(header, 16); // BitsPerSample
    
    // "data" sub-chunk
    header.add("data".codeUnits);
    _addInt32(header, rawData.length); // Subchunk2Size
    
    final fullFile = BytesBuilder(copy: false);
    fullFile.add(header.takeBytes());
    fullFile.add(rawData);
    
    await file.writeAsBytes(fullFile.takeBytes());
  }

  static void _addInt32(BytesBuilder builder, int value) {
    builder.addByte(value & 0xFF);
    builder.addByte((value >> 8) & 0xFF);
    builder.addByte((value >> 16) & 0xFF);
    builder.addByte((value >> 24) & 0xFF);
  }

  static void _addInt16(BytesBuilder builder, int value) {
    builder.addByte(value & 0xFF);
    builder.addByte((value >> 8) & 0xFF);
  }
}
