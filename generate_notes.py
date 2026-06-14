import wave
import struct
import math
import os

sample_rate = 44100
duration = 1.5 # 1.5 seconds per note
volume = 32767.0 * 0.5 # 50% volume

# Note names and starting from C0 (approx 16.35 Hz)
# E2 is MIDI note 40, E6 is MIDI note 88
note_names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']

out_dir = 'c:/Users/sabak/Notefy/assets/audio/notes'
os.makedirs(out_dir, exist_ok=True)

def generate_note(midi_note):
    octave = (midi_note // 12) - 1
    note_name = note_names[midi_note % 12]
    filename = f"{note_name}{octave}.wav".replace('#', 's')
    
    # Calculate frequency
    freq = 440.0 * (2.0 ** ((midi_note - 69) / 12.0))
    
    num_samples = int(sample_rate * duration)
    
    filepath = os.path.join(out_dir, filename)
    with wave.open(filepath, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)

        for i in range(num_samples):
            # Pluck envelope
            t = i / sample_rate
            envelope = math.exp(-t * 3.0)
            
            # Simple additive synthesis for guitar-like tone
            fundamental = math.sin(2.0 * math.pi * freq * t)
            harm1 = 0.5 * math.sin(2.0 * math.pi * freq * 2 * t)
            harm2 = 0.25 * math.sin(2.0 * math.pi * freq * 3 * t)
            harm3 = 0.125 * math.sin(2.0 * math.pi * freq * 4 * t)
            
            signal = (fundamental + harm1 + harm2 + harm3) / 1.875
            
            value = int(envelope * volume * signal)
            
            # Clip
            if value > 32767: value = 32767
            elif value < -32768: value = -32768
                
            data = struct.pack('<h', value)
            wav_file.writeframesraw(data)
            
    print(f"Generated {filename} ({freq:.2f} Hz)")

# Generate from E2 (40) to E6 (88)
for n in range(40, 89):
    generate_note(n)

print("Done generating notes!")
