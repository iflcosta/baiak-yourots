#!/usr/bin/env python3
"""Convert RME-exported BMP minimap to OTClient X_Y_Z.png sectors.

RME BMP: paletted 8bpp with 6x6x6 cube palette, one BMP per floor (z=0..15).
World origin: read from OTBM root header (offset 0x06: version u32, width u16, height u16).
Pixel (0,0) in the BMP = world (OTBM_X_MIN, OTBM_Y_MIN).

Each BMP is split into 256x256 sectors matching OTClient's expected format.
Void tiles (palette index 0 = black) are converted to transparent (alpha=0)
so the minimap widget's background color shows through.
"""
import os
import re
import struct
from PIL import Image

SRC = r"C:\baiak-yourots\server\data\world"
DST = r"C:\baiak-yourots\client\data\minimap"
OTBM = os.path.join(SRC, "world.otbm")
TS = 256


def read_otbm_extent(otbm_path):
    """Read OTBM root header: identifier(4) + START(1) + type(1) + version(4) + width(2) + height(2)."""
    with open(otbm_path, "rb") as f:
        data = f.read(16)
    # Offset 0x06 is the start of the root header (after 4-byte identifier + START + type)
    version = struct.unpack("<I", data[6:10])[0]
    width = struct.unpack("<H", data[10:12])[0]
    height = struct.unpack("<H", data[12:14])[0]
    return version, width, height


# Read extent from OTBM
otbm_version, otbm_width, otbm_height = read_otbm_extent(OTBM)
# Origin (0, 0) — confirmed from the OTBM root header for this map
OTBM_X_MIN = 0
OTBM_Y_MIN = 0
OTBM_X_MAX = OTBM_X_MIN + otbm_width - 1
OTBM_Y_MAX = OTBM_Y_MIN + otbm_height - 1
print(f"OTBM v{otbm_version}: width={otbm_width}, height={otbm_height}")
print(f"World extent: x=[{OTBM_X_MIN}, {OTBM_X_MAX}], y=[{OTBM_Y_MIN}, {OTBM_Y_MAX}]")

# Remove existing PNGs (clean slate for the new map)
removed = 0
for fname in os.listdir(DST):
    if fname.endswith(".png"):
        os.remove(os.path.join(DST, fname))
        removed += 1
print(f"Removed {removed} old PNGs")

# Process each BMP
generated = 0
pattern = re.compile(r"^minimap_(\d+)\.bmp$")
for fname in sorted(os.listdir(SRC)):
    m = pattern.match(fname)
    if not m:
        continue
    z = int(m.group(1))
    src_path = os.path.join(SRC, fname)
    img = Image.open(src_path)
    img = img.convert("RGBA")
    w, h = img.size
    print(f"Processing z={z}: {w}x{h} BMP")

    # For each sector that intersects the OTBM extent
    for sector_y in range(OTBM_Y_MIN // 256, (OTBM_Y_MAX // 256) + 1):
        for sector_x in range(OTBM_X_MIN // 256, (OTBM_X_MAX // 256) + 1):
            world_x0 = sector_x * 256
            world_y0 = sector_y * 256
            bmp_x0 = world_x0 - OTBM_X_MIN
            bmp_y0 = world_y0 - OTBM_Y_MIN
            bmp_x1 = bmp_x0 + 256
            bmp_y1 = bmp_y0 + 256

            src_x0 = max(0, bmp_x0)
            src_y0 = max(0, bmp_y0)
            src_x1 = min(w, bmp_x1)
            src_y1 = min(h, bmp_y1)

            if src_x0 >= src_x1 or src_y0 >= src_y1:
                continue

            sector_img = Image.new("RGBA", (TS, TS), (0, 0, 0, 0))
            crop = img.crop((src_x0, src_y0, src_x1, src_y1))
            paste_x = src_x0 - bmp_x0
            paste_y = src_y0 - bmp_y0
            sector_img.paste(crop, (paste_x, paste_y))
            # Void tiles (black) → transparent
            pixels = sector_img.load()
            for py in range(TS):
                for px in range(TS):
                    r, g, b, a = pixels[px, py]
                    if r == 0 and g == 0 and b == 0:
                        pixels[px, py] = (0, 0, 0, 0)

            out_name = f"{sector_x}_{sector_y}_{z}.png"
            sector_img.save(os.path.join(DST, out_name), "PNG", optimize=False)
            generated += 1

print(f"Generated {generated} PNG sectors from RME BMPs")
