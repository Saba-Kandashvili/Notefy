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

// Frequency bounds for piano (A0 = 27.5Hz to C8 = 4186Hz)
#define MIN_FREQUENCY 25.0f
#define MAX_FREQUENCY 4500.0f

// Minimum RMS energy to consider (avoids detecting noise)
#define MIN_RMS_THRESHOLD 0.005f

// ============================================================================
// Static buffer for reuse (avoids malloc/free overhead in real-time)
// ============================================================================
static float *g_yinBuffer = nullptr;
static int g_yinBufferSize = 0;

extern "C"
{

    // ========================================================================
    // Helper: Calculate RMS energy of the signal
    // ========================================================================
    float calculate_rms(const float *buffer, int length)
    {
        float sum = 0.0f;
        for (int i = 0; i < length; i++)
        {
            sum += buffer[i] * buffer[i];
        }
        return sqrtf(sum / length);
    }

    // ========================================================================
    // Step 1: Autocorrelation-based Difference Function
    //
    // For each lag tau, compute the squared difference between the signal
    // and a delayed version of itself. This is the core of YIN.
    // ========================================================================
    void yin_difference(const float *buffer, float *yinBuffer, int bufferLength)
    {
        int halfLen = bufferLength / 2;

        // Initialize buffer to zero
        memset(yinBuffer, 0, sizeof(float) * halfLen);

        // Compute difference for each lag value
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
    //
    // Normalizes the difference function to make threshold selection easier.
    // This is what makes YIN more robust than simple autocorrelation.
    // ========================================================================
    void yin_cumulative_mean_normalized_difference(float *yinBuffer, int bufferLength)
    {
        int halfLen = bufferLength / 2;

        yinBuffer[0] = 1.0f; // Defined as 1 by convention

        float runningSum = 0.0f;
        for (int tau = 1; tau < halfLen; tau++)
        {
            runningSum += yinBuffer[tau];
            if (runningSum != 0.0f)
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
    // Step 3: Absolute Threshold
    //
    // Find the first tau where CMND goes below threshold, then find the
    // local minimum. This gives us the fundamental period estimate.
    // ========================================================================
    int yin_absolute_threshold(const float *yinBuffer, int bufferLength, int sampleRate, float *confidence)
    {
        int halfLen = bufferLength / 2;

        // Calculate min/max tau based on frequency bounds
        int minTau = (int)(sampleRate / MAX_FREQUENCY);
        int maxTau = (int)(sampleRate / MIN_FREQUENCY);

        // Clamp to valid range
        if (minTau < 2)
            minTau = 2;
        if (maxTau > halfLen - 1)
            maxTau = halfLen - 1;

        // Find first tau below threshold
        int bestTau = -1;
        float bestValue = YIN_THRESHOLD;

        for (int tau = minTau; tau < maxTau; tau++)
        {
            if (yinBuffer[tau] < YIN_THRESHOLD)
            {
                // Found a candidate - now find the local minimum
                while (tau + 1 < maxTau && yinBuffer[tau + 1] < yinBuffer[tau])
                {
                    tau++;
                }

                // Check if this is better than what we found before
                if (yinBuffer[tau] < bestValue)
                {
                    bestValue = yinBuffer[tau];
                    bestTau = tau;
                }

                // For piano tuning, we typically want the first good match
                // (fundamental frequency, not harmonics)
                break;
            }
        }

        // Calculate confidence (1.0 - yinValue gives confidence from 0 to 1)
        if (bestTau != -1)
        {
            *confidence = 1.0f - bestValue;
        }
        else
        {
            *confidence = 0.0f;
        }

        return bestTau;
    }

    // ========================================================================
    // Step 4: Parabolic Interpolation
    //
    // Refine the tau estimate using parabolic interpolation for sub-sample
    // accuracy. This significantly improves pitch accuracy.
    // ========================================================================
    float yin_parabolic_interpolation(const float *yinBuffer, int tau, int bufferLength)
    {
        int halfLen = bufferLength / 2;

        // Bounds checking
        if (tau < 1 || tau >= halfLen - 1)
        {
            return (float)tau;
        }

        float s0 = yinBuffer[tau - 1];
        float s1 = yinBuffer[tau];
        float s2 = yinBuffer[tau + 1];

        // Parabolic interpolation formula
        float denominator = 2.0f * (2.0f * s1 - s2 - s0);

        // Avoid division by zero
        if (fabsf(denominator) < 1e-9f)
        {
            return (float)tau;
        }

        float adjustment = (s2 - s0) / denominator;

        // Sanity check - adjustment should be between -1 and 1
        if (adjustment < -1.0f)
            adjustment = -1.0f;
        if (adjustment > 1.0f)
            adjustment = 1.0f;

        return (float)tau + adjustment;
    }

    // ========================================================================
    // MAIN FUNCTION: detect_pitch
    //
    // Called from Dart/Flutter to detect the fundamental frequency.
    // Returns the pitch in Hz, or -1.0 if no pitch detected.
    // ========================================================================
    __attribute__((visibility("default"))) __attribute__((used)) float detect_pitch(float *audioData, int length, int sampleRate)
    {

        // Sanity checks
        if (audioData == nullptr || length < 64)
        {
            return -1.0f;
        }

        // Check if signal has enough energy (avoid detecting silence/noise)
        float rms = calculate_rms(audioData, length);
        if (rms < MIN_RMS_THRESHOLD)
        {
            return -1.0f;
        }

        int halfLen = length / 2;

        // Allocate/reuse YIN buffer
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
                return -1.0f; // Allocation failed
            }
        }

        // Step 1: Compute difference function
        yin_difference(audioData, g_yinBuffer, length);

        // Step 2: Cumulative mean normalized difference
        yin_cumulative_mean_normalized_difference(g_yinBuffer, length);

        // Step 3: Absolute threshold to find period
        float confidence = 0.0f;
        int tau = yin_absolute_threshold(g_yinBuffer, length, sampleRate, &confidence);

        // No pitch found
        if (tau == -1)
        {
            return -1.0f;
        }

        // Step 4: Parabolic interpolation for better accuracy
        float betterTau = yin_parabolic_interpolation(g_yinBuffer, tau, length);

        // Convert period to frequency
        float pitchHz = (float)sampleRate / betterTau;

        // Final sanity check on frequency range
        if (pitchHz < MIN_FREQUENCY || pitchHz > MAX_FREQUENCY)
        {
            return -1.0f;
        }

        return pitchHz;
    }

    // ========================================================================
    // EXTENDED FUNCTION: detect_pitch_with_confidence
    //
    // Same as detect_pitch but also returns a confidence value (0.0 to 1.0)
    // This is useful for UI feedback to show detection reliability.
    // ========================================================================
    __attribute__((visibility("default"))) __attribute__((used)) float detect_pitch_with_confidence(float *audioData, int length, int sampleRate, float *outConfidence)
    {

        // Initialize confidence to 0
        if (outConfidence != nullptr)
        {
            *outConfidence = 0.0f;
        }

        // Sanity checks
        if (audioData == nullptr || length < 64)
        {
            return -1.0f;
        }

        // Check signal energy
        float rms = calculate_rms(audioData, length);
        if (rms < MIN_RMS_THRESHOLD)
        {
            return -1.0f;
        }

        int halfLen = length / 2;

        // Allocate/reuse YIN buffer
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
                return -1.0f;
            }
        }

        // Run YIN algorithm steps
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

        if (pitchHz < MIN_FREQUENCY || pitchHz > MAX_FREQUENCY)
        {
            return -1.0f;
        }

        // Output confidence
        if (outConfidence != nullptr)
        {
            *outConfidence = confidence;
        }

        return pitchHz;
    }

    // ========================================================================
    // Cleanup function (optional - call when done with pitch detection)
    // ========================================================================
    __attribute__((visibility("default"))) __attribute__((used)) void cleanup_pitch_detector()
    {
        if (g_yinBuffer != nullptr)
        {
            free(g_yinBuffer);
            g_yinBuffer = nullptr;
            g_yinBufferSize = 0;
        }
    }
}