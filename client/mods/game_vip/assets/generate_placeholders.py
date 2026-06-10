"""Generate placeholder PNG badges for the VIP panel.

Run from anywhere — outputs to:
  client/mods/game_vip/assets/*.png

Pure-PIL, no external resources. The badges are simple colored circles
with text labels, kept tiny (64x64) and self-contained.
"""

import os
from PIL import Image, ImageDraw, ImageFont

OUT_DIR = r"C:\baiak-yourots\client\mods\game_vip\assets"
SIZE = 64

# (filename, fill_color, text_color, label)
BADGES = [
    ("badge-bronze.png", (205, 127, 50),  (255, 255, 255), "B"),
    ("badge-silver.png", (192, 192, 192),  (32, 32, 32),    "S"),
    ("badge-gold.png",   (255, 215, 0),    (40, 30, 0),     "G"),
    ("vip-icon.png",     (124, 58, 237),   (255, 255, 255), "VIP"),
    ("vip-icon-empty.png", (40, 40, 48),   (110, 110, 120), "—"),
]

os.makedirs(OUT_DIR, exist_ok=True)

# Try to find a usable font; fall back to default if missing.
def get_font(size: int) -> ImageFont.ImageFont:
    candidates = [
        r"C:\Windows\Fonts\segoeuib.ttf",   # Segoe UI Bold
        r"C:\Windows\Fonts\arialbd.ttf",    # Arial Bold
        r"C:\Windows\Fonts\arial.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def make_badge(name: str, fill, text_color, label: str) -> None:
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Outer ring
    draw.ellipse((2, 2, SIZE - 3, SIZE - 3), fill=fill, outline=(0, 0, 0, 100), width=2)

    # Inner highlight (top arc)
    overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    overlay_draw = ImageDraw.Draw(overlay)
    overlay_draw.ellipse((6, 6, SIZE - 7, SIZE - 7), fill=(255, 255, 255, 60))
    img = Image.alpha_composite(img, overlay)
    draw = ImageDraw.Draw(img)

    # Text
    font_size = 22 if len(label) <= 2 else 13
    font = get_font(font_size)
    bbox = draw.textbbox((0, 0), label, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = (SIZE - tw) // 2 - bbox[0]
    y = (SIZE - th) // 2 - bbox[1]
    draw.text((x, y), label, fill=text_color, font=font)

    out_path = os.path.join(OUT_DIR, name)
    img.save(out_path, "PNG")
    print(f"  wrote {out_path}")


def main() -> None:
    print(f"Generating VIP badges in {OUT_DIR}")
    for name, fill, text, label in BADGES:
        make_badge(name, fill, text, label)
    print("Done.")


if __name__ == "__main__":
    main()
