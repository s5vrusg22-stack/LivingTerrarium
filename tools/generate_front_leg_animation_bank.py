#!/usr/bin/env python3
"""Generate 100 loopable, keyframed raptorial-foreleg motion clips."""
from __future__ import annotations

import json
import math
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[1]
OUTPUT = PROJECT / "assets" / "animations" / "front_leg_100.json"
COUNT = 100
KEYFRAME_COUNT = 9
CHANNELS = [
    "femur_pitch_L", "femur_yaw_L", "femur_roll_L",
    "tibia_fold_L", "tibia_sweep_L", "tibia_roll_L",
    "femur_pitch_R", "femur_yaw_R", "femur_roll_R",
    "tibia_fold_R", "tibia_sweep_R", "tibia_roll_R",
]


def make_clip(index: int) -> dict:
    family, variation = divmod(index, 20)
    phase_offset = math.tau * variation / 20.0
    amplitude = 0.78 + variation * 0.022
    duration = 1.35 + (variation % 7) * 0.19 + family * 0.12
    frames = []
    for frame_index in range(KEYFRAME_COUNT):
        cycle = frame_index / (KEYFRAME_COUNT - 1)
        frame = []
        for side_index in range(2):
            side_sign = -1.0 if side_index == 0 else 1.0
            side_phase = phase_offset + (0.31 if side_index == 1 else 0.0)
            wave = math.sin(math.tau * cycle + side_phase)
            wave_2 = math.sin(math.tau * cycle * 2.0 + side_phase * 0.73)
            exponent = 1.15 + (variation % 5) * 0.11
            pulse = max(0.0, math.sin(math.tau * cycle + side_phase)) ** exponent
            if family == 0:  # Sensory probing
                values = (
                    -0.035 + wave * 0.105 * amplitude,
                    side_sign * (0.095 + wave_2 * 0.055 * amplitude),
                    side_sign * wave * 0.035 * amplitude,
                    0.36 + 0.13 * (0.5 + 0.5 * wave_2) * amplitude,
                    -side_sign * wave * 0.075 * amplitude,
                    -side_sign * wave_2 * 0.025,
                )
            elif family == 1:  # Grasp and release
                values = (
                    -0.12 - pulse * 0.30 * amplitude,
                    side_sign * (0.055 + pulse * 0.145 * amplitude),
                    side_sign * pulse * 0.075 * amplitude,
                    0.22 + pulse * 0.78 * amplitude,
                    -side_sign * (0.04 + pulse * 0.11),
                    side_sign * (0.025 + pulse * 0.045),
                )
            elif family == 2:  # Grooming strokes
                values = (
                    -0.48 + wave * 0.16 * amplitude,
                    side_sign * (0.13 + wave * 0.105 * amplitude),
                    side_sign * wave_2 * 0.075 * amplitude,
                    0.65 + abs(wave) * 0.23 * amplitude,
                    -side_sign * wave * 0.18 * amplitude,
                    side_sign * wave_2 * 0.055,
                )
            elif family == 3:  # Alert and display fan
                values = (
                    -0.24 + wave * 0.22 * amplitude,
                    side_sign * (0.19 + wave_2 * 0.125 * amplitude),
                    side_sign * (0.055 + wave * 0.075 * amplitude),
                    0.48 + 0.20 * (0.5 + 0.5 * wave) * amplitude,
                    -side_sign * (0.10 + wave_2 * 0.11 * amplitude),
                    -side_sign * wave * 0.05,
                )
            else:  # Strike and recover
                values = (
                    -0.08 - pulse * 0.86 * amplitude,
                    side_sign * (0.045 + pulse * 0.205 * amplitude),
                    side_sign * pulse * 0.10 * amplitude,
                    0.78 - pulse * 0.62 * amplitude,
                    -side_sign * pulse * 0.14 * amplitude,
                    side_sign * pulse * 0.065,
                )
            frame.extend(round(value, 6) for value in values)
        frames.append(frame)
    return {
        "name": f"Foreleg_{index + 1:03d}",
        "family": ("probe", "grasp", "groom", "display", "strike")[family],
        "duration": round(duration, 3),
        "loop": True,
        "keyframes": frames,
    }


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    data = {
        "version": "v3.7",
        "keyframe_count": KEYFRAME_COUNT,
        "channels": CHANNELS,
        "interpolation": "linear",
        "animations": [make_clip(index) for index in range(COUNT)],
    }
    OUTPUT.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {COUNT} unique {KEYFRAME_COUNT}-keyframe front-leg clips to {OUTPUT.relative_to(PROJECT)}")


if __name__ == "__main__":
    main()
