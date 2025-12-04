# Project Name: PreciseTuner (Native C++ Engine)

## 1. Executive Summary
We are building a professional-grade, chromatic instrument tuner for Android (and eventually iOS). The primary goal is to achieve **high-precision pitch detection** capable of tuning instruments ranging from guitars to pianos (low bass frequencies) with zero latency.

Unlike existing market solutions, this app will be:
*   **Ad-free and lightweight:** No Unity overhead, no bloatware.
*   **Mathematically precise:** Using industry-standard DSP (Digital Signal Processing) algorithms.
*   **High Performance:** Bypassing the Java/Dart Virtual Machine for audio processing.

## 2. Technical Architecture

To achieve maximum precision and speed, we utilize a **Hybrid Architecture**. We use **Flutter** for the UI and **C++** for the audio engine, connected via **Dart FFI (Foreign Function Interface)**.

### Why this stack?
1.  **Flutter (Dart):** Allows for rapid UI development and 60fps animations for the tuning needle.
2.  **C++:** Audio processing requires complex math (autocorrelation) run thousands of times per second. C++ is the industry standard for DSP because it offers direct memory management and SIMD optimizations, avoiding the "Garbage Collection pauses" that happen in Java or Dart.
3.  **Dart FFI:** Instead of using standard "Method Channels" (which serialize data and are slow), FFI allows Dart to call C++ functions **directly in memory**. This results in near-zero latency when passing audio buffers.

---

## 3. The Data Pipeline (How it works)

Here is the lifecycle of a single audio frame, from Microphone to UI:

### Step 1: Signal Acquisition (Dart Layer)
*   **Library:** `flutter_audio_capture`
*   **Format:** Raw PCM Data (Pulse Code Modulation).
*   **Type:** 32-bit Float (`List<double>`).
*   **Sample Rate:** 44,100 Hz (Standard Audio).
*   **Buffer Size:** 4096 samples (Selected to capture low frequencies for Piano A0).

### Step 2: The Bridge (FFI Layer)
*   Dart allocates a pointer in memory.
*   The raw audio data is copied into this memory block.
*   Dart passes the **memory address (pointer)** to the C++ function `detect_pitch()`.

### Step 3: The Engine (C++ Layer)
The C++ engine receives the pointer. It does **not** use FFT (Fast Fourier Transform), as FFT is imprecise for tuning instruments. Instead, it uses the **YIN Algorithm**.

**The YIN Algorithm Logic:**
1.  **Autocorrelation:** Compares the signal with a time-shifted version of itself to find periodicity.
2.  **Difference Function:** Calculates the error rate for different pitches.
3.  **Absolute Threshold:** Finds the first "dip" in error that is significant (ignoring false positives).
4.  **Parabolic Interpolation:** This is key for precision. Since digital audio is "stepped," the true peak might fall *between* two samples. We use calculus to estimate the curve between steps to find the exact fractional frequency (e.g., 440.02Hz vs 440.0Hz).

### Step 4: UI Feedback (Dart Layer)
*   C++ returns a `float` (e.g., `82.41`).
*   Dart converts `82.41 Hz` -> **E2** (Low E String).
*   Dart calculates "Cents" (how far off the note is) and updates the visual needle.

---

## 4. Development Environment Setup

If you are a new developer cloning this repo, follow these steps to compile the native engine.

### Prerequisites
1.  **Flutter SDK** (Latest Stable).
2.  **Android SDK & NDK (Side-by-side):**
    *   Open Android Studio -> SDK Manager -> SDK Tools -> Check "NDK (Side by side)" and "CMake".

### Directory Structure
*   `lib/` -> Contains all UI code and the Dart `AudioEngine` wrapper.
*   `android/app/src/main/cpp/` -> Contains the **C++ Source code**.
    *   `native_tuner.cpp`: The implementation of the YIN algorithm.
    *   `CMakeLists.txt`: Instructions for the compiler on how to build the `.so` library.

### Compilation
The C++ code is compiled automatically by Gradle.
1.  Run `flutter clean` (Removes old binaries).
2.  Run `flutter pub get`.
3.  Run `flutter run` (This triggers the NDK build process).

---

## 5. Goals & Roadmap

### Phase 1: MVP (Completed)
*   [x] Establish FFI bridge between Dart and C++.
*   [x] Implement basic YIN algorithm in C++.
*   [x] Get microphone stream in Flutter.

### Phase 2: Refinement (Current Focus)
*   [ ] Optimize C++ memory usage (remove `malloc` inside the loop).
*   [ ] Implement specific "Guitar Mode" vs "Piano Mode" (filtering frequencies).
*   [ ] Add a "Noise Gate" (don't detect pitch if volume is too low).

### Phase 3: Polish
*   [ ] Smooth the UI needle movement (moving average/smoothing filter).
*   [ ] Compile support for iOS (`.dylib` vs `.so`).

---

## 6. Mathematical Reference
For the curious developer, we are using the formula:
$$ Note = 12 \times \log_2(\frac{f}{440}) + 69 $$
Where $f$ is the frequency returned by our C++ engine.
