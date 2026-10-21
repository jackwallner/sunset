#!/usr/bin/env python3
"""Play listing art: the 512 icon (from the iOS 1024 icon) and the 1024 x 500
feature graphic, a sunset sky with the half-set sun and the app's pitch.
Writes android/play-assets/graphics/. Needs Pillow."""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "android", "play-assets", "graphics")
FONT = os.path.join(ROOT, "android", "app", "src", "main", "res", "font", "nunito.ttf")

TOP = (0x33, 0x1A, 0x6B)
MID = (0xDB, 0x38, 0x70)
LOW = (0xFF, 0x9E, 0x33)
SUN = (0xFF, 0xE2, 0x8A)
GROUND = (0x16, 0x10, 0x2A)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def font(size, weight):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def icon():
    src = Image.open(os.path.join(ROOT, "Sunset", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")).convert("RGB")
    src.resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, "icon-512.png"))


def feature():
    w, h, s = 1024, 500, 2
    W, H = w * s, h * s
    img = Image.new("RGB", (W, H), TOP)
    d = ImageDraw.Draw(img)
    horizon = int(H * 0.74)
    for y in range(horizon):
        t = y / horizon
        d.line([(0, y), (W, y)], fill=lerp(TOP, MID, t / 0.55) if t < 0.55 else lerp(MID, LOW, (t - 0.55) / 0.45))
    for y in range(horizon, H):
        d.line([(0, y), (W, y)], fill=lerp((0x24, 0x18, 0x3E), GROUND, (y - horizon) / (H - horizon)))
    cx, r = int(W * 0.76), int(H * 0.26)
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse([cx - r * 1.6, horizon - r * 1.6, cx + r * 1.6, horizon + r * 1.6], fill=110)
    glow = glow.filter(ImageFilter.GaussianBlur(60 * s))
    img = Image.composite(Image.new("RGB", (W, H), SUN), img, glow)
    d = ImageDraw.Draw(img)
    d.pieslice([cx - r, horizon - r, cx + r, horizon + r], 180, 360, fill=SUN)
    d.rectangle([0, horizon, W, H], fill=None)
    for y in range(horizon, H):
        d.line([(0, y), (W, y)], fill=lerp((0x24, 0x18, 0x3E), GROUND, (y - horizon) / (H - horizon)))
    x = int(W * 0.07)
    d.text((x, int(H * 0.17)), "Sunset", font=font(118 * s // 1, 800), fill="white")
    d.text((x, int(H * 0.17) + 150 * s), "A score for every sunrise", font=font(40 * s, 700), fill=(255, 255, 255))
    d.text((x, int(H * 0.17) + 205 * s), "and sunset, with free alerts", font=font(40 * s, 700), fill=(255, 255, 255))
    img.resize((w, h), Image.LANCZOS).save(os.path.join(OUT, "feature-1024x500.png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    icon()
    feature()
    print("wrote", OUT)
