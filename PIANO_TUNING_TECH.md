# Piano Tuning & Inharmonicity Implementation

This document provides a detailed technical and conceptual explanation of the professional piano tuning feature implemented in **Notefy**. It covers the physics of piano strings, the mathematical models used, and the implementation details in C++ and Dart.

---

## 1. Conceptual Level: The Physics of Piano Tuning

### Why Pianos Aren't Tuned to Perfect Frequencies
In theory, every note on a musical instrument follows a harmonic series: a fundamental frequency ($f_1$) and its overtones ($f_2, f_3, \dots$) which are exact integer multiples ($2f_1, 3f_1, \dots$). 

However, **piano strings are not ideal "mathematical" strings.** Because they are made of stiff steel (and often wound with copper in the bass), they behave slightly like physical bars. This stiffness causes the higher harmonics (partials) to vibrate **faster** than the theoretical integer multiples. This phenomenon is called **Inharmonicity**.

### The Inharmonicity Coefficient ($B$)
The frequency of the $n$-th partial ($f_n$) is given by:
$$f_n = n \cdot f_1 \cdot \sqrt{1 + B \cdot n^2}$$
Where $B$ is the **inharmonicity coefficient**.

*   For a thin, flexible string, $B \approx 0$.
*   For thick, short, or stiff strings (common in small upright pianos), $B$ is much higher.

### Stretched Tuning (Octave Stretching)
Because the overtones of the lower notes are "sharp," if we tune the higher notes to their theoretical frequencies, they will sound **flat** compared to the overtones of the lower notes. This creates "beating" and makes the piano sound out of tune with itself.

To fix this, we "stretch" the tuning:
1.  We measure how stiff the strings are ($B$).
2.  We match the fundamental of a higher note to a specific overtone of a lower note.
3.  **4:2 Matching Rule:** A common professional standard where the 4th partial of the lower note is matched to the 2nd partial of the note one octave above.

---

## 2. Technical Implementation: From Signal to Model

The implementation is split between a high-performance **C++ Native Engine** for signal processing and a **Dart/Flutter Layer** for mathematical modeling and UI.

### Phase 1: Native Signal Processing (C++)
To calculate $B$, the app needs to find the exact frequencies of the fundamental ($f_1$) and the second partial ($f_2$) simultaneously.

*   **Windowed DFT:** We use a Hann-windowed Discrete Fourier Transform (DFT) to analyze the audio buffer. The Hann window reduces spectral leakage, allowing for sub-Hz precision.
*   **Peak Search:**
    1.  We first scan the expected frequency range of $f_1$ (around the target key).
    2.  We perform a "coarse scan" (40 steps) followed by a "fine scan" (40 steps) to find the absolute peak magnitude.
    3.  We repeat this for $f_2$ in the range of $2 \cdot f_1$.
*   **Calculating B:** Once $f_1$ and $f_2$ are found, we solve for $B$:
    $$B = \frac{(f_2 / 2f_1)^2 - 1}{4 - (f_2 / 2f_1)^2}$$

### Phase 2: Mathematical Modeling (Dart)
Users calibrate their piano by playing a few keys (e.g., A1, A2, A3, A4, A5, A6). The app then builds a model for the entire 88-key range.

*   **Log-Linear Regression:** Inharmonicity grows exponentially as we move up the keyboard. We map the measured $B$ values to a log-linear model:
    $$\ln(B) = \alpha \cdot \text{keyNumber} + \beta$$
    We use linear regression on the logged $B$ values to find $\alpha$ (the slope) and $\beta$ (the intercept), allowing us to predict $B$ for any unmeasured key.
*   **Iterative Stretch Calculation:**
    Starting from A4 (the 440Hz reference), we calculate the "cents deviation" for every note:
    1.  We calculate the octave stretch using the 4:2 rule:
        $$\text{Stretch} = 1200 \cdot \log_2\left(\frac{\sqrt{1 + 16B_L}}{\sqrt{1 + 4B_U}}\right)$$
    2.  We distribute this stretch across the 12 semitones of the octave.
    3.  We repeat this upwards to C8 and downwards to A0.

### Phase 3: Integration and UI
*   **FFI Bridge:** The `AudioEngine` (Dart) passes a pointer to the raw audio buffer to the C++ `detect_inharmonicity` function in real-time.
*   **PianoCalibrationScreen:** A guided UI that prompts the user to play specific keys, validates the signal quality, and visualizes the detected $B$ coefficient.
*   **Tuning Profiles:** Calculated frequencies are saved in a `PianoTuningProfile`, which persists in local storage. When active, the main tuner UI automatically shifts its "zero point" (the needle's center) to the stretched frequency for the selected key.

### Out-of-Tune Piano Handling
A common challenge in piano tuning is that the instrument is already out of tune when the user begins calibration. If we only searched for the $f_1$ peak around the **theoretical** frequency of the target key, we might miss the actual string frequency if it's more than a semitone flat or sharp.

**Our Solution:** 
1. The app first uses its primary, robust pitch detection algorithm (YIN) to find the **actual** vibrating frequency of the string.
2. If this detected pitch is within $\pm 2$ semitones of the target key, we use it as the `expectedF1` for the inharmonicity detector.
3. This allows the high-precision peak search to start exactly where the string is currently tuned, making calibration reliable even for severely out-of-tune pianos.

---

## 3. Code Architecture Summary

| Component | Responsibility | Key File |
| :--- | :--- | :--- |
| **DSP (C++)** | DFT, Peak Detection, $B$ Calculation | `notefy.cpp` |
| **Model (Dart)** | Linear Regression, 4:2 Octave Stretching | `piano_tuning_profile.dart` |
| **Persistence** | Saving/Loading Tuning Profiles (JSON) | `tuner_repository.dart` |
| **Controller** | Orchestrating calibration and state | `tuner_controller.dart` |
| **UI** | Calibration workflow and keyboard visualizer | `piano_calibration_screen.dart` |

This architecture ensures that the heavy mathematical lifting is done by the CPU-efficient C++ engine, while the complex modeling and user experience are managed by the flexible Flutter framework.
