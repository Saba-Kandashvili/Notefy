#include <stdint.h>
#include <stdlib.h>
#include <math.h>
#include <float.h>

// Configuration for the algorithm
#define THRESHOLD 0.15

extern "C" {

    // Helper: Difference function
    void difference(float* buffer, float* yinBuffer, int length) {
        int halfLen = length / 2;
        for (int tau = 0; tau < halfLen; tau++) {
            yinBuffer[tau] = 0;
        }
        for (int tau = 1; tau < halfLen; tau++) {
            for (int i = 0; i < halfLen; i++) {
                float delta = buffer[i] - buffer[i + tau];
                yinBuffer[tau] += delta * delta;
            }
        }
    }

    // Helper: Cumulative Mean Normalized Difference
    void cumulative_mean_normalized_difference(float* yinBuffer, int length) {
        int halfLen = length / 2;
        yinBuffer[0] = 1;
        float runningSum = 0;
        for (int tau = 1; tau < halfLen; tau++) {
            runningSum += yinBuffer[tau];
            yinBuffer[tau] *= tau / runningSum;
        }
    }

    // Helper: Absolute Threshold
    int absolute_threshold(float* yinBuffer, int length) {
        int halfLen = length / 2;
        for (int tau = 2; tau < halfLen; tau++) {
            if (yinBuffer[tau] < THRESHOLD) {
                while (tau + 1 < halfLen && yinBuffer[tau + 1] < yinBuffer[tau]) {
                    tau++;
                }
                return tau;
            }
        }
        return -1; // No pitch found
    }

    // Helper: Parabolic Interpolation (Make it precise!)
    float parabolic_interpolation(float* yinBuffer, int tau, int length) {
        int halfLen = length / 2;
        if (tau >= halfLen) return (float)tau;
        
        float s0, s1, s2;
        if (tau < 1) s0 = yinBuffer[tau]; else s0 = yinBuffer[tau - 1];
        s1 = yinBuffer[tau];
        if (tau + 1 < halfLen) s2 = yinBuffer[tau + 1]; else s2 = yinBuffer[tau];
        
        if (s0 == s2) return (float)tau; // unlikely
        
        return tau + (s2 - s0) / (2 * (2 * s1 - s2 - s0));
    }

    // --- MAIN FUNCTION CALLED BY DART ---
    __attribute__((visibility("default"))) __attribute__((used))
    float detect_pitch(float* audioData, int length, int sampleRate) {
        
        // 1. Create a buffer for calculations (Yin requires a buffer half the size)
        // In production, reuse this memory instead of allocating every time!
        int halfLen = length / 2;
        float* yinBuffer = (float*)malloc(sizeof(float) * halfLen);
        
        // 2. Run Steps
        difference(audioData, yinBuffer, length);
        cumulative_mean_normalized_difference(yinBuffer, length);
        int tau = absolute_threshold(yinBuffer, length);
        
        float pitchInHz = -1.0;

        if (tau != -1) {
            float betterTau = parabolic_interpolation(yinBuffer, tau, length);
            pitchInHz = (float)sampleRate / betterTau;
        }

        free(yinBuffer);
        return pitchInHz;
    }
}