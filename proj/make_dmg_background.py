#!/usr/bin/env python3
"""生成 DMG 背景图片"""
from PIL import Image, ImageDraw, ImageFont
import os

W, H = 540, 380
OUTPUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dmg_background.png")

img = Image.new("RGB", (W, H), (255, 255, 255))
draw = ImageDraw.Draw(img)

# 底部装饰线
for i in range(W):
    t = i / W
    r = int(180 + 40 * (1 - t))
    g = int(200 + 30 * t)
    b = int(230 + 15 * t)
    draw.line([(i, H - 60), (i, H - 58)], fill=(r, g, b))

# 主文字
text = "沐枫慕夏，倾情巨献"
try:
    font = ImageFont.truetype("/System/Library/Fonts/PingFang.ttc", 28)
except (IOError, OSError):
    try:
        font = ImageFont.truetype("/System/Library/Fonts/STHeiti Light.ttc", 28)
    except (IOError, OSError):
        font = ImageFont.load_default()

bbox = draw.textbbox((0, 0), text, font=font)
tw = bbox[2] - bbox[0]
th = bbox[3] - bbox[1]
tx = (W - tw) // 2
ty = H - 42

# 阴影
draw.text((tx + 1, ty + 1), text, fill=(200, 200, 210), font=font)
# 主体
draw.text((tx, ty), text, fill=(120, 130, 160), font=font)

img.save(OUTPUT)
print(f"背景图片已生成: {OUTPUT} ({W}x{H})")
