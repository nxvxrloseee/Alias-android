#!/usr/bin/env python3
"""Рисует иконку приложения: белая карточка с буквой «Э» на зелёном сукне."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
S = 1024
FELT, DEEP, CARD, INK, GOLD = (27, 74, 61), (20, 58, 48), (251, 250, 246), (29, 36, 34), (242, 182, 50)

def card_layer(angle, fill, offset):
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    w, h = 520, 640
    x0, y0 = (S - w) // 2 + offset[0], (S - h) // 2 + offset[1]
    d.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=70, fill=fill)
    return layer.rotate(angle, resample=Image.BICUBIC, center=(S // 2, S // 2))

img = Image.new("RGBA", (S, S), FELT)
img.alpha_composite(card_layer(14, (*GOLD, 255), (40, 10)))
img.alpha_composite(card_layer(-6, (*CARD, 255), (-20, 0)))
text = Image.new("RGBA", (S, S), (0, 0, 0, 0))
# статичный шрифт: у вариативного Unbounded Pillow рисует перекрытия контуров с дырами
font = ImageFont.truetype("/usr/share/fonts/noto/NotoSans-Black.ttf", 460)
td = ImageDraw.Draw(text)
td.text((S // 2 - 20, S // 2 + 10), "Э", font=font, fill=INK, anchor="mm")
img.alpha_composite(text.rotate(-6, resample=Image.BICUBIC, center=(S // 2, S // 2)))

res = ROOT / "android/app/src/main/res"
for folder, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    img.convert("RGB").resize((px, px), Image.LANCZOS).save(res / f"mipmap-{folder}/ic_launcher.png")
ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
for f in ios.glob("*.png"):
    with Image.open(f) as old:
        size = old.size
    img.convert("RGB").resize(size, Image.LANCZOS).save(f)
img.convert("RGB").save(ROOT / "tool/icon_1024.png")
print("ok")
