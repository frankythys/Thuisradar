"""Generate original notification tones; no external recordings or dependencies."""
import math
import struct
import wave
from pathlib import Path

OUTPUT = Path(__file__).resolve().parents[1] / 'android/app/src/main/res/raw'
RATE = 22050


def write(name, duration, sample):
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUTPUT / f'{name}.wav'), 'wb') as audio:
        audio.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        audio.writeframes(b''.join(
            struct.pack('<h', round(26000 * sample(i / RATE)))
            for i in range(round(duration * RATE))
        ))


def alarm(t):
    # Six distinct alternating pulses, with ramps to avoid clicks.
    pulse = t % 0.75
    if pulse >= 0.6:
        return 0
    envelope = min(1, pulse / 0.02, (0.6 - pulse) / 0.04)
    frequency = 880 if int(t / 0.75) % 2 == 0 else 1174
    return envelope * (0.8 * math.sin(2 * math.pi * frequency * t)
                       + 0.2 * math.sin(4 * math.pi * frequency * t))


def message(t):
    local = t if t < 0.25 else t - 0.25
    frequency = 784 if t < 0.25 else 1047
    return min(1, local / 0.008) * math.exp(-7 * local) * math.sin(2 * math.pi * frequency * local)


write('thuisradar_sos', 4.5, alarm)
write('thuisradar_message', 0.9, message)
