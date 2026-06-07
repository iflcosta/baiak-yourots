#!/usr/bin/env python3
"""Convert RME-exported BMP minimap to OTClient X_Y_Z.png sectors.

RME BMP: 564x554 (one per floor), paletted mode with 6x6x6 cube palette
OTBM extent: x=722-1285, y=791-1344 (so BMP pixel 0,0 = world 722, 791)

Each BMP is split into 256x256 sectors matching OTClient's expected format.
Void tiles (palette index 0 = black) are preserved as black (alpha=255) so
they overlay on the minimap widget's background.
"""
import os
import re
from PIL import Image

SRC = r"C:\baiak-yourots\server\data\world"
DST = r"C:\baiak-yourots\client\data\minimap"
TS = 256

# OTBM extent (from generate_minimap.py analysis)
OTBM_X_MIN = 722
OTBM_Y_MIN = 791
OTBM_X_MAX = 1285
OTBM_Y_MAX = 1344

# Remove existing PNGs (we have a cleaner set now)
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
    img = img.convert("RGBA")  # use palette to RGBA
    w, h = img.size
    print(f"Processing z={z}: {w}x{h} BMP")

    # For each sector that intersects the OTBM extent
    # Sector X covers world x in [X*256, X*256+255]
    # Sector Y covers world y in [Y*256, Y*256+255]
    for sector_y in range(OTBM_Y_MIN // 256, (OTBM_Y_MAX // 256) + 1):
        for sector_x in range(OTBM_X_MIN // 256, (OTBM_X_MAX // 256) + 1):
            # World bounds for this sector
            world_x0 = sector_x * 256
            world_y0 = sector_y * 256
            # BMP pixel bounds for this sector
            bmp_x0 = world_x0 - OTBM_X_MIN
            bmp_y0 = world_y0 - OTBM_Y_MIN
            bmp_x1 = bmp_x0 + 256
            bmp_y1 = bmp_y0 + 256

            # Clip to BMP bounds
            src_x0 = max(0, bmp_x0)
            src_y0 = max(0, bmp_y0)
            src_x1 = min(w, bmp_x1)
            src_y1 = min(h, bmp_y1)

            if src_x0 >= src_x1 or src_y0 >= src_y1:
                continue

            # Create 256x256 RGBA PNG (filled with alpha=0 = transparent)
            sector_img = Image.new("RGBA", (TS, TS), (0, 0, 0, 0))
            # Crop the relevant region from BMP
            crop = img.crop((src_x0, src_y0, src_x1, src_y1))
            # Paste into the correct position in the sector
            paste_x = src_x0 - bmp_x0
            paste_y = src_y0 - bmp_y0
            sector_img.paste(crop, (paste_x, paste_y))
            # Convert void tiles (black) to transparent so minimap widget background shows through
            pixels = sector_img.load()
            for py in range(TS):
                for px in range(TS):
                    r, g, b, a = pixels[px, py]
                    if r == 0 and g == 0 and b == 0:
                        pixels[px, py] = (0, 0, 0, 0)

            # Save as PNG
            out_name = f"{sector_x}_{sector_y}_{z}.png"
            sector_img.save(os.path.join(DST, out_name), "PNG", optimize=False)
            generated += 1

print(f"Generated {generated} PNG sectors from RME BMPs")
