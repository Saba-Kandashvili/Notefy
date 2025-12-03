import 'package:flutter/material.dart';

import 'audio_engine.dart'; // Import your engine

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: TunerHome());
  }
}

class TunerHome extends StatefulWidget {
  const TunerHome({super.key});

  @override
  _TunerHomeState createState() => _TunerHomeState();
}

class _TunerHomeState extends State<TunerHome> {
  final AudioEngine engine = AudioEngine();
  String status = "Not Tested";

  void testNativeCode() {
    try {
      // This calls C++!
      double result = engine.getPitch(0.0);
      setState(() {
        status = "Native C++ returned: $result Hz";
      });
    } catch (e) {
      setState(() {
        status = "Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(status),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: testNativeCode,
              child: Text("Test C++ Connection"),
            ),
          ],
        ),
      ),
    );
  }
}
