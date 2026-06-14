import wave
import struct
import math

sample_rate = 44100
duration = 0.05 # 50 ms
frequency = 1000.0

# Generate a short percussive beep
num_samples = int(sample_rate * duration)

with wave.open('c:/Users/sabak/Notefy/assets/audio/click.wav', 'w') as wav_file:
    wav_file.setnchannels(1)
    wav_file.setsampwidth(2)
    wav_file.setframerate(sample_rate)

    for i in range(num_samples):
        # Apply exponential decay envelope for a "click/percussive" sound
        envelope = math.exp(-i / (sample_rate * 0.015))
        value = int(envelope * 32767.0 * math.sin(2.0 * math.pi * frequency * i / sample_rate))
        data = struct.pack('<h', value)
        wav_file.writeframesraw(data)
