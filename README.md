# Notefy

![License](https://img.shields.io/badge/License-CC_BY_NC_SA_4.0-lightgrey.svg)
![Platform](https://img.shields.io/badge/Platform-Android-green.svg)

Notefy is a high-precision, chromatic instrument tuner application for Android. It utilizes a hybrid architecture, combining a Flutter-based user interface with a native C++ audio engine to achieve low-latency pitch detection.

Unlike standard tuner applications that rely on FFT (Fast Fourier Transform) within the managed runtime, Notefy implements the **YIN Algorithm** in unmanaged C++ to solve specific physics challenges associated with tuning instruments, such as inharmonicity and low-frequency detection on mobile hardware.

## Features

- **Hybrid Audio Engine:** Audio processing is offloaded to a compiled C++ shared library via Dart FFI (Foreign Function Interface), bypassing the Dart/Java VM garbage collector for real-time performance.
- **YIN Algorithm:** Implements autocorrelation, difference function, and parabolic interpolation to calculate the fundamental frequency with high precision.
- **Customizable Tuning:**
  - Dynamic headstock generation supporting arbitrary string counts (6, 7, 8, 12, etc.).
  - Supports single-side (Ibanez/Fender style) and dual-side (Gibson style) layouts.
  - User-definable frequency presets.
- **Instrument Modes:**
  - **Guitar:** Custom string selection and visualization.
  - **Piano:** Full 88-key range detection (A0 to C8), optimized for bass frequencies down to 27.5Hz.
- **Seismograph Visualization:** Provides a rolling history of pitch stability to assist with intonation setup.
- **Privacy Focused:** Completely offline operation. No analytics, no ads, and no data collection.

## Technical Architecture

Notefy processes audio using the following pipeline:

1.  **Signal Acquisition:** `flutter_audio_capture` retrieves the raw PCM audio stream (Float32 format) from the Android hardware layer.
2.  **FFI Bridge:** Dart allocates a memory pointer and passes the raw audio buffer directly to the C++ native library (`libnative_tuner.so`).
3.  **Signal Processing (C++):**
    - **Noise Gate:** Applies a hysteresis filter to ignore background noise.
    - **YIN Algorithm:** Calculates pitch estimation.
    - **Parabolic Interpolation:** Refines the estimate to find the exact fractional frequency.
4.  **UI Rendering:** The calculated frequency is returned to the Flutter UI layer to update the needle and seismograph at 60fps.

### Project Structure

- `lib/` - Dart/Flutter application code.
  - `audio_engine.dart` - FFI bindings connecting Dart to C++.
  - `tuning_model.dart` - Data models for presets and frequency calculations.
  - `components/` - Custom painters and procedural UI widgets.
- `android/app/src/main/cpp/` - Native C++ source code.
  - `notefy.cpp` - Implementation of the DSP algorithms.
  - `CMakeLists.txt` - Build configuration for the Android NDK.

## Setup and Installation

### Prerequisites

- Flutter SDK (Latest Stable)
- Android SDK
- Android NDK (Native Development Kit) & CMake

### Build Instructions

1.  Clone the repository:

    ```bash
    git clone https://github.com/sabak/notefy.git
    cd notefy
    ```

2.  Install Dart dependencies:

    ```bash
    flutter pub get
    ```

3.  Build and Run:
    ```bash
    flutter run
    ```
    _Note: The initial build may take longer than usual as Gradle compiles the C++ native library._

## License & Commercial Use

This project is licensed under the **Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)** license.

**Summary of Terms:**

- **Non-Commercial:** You are **strictly prohibited** from using this source code, assets, or the application itself for commercial purposes. You cannot sell the app, sell modified versions, or monetize the app via advertisements.
- **Attribution:** You must give appropriate credit to the original author (Saba Kandashvili) if you redistribute or modify the code.
- **ShareAlike:** If you remix, transform, or build upon the material, you must distribute your contributions under the same license as the original.

See the `LICENSE` file for the full legal text.
