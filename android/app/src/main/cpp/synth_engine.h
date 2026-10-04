#ifndef SYNTH_ENGINE_H
#define SYNTH_ENGINE_H

#include <oboe/Oboe.h>
#include <atomic>
#include <mutex>

class SynthEngine : public oboe::AudioStreamCallback {
public:
    SynthEngine();
    ~SynthEngine();

    bool start();
    void stop();
    void setFrequency(float freq);
    void setWaveform(int type);
    void startSweep(float endFreq, float durationSec, bool loop);
    void stopSweep();
    void setLoopSweep(bool loop);
    float getFrequency();

    // AudioStreamCallback
    oboe::DataCallbackResult onAudioReady(oboe::AudioStream *oboeStream, void *audioData, int32_t numFrames) override;

private:
    std::shared_ptr<oboe::AudioStream> mStream;
    std::atomic<bool> mIsPlaying{false};
    std::atomic<float> mFrequency{440.0f};
    std::atomic<int> mWaveform{0}; // 0=Sine, 1=Square, 2=Sawtooth, 3=Triangle
    
    // Sweep state
    std::atomic<bool> mIsSweeping{false};
    std::atomic<bool> mLoopSweep{false};
    float mSweepStartFreq{440.0f};
    float mSweepEndFreq{440.0f};
    float mSweepDurationSec{0.0f};
    float mSweepTimePassed{0.0f};

    float mPhase{0.0f};
    int32_t mSampleRate{48000};
    
    std::mutex mLock;
};

#endif // SYNTH_ENGINE_H
