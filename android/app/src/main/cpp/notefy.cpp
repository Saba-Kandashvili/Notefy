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

// ============================================================================
// YIN Algorithm Configuration
// ============================================================================

// Threshold for pitch detection (lower = more sensitive, higher = fewer false positives)
// For piano tuning, 0.10-0.15 works well
#define YIN_THRESHOLD 0.10f

// ============================================================================
// Tuning Mode Definitions
// ============================================================================
#define MODE_CHROMATIC 0
#define MODE_GUITAR 1
#define MODE_PIANO 2

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

// Sustained signal detection - requires multiple frames above threshold
#define NOISE_GATE_ATTACK_FRAMES 2  // Frames needed to "open" gate
#define NOISE_GATE_RELEASE_FRAMES 5 // Frames before gate "closes"

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
        g_currentMode = mode;

        // Modes only affect noise gate threshold
        // Frequency range stays wide to support all tunings
        switch (mode)
        {
        case MODE_GUITAR:
            g_noiseThreshold = NOISE_GATE_GUITAR;
            break;
        case MODE_PIANO:
            g_noiseThreshold = NOISE_GATE_PIANO;
            break;
        case MODE_CHROMATIC:
        default:
            g_noiseThreshold = NOISE_GATE_CHROMATIC;
            break;
        }

        // Reset gate state on mode change
        g_gateOpenCounter = 0;
        g_gateCloseCounter = 0;
        g_gateIsOpen = false;
        g_lastValidPitch = -1.0f;
    }

    // ========================================================================
    // Configuration: Set custom frequency range
    // Use this for custom tunings (e.g., 7-string, drop tuning, bass guitar)
    // ========================================================================
    __attribute__((visibility("default"))) __attribute__((used)) void set_frequency_range(float minFreq, float maxFreq)
    {
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
        g_minFrequency = DEFAULT_MIN_FREQ;
        g_maxFrequency = DEFAULT_MAX_FREQ;
    }

    // ========================================================================
    // Configuration: Set custom noise gate threshold
    // ========================================================================
    __attribute__((visibility("default"))) __attribute__((used)) void set_noise_threshold(float threshold)
    {
        if (threshold > 0.0f && threshold < 1.0f)
        {
            g_noiseThreshold = threshold;
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

        if (signal_present)
        {
            g_gateCloseCounter = 0;
            g_gateOpenCounter++;

            // Open gate after sustained signal
            if (g_gateOpenCounter >= NOISE_GATE_ATTACK_FRAMES)
            {
                g_gateIsOpen = true;
            }
        }
        else
        {
            g_gateOpenCounter = 0;
            g_gateCloseCounter++;

            // Close gate after sustained silence
            if (g_gateCloseCounter >= NOISE_GATE_RELEASE_FRAMES)
            {
                g_gateIsOpen = false;
                g_lastValidPitch = -1.0f;
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
        float bestValue = YIN_THRESHOLD;

        for (int tau = minTau; tau < maxTau; tau++)
        {
            if (yinBuffer[tau] < YIN_THRESHOLD)
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

        float betterTau = yin_parabolic_interpolation(g_yinBuffer, tau, length);
        float pitchHz = (float)sampleRate / betterTau;

        // Final frequency range check
        if (pitchHz < g_minFrequency || pitchHz > g_maxFrequency)
        {
            return -1.0f;
        }

        // Store as last valid pitch for stability
        g_lastValidPitch = pitchHz;

        return pitchHz;
    }

    // ========================================================================
    // EXTENDED FUNCTION: detect_pitch_with_confidence
    // ========================================================================
    __attribute__((visibility("default"))) __attribute__((used)) float detect_pitch_with_confidence(float *audioData, int length, int sampleRate, float *outConfidence)
    {
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

        float betterTau = yin_parabolic_interpolation(g_yinBuffer, tau, length);
        float pitchHz = (float)sampleRate / betterTau;

        if (pitchHz < g_minFrequency || pitchHz > g_maxFrequency)
        {
            return -1.0f;
        }

        if (outConfidence != nullptr)
        {
            *outConfidence = confidence;
        }

        g_lastValidPitch = pitchHz;
        return pitchHz;
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
        g_lastValidPitch = -1.0f;
        g_currentMode = MODE_CHROMATIC;
        g_minFrequency = DEFAULT_MIN_FREQ;
        g_maxFrequency = DEFAULT_MAX_FREQ;
        g_noiseThreshold = NOISE_GATE_CHROMATIC;
    }
}