#!/usr/bin/env python3
"""Sunset app icon: a violet-to-gold sky, a half-set sun on a dark horizon.

Rendered at 4x and downsampled so the sun's edge stays crisp at small sizes.
Writes Sunset/Assets.xcassets/AppIcon.appiconset/AppIcon.png (1024, no alpha).
"""

import os

from PIL import Image, ImageDraw

SS = 4
SIZE = 1024
S = SIZE * SS
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Sunset", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")

TOP = (0x33, 0x1A, 0x6B)
MID = (0xDB, 0x38, 0x70)
LOW = (0xFF, 0x9E, 0x33)
SUN = (0xFF, 0xE2, 0x8A)
GROUND = (0x16, 0x10, 0x2A)
GROUND_TOP = (0x24, 0x18, 0x3E)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def sky(y, horizon):
    t = y / horizon
    if t < 0.55:
        return lerp(TOP, MID, t / 0.55)
    return lerp(MID, LOW, (t - 0.55) / 0.45)


def main():
    img = Image.new("RGB", (S, S), TOP)
    draw = ImageDraw.Draw(img)
    horizon = int(S * 0.72)
    for y in range(horizon):
        draw.line([(0, y), (S, y)], fill=sky(y, horizon))

    # Sun, with a soft glow, clipped by the horizon.
    cx, cy, r = S // 2, horizon, int(S * 0.21)
    glow = Image.new("RGB", (S, S), (0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    for i in range(12, 0, -1):
        rr = r + i * int(S * 0.012)
        alpha = int(26 * (1 - i / 12) ** 1.4)
        gdraw.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(alpha, alpha // 2, 0))
    img = Image.blend(img, Image.eval(glow, lambda v: v), 0) if False else img
    img_px = img.load()
    glow_px = glow.load()
    for y in range(horizon):
        for x in range(S):
            g = glow_px[x, y]
            if g[0]:
                p = img_px[x, y]
                img_px[x, y] = (min(255, p[0] + g[0]), min(255, p[1] + g[1]), p[2])
    draw = ImageDraw.Draw(img)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=SUN)

    # Ground with a gentle hill.
    for y in range(horizon, S):
        t = (y - horizon) / (S - horizon)
        draw.line([(0, y), (S, y)], fill=lerp(GROUND_TOP, GROUND, t))
    hill = [(0, horizon + int(S * 0.02))]
    for x in range(0, S + 1, S // 64):
        import math
        yy = horizon - int(S * 0.035 * math.sin(math.pi * x / S))
        hill.append((x, yy))
    hill += [(S, S), (0, S)]
    draw.polygon(hill, fill=GROUND_TOP)

    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT, "PNG")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
