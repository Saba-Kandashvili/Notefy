#include "synth_engine.h"
#include <android/log.h>
#include <math.h>

#define LOG_TAG "SynthEngine"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

#ifndef M_PI
#define M_PI 3.14159265358979323846f
#endif

SynthEngine::SynthEngine() {
}

SynthEngine::~SynthEngine() {
    stop();
}

bool SynthEngine::start() {
    std::lock_guard<std::mutex> lock(mLock);
    if (mIsPlaying) return true;

    oboe::AudioStreamBuilder builder;
    builder.setDirection(oboe::Direction::Output);
    builder.setPerformanceMode(oboe::PerformanceMode::LowLatency);
    builder.setSharingMode(oboe::SharingMode::Exclusive);
    builder.setFormat(oboe::AudioFormat::Float);
    builder.setChannelCount(1); // Mono
    builder.setCallback(this);

    oboe::Result result = builder.openStream(mStream);
    if (result != oboe::Result::OK) {
        LOGE("Failed to open stream. Error: %s", oboe::convertToText(result));
        return false;
    }

    mSampleRate = mStream->getSampleRate();
    
    result = mStream->requestStart();
    if (result != oboe::Result::OK) {
        LOGE("Failed to start stream. Error: %s", oboe::convertToText(result));
        mStream->close();
        return false;
    }

    mIsPlaying = true;
    return true;
}

void SynthEngine::stop() {
    std::lock_guard<std::mutex> lock(mLock);
    if (!mIsPlaying || !mStream) return;
    
    mStream->requestStop();
    mStream->close();
    mStream.reset();
    
    mIsPlaying = false;
    mIsSweeping = false;
}

void SynthEngine::setFrequency(float freq) {
    if (freq < 20.0f) freq = 20.0f;
    if (freq > 20000.0f) freq = 20000.0f;
    mFrequency = freq;
    mIsSweeping = false;
}

void SynthEngine::setWaveform(int type) {
    mWaveform = type;
}

void SynthEngine::startSweep(float endFreq, float durationSec, bool loop) {
    if (durationSec <= 0.0f) {
        setFrequency(endFreq);
        return;
    }
    mSweepStartFreq = mFrequency.load();
    mSweepEndFreq = endFreq;
    mSweepDurationSec = durationSec;
    mLoopSweep = loop;
    mSweepTimePassed = 0.0f;
    mIsSweeping = true;
}

void SynthEngine::stopSweep() {
    mIsSweeping = false;
}

void SynthEngine::setLoopSweep(bool loop) {
    mLoopSweep = loop;
}

float SynthEngine::getFrequency() {
    return mFrequency.load();
}

oboe::DataCallbackResult SynthEngine::onAudioReady(oboe::AudioStream *oboeStream, void *audioData, int32_t numFrames) {
    float *floatData = static_cast<float *>(audioData);
    
    float currentFreq = mFrequency.load();
    int waveform = mWaveform.load();
    bool isSweeping = mIsSweeping.load();
    
    float timeIncrement = 1.0f / mSampleRate;

    for (int i = 0; i < numFrames; ++i) {
        if (isSweeping) {
            mSweepTimePassed += timeIncrement;
            if (mSweepTimePassed >= mSweepDurationSec) {
                if (mLoopSweep.load()) {
                    mSweepTimePassed -= mSweepDurationSec;
                    currentFreq = mSweepStartFreq;
                } else {
                    mSweepTimePassed = mSweepDurationSec;
                    isSweeping = false;
                    mIsSweeping = false;
                    currentFreq = mSweepEndFreq;
                }
                mFrequency = currentFreq;
            } else {
                // Exponential sweep for pitch
                float progress = mSweepTimePassed / mSweepDurationSec;
                currentFreq = mSweepStartFreq * powf(mSweepEndFreq / mSweepStartFreq, progress);
                mFrequency = currentFreq;
            }
        }
        
        float phaseIncrement = currentFreq / mSampleRate;
        mPhase += phaseIncrement;
        if (mPhase >= 1.0f) mPhase -= 1.0f;
        
        float sample = 0.0f;
        switch (waveform) {
            case 0: // Sine
                sample = sinf(mPhase * 2.0f * M_PI);
                break;
            case 1: // Square
                sample = mPhase < 0.5f ? 1.0f : -1.0f;
                break;
            case 2: // Sawtooth
                sample = 2.0f * mPhase - 1.0f;
                break;
            case 3: // Triangle
                sample = 4.0f * fabsf(mPhase - 0.5f) - 1.0f;
                break;
        }
        
        // Attenuate to avoid clipping and ease hearing
        floatData[i] = sample * 0.25f; 
    }
    
    return oboe::DataCallbackResult::Continue;
}
