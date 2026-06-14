/*
 * YIN Pitch Detection Algorithm Implementation
 *
 * Optimized for real-time piano/instrument tuning.
 * Based on the paper: "YIN, a fundamental frequency estimator for speech and music"
 * by Alain de Cheveigné and Hideki Kawahara (2002)
 *
 * This implementation provides accurate pitch detection suitable for
 * tuning instruments like pianos, guitars, and other stringed instruments.
 */

#include <stdint.h>
#include <stdlib.h>
#include <math.h>
#include <float.h>
#include <string.h>
#include <mutex>

#ifndef M_PI
#define M_PI 3.14159265358979323846f
#endif

// ============================================================================
// YIN Algorithm Configuration
// ============================================================================

// Threshold for pitch detection (lower = more sensitive, higher = fewer false positives)
// For piano tuning, 0.10-0.15 works well
// Now configurable at runtime via set_yin_threshold()
static float g_yinThreshold = 0.15f;

// Thread safety mutex for all global state
static std::mutex g_mutex;

// ============================================================================
// Tuning Mode Definitions
// ============================================================================
#define MODE_CHROMATIC 0
#define MODE_GUITAR 1
#define MODE_PIANO 2
#define MODE_PRACTICE 3

// Frequency ranges - all modes use full range by default
// Guitar/Piano modes only affect noise gate sensitivity
// Actual frequency filtering can be done via set_frequency_range()
#define DEFAULT_MIN_FREQ 25.0f   // A0 = 27.5Hz with margin
#define DEFAULT_MAX_FREQ 4500.0f // C8 = 4186Hz with margin

// ============================================================================
// Noise Gate Configuration
// ============================================================================

// Minimum RMS energy thresholds (higher = stricter noise gate)
#define NOISE_GATE_CHROMATIC 0.008f // Medium sensitivity
#define NOISE_GATE_GUITAR 0.010f    // Guitar - slightly higher for amp noise
#define NOISE_GATE_PIANO 0.006f     // Piano can be quieter, more sensitive
#define NOISE_GATE_PRACTICE 0.005f  // Practice - very sensitive to allow quiet bends

// Sustained signal detection - requires multiple frames above threshold
#define NOISE_GATE_ATTACK_FRAMES 2  // Frames needed to "open" gate
#define NOISE_GATE_RELEASE_FRAMES 5 // Frames before gate "closes"

// Practice mode (Fast Response, but stable)
#define NOISE_GATE_ATTACK_FRAMES_PRACTICE 4  // More frames needed to stabilize pick attack
#define NOISE_GATE_RELEASE_FRAMES_PRACTICE 6 // Slower release to avoid dropouts at end of note

// ============================================================================
// Pitch Stability Configuration
// ============================================================================
#define PITCH_HISTORY_SIZE 5            // Median filter window size (unused now)
#define MIN_CONFIDENCE_THRESHOLD 0.50f  // Only reject very low confidence (noise)
#define OCTAVE_JUMP_THRESHOLD_LOW 0.45f // Ratio for octave-down detection
#define OCTAVE_JUMP_THRESHOLD_HIGH 0.55f
#define OCTAVE_JUMP_THRESHOLD_2X_LOW 1.8f // Ratio for octave-up detection
#define OCTAVE_JUMP_THRESHOLD_2X_HIGH 2.2f

// ============================================================================
// Static buffers for reuse (avoids malloc/free overhead in real-time)
// ============================================================================
static float *g_yinBuffer = nullptr;
static int g_yinBufferSize = 0;

// Noise gate state
static int g_gateOpenCounter = 0;      // Counts frames above threshold
static int g_gateCloseCounter = 0;     // Counts frames below threshold
static bool g_gateIsOpen = false;      // Current gate state
static float g_lastValidPitch = -1.0f; // Last detected pitch for stability

// Pitch stability state (median filter)
static float g_pitchHistory[PITCH_HISTORY_SIZE] = {0};
static int g_pitchHistoryIndex = 0;
static int g_pitchHistoryCount = 0; // How many valid samples we have

// Current mode settings
static int g_currentMode = MODE_CHROMATIC;
static float g_minFrequency = DEFAULT_MIN_FREQ;
static float g_maxFrequency = DEFAULT_MAX_FREQ;
static float g_noiseThreshold = NOISE_GATE_CHROMATIC;

extern "C"
{

    // ========================================================================
    // Configuration: Set tuning mode (affects noise gate sensitivity)
    // ========================================================================
    __attribute__((visibility("default"))) __attribute__((used)) void set_tuning_mode(int mode)
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        g_currentMode = mode;

        // Modes only affect noise gate threshold and algorithm sensitivity
        switch (mode)
        {
        case MODE_GUITAR:
            g_noiseThreshold = NOISE_GATE_GUITAR;
            g_yinThreshold = 0.15f;
            break;
        case MODE_PIANO:
            g_noiseThreshold = NOISE_GATE_PIANO;
            g_yinThreshold = 0.15f;
            break;
        case MODE_PRACTICE:
            g_noiseThreshold = 0.007f;
            // Lower threshold = more strict (requires better autocorrelation match)
            g_yinThreshold = 0.12f;
            break;
        case MODE_CHROMATIC:
        default:
            g_noiseThreshold = NOISE_GATE_CHROMATIC;
            g_yinThreshold = 0.15f;
            break;
        }

        // Reset gate state and pitch stability on mode change
        g_gateOpenCounter = 0;
        g_gateCloseCounter = 0;
        g_gateIsOpen = false;
        g_lastValidPitch = -1.0f;
        // Reset pitch history
        for (int i = 0; i < PITCH_HISTORY_SIZE; i++)
        {
            g_pitchHistory[i] = 0.0f;
        }
        g_pitchHistoryIndex = 0;
        g_pitchHistoryCount = 0;
    }

    // ========================================================================
    // Configuration: Set custom frequency range
    // Use this for custom tunings (e.g., 7-string, drop tuning, bass guitar)
    // ========================================================================
    __attribute__((visibility("default"))) __attribute__((used)) void set_frequency_range(float minFreq, float maxFreq)
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        if (minFreq > 0.0f && minFreq < maxFreq)
        {
            g_minFrequency = minFreq;
            g_maxFrequency = maxFreq;
        }
    }

    // ========================================================================
    // Configuration: Reset frequency range to defaults
    // ========================================================================
    __attribute__((visibility("default"))) __attribute__((used)) void reset_frequency_range()
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        g_minFrequency = DEFAULT_MIN_FREQ;
        g_maxFrequency = DEFAULT_MAX_FREQ;
    }

    // ========================================================================
    // Configuration: Set custom noise gate threshold
    // ========================================================================
    __attribute__((visibility("default"))) __attribute__((used)) void set_noise_threshold(float threshold)
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        if (threshold > 0.0f && threshold < 1.0f)
        {
            g_noiseThreshold = threshold;
        }
    }

    // ========================================================================
    // Configuration: Set YIN algorithm threshold
    // Lower = more sensitive (0.05-0.15), Higher = fewer false positives (0.15-0.3)
    // ========================================================================
    __attribute__((visibility("default"))) __attribute__((used)) void set_yin_threshold(float threshold)
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        if (threshold > 0.05f && threshold < 0.5f)
        {
            g_yinThreshold = threshold;
        }
    }

    // ========================================================================
    // Helper: Calculate RMS energy of the signal
    // ========================================================================
    static inline float calculate_rms(const float *buffer, int length)
    {
        float sum = 0.0f;
        for (int i = 0; i < length; i++)
        {
            sum += buffer[i] * buffer[i];
        }
        return sqrtf(sum / length);
    }

    // ========================================================================
    // Helper: Calculate peak amplitude (for additional noise detection)
    // ========================================================================
    static inline float calculate_peak(const float *buffer, int length)
    {
        float peak = 0.0f;
        for (int i = 0; i < length; i++)
        {
            float abs_val = fabsf(buffer[i]);
            if (abs_val > peak)
                peak = abs_val;
        }
        return peak;
    }

    // ========================================================================
    // Helper: Median filter for pitch stability (reduces jitter)
    // Returns median of last N pitch values
    // ========================================================================
    static float apply_median_filter(float newPitch)
    {
        // Add to history
        g_pitchHistory[g_pitchHistoryIndex] = newPitch;
        g_pitchHistoryIndex = (g_pitchHistoryIndex + 1) % PITCH_HISTORY_SIZE;
        if (g_pitchHistoryCount < PITCH_HISTORY_SIZE)
        {
            g_pitchHistoryCount++;
        }

        // Need at least 3 samples for meaningful median
        if (g_pitchHistoryCount < 3)
        {
            return newPitch;
        }

        // Copy valid samples and sort
        float sorted[PITCH_HISTORY_SIZE];
        int count = g_pitchHistoryCount;
        for (int i = 0; i < count; i++)
        {
            sorted[i] = g_pitchHistory[i];
        }

        // Simple insertion sort (small array, fast enough)
        for (int i = 1; i < count; i++)
        {
            float key = sorted[i];
            int j = i - 1;
            while (j >= 0 && sorted[j] > key)
            {
                sorted[j + 1] = sorted[j];
                j--;
            }
            sorted[j + 1] = key;
        }

        // Return median
        return sorted[count / 2];
    }

    // ========================================================================
    // Helper: Correct octave errors (YIN sometimes jumps octaves)
    // ========================================================================
    static float correct_octave_error(float pitchHz)
    {
        if (g_lastValidPitch <= 0.0f)
        {
            return pitchHz; // No reference yet
        }

        float ratio = pitchHz / g_lastValidPitch;

        // Detected pitch is ~2x the last valid pitch (jumped up an octave)
        if (ratio > OCTAVE_JUMP_THRESHOLD_2X_LOW && ratio < OCTAVE_JUMP_THRESHOLD_2X_HIGH)
        {
            return pitchHz / 2.0f;
        }

        // Detected pitch is ~0.5x the last valid pitch (jumped down an octave)
        if (ratio > OCTAVE_JUMP_THRESHOLD_LOW && ratio < OCTAVE_JUMP_THRESHOLD_HIGH)
        {
            return pitchHz * 2.0f;
        }

        return pitchHz;
    }

    // ========================================================================
    // Helper: Reset pitch stability state
    // ========================================================================
    static void reset_pitch_stability()
    {
        for (int i = 0; i < PITCH_HISTORY_SIZE; i++)
        {
            g_pitchHistory[i] = 0.0f;
        }
        g_pitchHistoryIndex = 0;
        g_pitchHistoryCount = 0;
        g_lastValidPitch = -1.0f;
    }

    // ========================================================================
    // Noise Gate: Determines if signal should be processed
    // Uses hysteresis to avoid rapid on/off switching
    // ========================================================================
    static bool noise_gate_check(float rms, float peak)
    {
        // Primary check: RMS above threshold
        bool above_threshold = (rms > g_noiseThreshold);

        // Secondary check: Peak should be reasonable (not just DC offset)
        bool has_signal = (peak > g_noiseThreshold * 2.0f);

        bool signal_present = above_threshold && has_signal;

        int attack_frames = (g_currentMode == MODE_PRACTICE) ? NOISE_GATE_ATTACK_FRAMES_PRACTICE : NOISE_GATE_ATTACK_FRAMES;
        int release_frames = (g_currentMode == MODE_PRACTICE) ? NOISE_GATE_RELEASE_FRAMES_PRACTICE : NOISE_GATE_RELEASE_FRAMES;

        if (signal_present)
        {
            g_gateCloseCounter = 0;
            g_gateOpenCounter++;

            // Open gate after sustained signal
            if (g_gateOpenCounter >= attack_frames)
            {
                g_gateIsOpen = true;
            }
        }
        else
        {
            g_gateOpenCounter = 0;
            g_gateCloseCounter++;

            // Close gate after sustained silence
            if (g_gateCloseCounter >= release_frames)
            {
                g_gateIsOpen = false;
                reset_pitch_stability(); // Reset pitch history when gate closes
            }
        }

        return g_gateIsOpen;
    }

    // ========================================================================
    // Step 1: Autocorrelation-based Difference Function
    // ========================================================================
    static void yin_difference(const float *buffer, float *yinBuffer, int bufferLength)
    {
        int halfLen = bufferLength / 2;
        memset(yinBuffer, 0, sizeof(float) * halfLen);

        for (int tau = 1; tau < halfLen; tau++)
        {
            float sum = 0.0f;
            for (int i = 0; i < halfLen; i++)
            {
                float delta = buffer[i] - buffer[i + tau];
                sum += delta * delta;
            }
            yinBuffer[tau] = sum;
        }
    }

    // ========================================================================
    // Step 2: Cumulative Mean Normalized Difference Function (CMND)
    // ========================================================================
    static void yin_cumulative_mean_normalized_difference(float *yinBuffer, int bufferLength)
    {
        int halfLen = bufferLength / 2;
        yinBuffer[0] = 1.0f;

        float runningSum = 0.0f;
        for (int tau = 1; tau < halfLen; tau++)
        {
            runningSum += yinBuffer[tau];
            if (runningSum > 0.0f)
            {
                yinBuffer[tau] = yinBuffer[tau] * tau / runningSum;
            }
            else
            {
                yinBuffer[tau] = 1.0f;
            }
        }
    }

    // ========================================================================
    // Step 3: Absolute Threshold with mode-aware frequency bounds
    // ========================================================================
    static int yin_absolute_threshold(const float *yinBuffer, int bufferLength, int sampleRate, float *confidence)
    {
        int halfLen = bufferLength / 2;

        // Calculate min/max tau based on current mode frequency bounds
        int minTau = (int)(sampleRate / g_maxFrequency);
        int maxTau = (int)(sampleRate / g_minFrequency);

        if (minTau < 2)
            minTau = 2;
        if (maxTau > halfLen - 1)
            maxTau = halfLen - 1;

        int bestTau = -1;
        float bestValue = g_yinThreshold;

        for (int tau = minTau; tau < maxTau; tau++)
        {
            if (yinBuffer[tau] < g_yinThreshold)
            {
                while (tau + 1 < maxTau && yinBuffer[tau + 1] < yinBuffer[tau])
                {
                    tau++;
                }

                if (yinBuffer[tau] < bestValue)
                {
                    bestValue = yinBuffer[tau];
                    bestTau = tau;
                }
                break;
            }
        }

        *confidence = (bestTau != -1) ? (1.0f - bestValue) : 0.0f;
        return bestTau;
    }

    // ========================================================================
    // Step 4: Parabolic Interpolation
    // ========================================================================
    static float yin_parabolic_interpolation(const float *yinBuffer, int tau, int bufferLength)
    {
        int halfLen = bufferLength / 2;

        if (tau < 1 || tau >= halfLen - 1)
        {
            return (float)tau;
        }

        float s0 = yinBuffer[tau - 1];
        float s1 = yinBuffer[tau];
        float s2 = yinBuffer[tau + 1];

        float denominator = 2.0f * (2.0f * s1 - s2 - s0);

        if (fabsf(denominator) < 1e-9f)
        {
            return (float)tau;
        }

        float adjustment = (s2 - s0) / denominator;

        if (adjustment < -1.0f)
            adjustment = -1.0f;
        if (adjustment > 1.0f)
            adjustment = 1.0f;

        return (float)tau + adjustment;
    }

    // ========================================================================
    // Helper: Ensure YIN buffer is allocated
    // ========================================================================
    static bool ensure_yin_buffer(int halfLen)
    {
        if (g_yinBuffer == nullptr || g_yinBufferSize < halfLen)
        {
            if (g_yinBuffer != nullptr)
            {
                free(g_yinBuffer);
            }
            g_yinBuffer = (float *)malloc(sizeof(float) * halfLen);
            g_yinBufferSize = halfLen;

            if (g_yinBuffer == nullptr)
            {
                return false;
            }
        }
        return true;
    }

    // ========================================================================
    // MAIN FUNCTION: detect_pitch
    // ========================================================================
    __attribute__((visibility("default"))) __attribute__((used)) float detect_pitch(float *audioData, int length, int sampleRate)
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        if (audioData == nullptr || length < 64)
        {
            return -1.0f;
        }

        // Calculate signal energy
        float rms = calculate_rms(audioData, length);
        float peak = calculate_peak(audioData, length);

        // Noise gate check with hysteresis
        if (!noise_gate_check(rms, peak))
        {
            return -1.0f;
        }

        int halfLen = length / 2;

        if (!ensure_yin_buffer(halfLen))
        {
            return -1.0f;
        }

        // YIN Algorithm
        yin_difference(audioData, g_yinBuffer, length);
        yin_cumulative_mean_normalized_difference(g_yinBuffer, length);

        float confidence = 0.0f;
        int tau = yin_absolute_threshold(g_yinBuffer, length, sampleRate, &confidence);

        if (tau == -1)
        {
            return -1.0f;
        }

        // Low confidence = no pitch detected (don't fake it)
        if (confidence < MIN_CONFIDENCE_THRESHOLD)
        {
            return -1.0f;
        }

        float betterTau = yin_parabolic_interpolation(g_yinBuffer, tau, length);
        float pitchHz = (float)sampleRate / betterTau;

        // Apply octave correction
        pitchHz = correct_octave_error(pitchHz);

        // Final frequency range check
        if (pitchHz < g_minFrequency || pitchHz > g_maxFrequency)
        {
            return -1.0f;
        }

        // Store as last valid pitch (for reference only, not used to fake readings)
        g_lastValidPitch = pitchHz;

        return pitchHz;
    }

    // ========================================================================
    // EXTENDED FUNCTION: detect_pitch_with_confidence
    // ========================================================================
    __attribute__((visibility("default"))) __attribute__((used)) float detect_pitch_with_confidence(float *audioData, int length, int sampleRate, float *outConfidence)
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        if (outConfidence != nullptr)
        {
            *outConfidence = 0.0f;
        }

        if (audioData == nullptr || length < 64)
        {
            return -1.0f;
        }

        float rms = calculate_rms(audioData, length);
        float peak = calculate_peak(audioData, length);

        if (!noise_gate_check(rms, peak))
        {
            return -1.0f;
        }

        int halfLen = length / 2;

        if (!ensure_yin_buffer(halfLen))
        {
            return -1.0f;
        }

        yin_difference(audioData, g_yinBuffer, length);
        yin_cumulative_mean_normalized_difference(g_yinBuffer, length);

        float confidence = 0.0f;
        int tau = yin_absolute_threshold(g_yinBuffer, length, sampleRate, &confidence);

        if (tau == -1)
        {
            return -1.0f;
        }

        // Always report confidence, even if low
        if (outConfidence != nullptr)
        {
            *outConfidence = confidence;
        }

        // Low confidence = no pitch detected (don't fake it)
        if (confidence < MIN_CONFIDENCE_THRESHOLD)
        {
            return -1.0f;
        }

        float betterTau = yin_parabolic_interpolation(g_yinBuffer, tau, length);
        float pitchHz = (float)sampleRate / betterTau;

        // Apply octave correction
        pitchHz = correct_octave_error(pitchHz);

        if (pitchHz < g_minFrequency || pitchHz > g_maxFrequency)
        {
            return -1.0f;
        }

        g_lastValidPitch = pitchHz;
        return pitchHz;
    }

    // ========================================================================
    // NEW: Inharmonicity Detection for Piano Tuning
    // ========================================================================

    static float calculate_dft_magnitude_windowed(const float *buffer, int length, float freq, int sampleRate)
    {
        float real = 0.0f;
        float imag = 0.0f;
        float angleStep = 2.0f * M_PI * freq / (float)sampleRate;

        for (int i = 0; i < length; i++)
        {
            // Hann window: 0.5 * (1 - cos(2*pi*i/(N-1)))
            float window = 0.5f * (1.0f - cosf(2.0f * M_PI * (float)i / (float)(length - 1)));
            float angle = angleStep * (float)i;
            real += buffer[i] * window * cosf(angle);
            imag += buffer[i] * window * sinf(angle);
        }

        return sqrtf(real * real + imag * imag);
    }

    static float find_peak_in_range(const float *buffer, int length, int sampleRate, float minFreq, float maxFreq, float *outMag)
    {
        float bestFreq = minFreq;
        float maxMag = -1.0f;

        // Scan in 40 steps
        const int steps = 40;
        float stepSize = (maxFreq - minFreq) / (float)steps;

        for (int i = 0; i <= steps; i++)
        {
            float f = minFreq + stepSize * (float)i;
            float mag = calculate_dft_magnitude_windowed(buffer, length, f, sampleRate);
            if (mag > maxMag)
            {
                maxMag = mag;
                bestFreq = f;
            }
        }

        // Fine scan around the best frequency
        float fineMin = bestFreq - stepSize;
        float fineMax = bestFreq + stepSize;
        const int fineSteps = 40;
        float fineStepSize = (fineMax - fineMin) / (float)fineSteps;

        for (int i = 0; i <= fineSteps; i++)
        {
            float f = fineMin + fineStepSize * (float)i;
            float mag = calculate_dft_magnitude_windowed(buffer, length, f, sampleRate);
            if (mag > maxMag)
            {
                maxMag = mag;
                bestFreq = f;
            }
        }

        if (outMag)
            *outMag = maxMag;
        return bestFreq;
    }

    __attribute__((visibility("default"))) __attribute__((used)) float detect_inharmonicity(float *audioData, int length, int sampleRate, float expectedF1)
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        if (audioData == nullptr || length < 512)
            return -1.0f;

        // Calculate signal energy
        float rms = calculate_rms(audioData, length);
        if (rms < g_noiseThreshold)
        {
            return -1.0f;
        }

        float mag1 = 0, mag2 = 0;
        // 1. Find actual f1 around expectedF1
        float f1 = find_peak_in_range(audioData, length, sampleRate, expectedF1 * 0.94f, expectedF1 * 1.06f, &mag1);

        // 2. Find f2 around 2*f1
        float f2 = find_peak_in_range(audioData, length, sampleRate, f1 * 1.95f, f1 * 2.15f, &mag2);

        // Validation: mag should be significantly above noise floor
        // and f2 should have reasonable energy compared to f1
        if (mag1 < g_noiseThreshold * length * 0.1f || mag2 < g_noiseThreshold * length * 0.05f)
        {
            return -1.0f;
        }

        // 3. Calculate B
        float ratio = f2 / (2.0f * f1);
        float R = ratio * ratio;

        if (R >= 4.0f || R < 1.0f)
            return 0.0f;

        float b = (R - 1.0f) / (4.0f - R);

        // Limit B to reasonable piano ranges (0.0 to 0.01)
        if (b < 0.0f)
            b = 0.0f;
        if (b > 0.01f)
            b = 0.01f;

        return b;
    }

    // ========================================================================
    // Get current noise gate state (for UI feedback)
    // ========================================================================
    __attribute__((visibility("default"))) __attribute__((used)) bool is_gate_open()
    {
        return g_gateIsOpen;
    }

    // ========================================================================
    // Cleanup function
    // ========================================================================
    __attribute__((visibility("default"))) __attribute__((used)) void cleanup_pitch_detector()
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        if (g_yinBuffer != nullptr)
        {
            free(g_yinBuffer);
            g_yinBuffer = nullptr;
            g_yinBufferSize = 0;
        }

        // Reset state
        g_gateOpenCounter = 0;
        g_gateCloseCounter = 0;
        g_gateIsOpen = false;
        reset_pitch_stability();
        g_currentMode = MODE_CHROMATIC;
        g_minFrequency = DEFAULT_MIN_FREQ;
        g_maxFrequency = DEFAULT_MAX_FREQ;
        g_noiseThreshold = NOISE_GATE_CHROMATIC;
        g_yinThreshold = 0.15f;
    }

    // ========================================================================
    // NEW: Fast, constrained Pitch Tracking specifically for Bends Practice
    // ========================================================================
    __attribute__((visibility("default"))) __attribute__((used)) float detect_pitch_bend(float *audioData, int length, int sampleRate, float expectedFreq)
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        if (audioData == nullptr || length < 128 || expectedFreq <= 0.0f)
        {
            return -1.0f;
        }

        // Fast bounds calculation: search from ~4 semitones down to ~7 semitones up
        float minFreq = expectedFreq * 0.75f;
        float maxFreq = expectedFreq * 1.50f;

        int minTau = (int)(sampleRate / maxFreq);
        int maxTau = (int)(sampleRate / minFreq);

        int halfLen = length / 2;
        if (minTau < 2) minTau = 2;
        if (maxTau >= halfLen) maxTau = halfLen - 1;
        if (minTau >= maxTau) return -1.0f;

        // Practice bends needs a very low threshold to track decaying strings
        float rms = calculate_rms(audioData, length);
        if (rms < 0.002f) {
            return -1.0f; 
        }

        if (!ensure_yin_buffer(halfLen)) {
            return -1.0f;
        }

        // Use robust YIN difference and CMND steps to eliminate harmonic confusion
        yin_difference(audioData, g_yinBuffer, length);
        yin_cumulative_mean_normalized_difference(g_yinBuffer, length);

        int bestTau = -1;
        float bestValue = 0.2f; // YIN absolute threshold

        for (int tau = minTau; tau < maxTau; tau++) {
            if (g_yinBuffer[tau] < 0.2f) {
                // Found a dip below threshold, now find local minimum
                while (tau + 1 < maxTau && g_yinBuffer[tau + 1] < g_yinBuffer[tau]) {
                    tau++;
                }
                bestValue = g_yinBuffer[tau];
                bestTau = tau;
                break;
            }
        }

        // Fallback if no dip below threshold found: pick the absolute minimum in our tightly bounded range
        if (bestTau == -1) {
            float min_val = 1.0f;
            for (int tau = minTau; tau < maxTau; tau++) {
                if (g_yinBuffer[tau] < min_val) {
                    min_val = g_yinBuffer[tau];
                    bestTau = tau;
                }
            }
            // If the best minimum is still garbage, we don't have a solid pitch
            if (min_val > 0.4f) {
                return -1.0f; 
            }
        }

        // Sub-sample interpolation
        float betterTau = yin_parabolic_interpolation(g_yinBuffer, bestTau, length);
        
        return (float)sampleRate / betterTau;
    }
}