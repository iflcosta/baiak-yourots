#!/usr/bin/env python3
"""Generate OTClient .minimap files from OTBM using OTB + DAT 8.6.
DAT parser based on OTClient ThingType::unserialize in C++."""
import struct
import os
import sys

MINIMAP_DIR = r"C:\baiak-yourots\client\data\minimap"
OTBM_PATH = r"C:\baiak-yourots\server\data\world\world.otbm"
DAT_PATH = r"C:\baiak-yourots\client\data\things\860\Tibia.dat"
OTB_PATH = r"C:\baiak-yourots\server\data\items\items.otb"
START = 0xFE; END = 0xFF; ESCAPE = 0xFD

def parse_tree(path):
    with open(path, 'rb') as f:
        data = f.read()
    def read_node(start):
        if data[start] != START:
            raise ValueError(f"Expected START at {start}")
        typ = data[start + 1]
        pos = start + 2
        children = []
        while pos < len(data):
            if data[pos] == END:
                node_end = pos + 1; break
            elif data[pos] == START:
                ct, cp, cch, ce = read_node(pos)
                children.append({'type': ct, 'props': cp, 'children': cch})
                pos = ce
            elif data[pos] == ESCAPE:
                pos += 2
            else:
                pos += 1
        else:
            raise ValueError("Unterminated node")
        raw = data[start + 2:pos]
        unesc = bytearray()
        i = 0
        while i < len(raw):
            if raw[i] == ESCAPE:
                unesc.append(raw[i+1]); i += 2
            else:
                unesc.append(raw[i]); i += 1
        return typ, bytes(unesc), children, node_end
    return read_node(4)

def load_otb_mappings():
    _, _, root_children, _ = parse_tree(OTB_PATH)
    mappings = {}
    for child in root_children:
        props = child['props']
        if len(props) < 4: continue
        sid, speed = 0, 0
        pos = 4
        while pos < len(props):
            if pos + 3 > len(props): break
            attr = props[pos]
            if attr == 0: break
            dl = struct.unpack_from('<H', props, pos + 1)[0]
            if pos + 3 + dl > len(props): break
            if attr == 0x10:
                sid = struct.unpack_from('<H', props, pos + 3)[0]
            elif attr == 0x0E:
                speed = struct.unpack_from('<H', props, pos + 3)[0]
            pos += 3 + dl
        if sid:
            mappings[sid] = {'speed': speed}
    return mappings

def load_dat_colors_and_speeds():
    """Parse Tibia 8.6 DAT format based on OTClient's ThingType::unserialize."""
    with open(DAT_PATH, 'rb') as f:
        data = f.read()
    size = len(data)

    pos = 4  # skip signature
    counts = []
    for c in range(4):
        cnt = struct.unpack_from('<H', data, pos)[0]
        pos += 2
        counts.append(cnt)

    ATTR_SIZES = {
        0: 2, 8: 2, 9: 2, 21: 4, 24: 4, 25: 2, 28: 2,
        29: 2, 32: 2, 33: -1, 34: 2, 38: 16,
    }

    colors = {}  # client_id -> minimap_color16
    speeds = {}  # client_id -> ground_speed

    for cat in range(4):
        first_id = 100 if cat == 0 else 1
        n_items = counts[cat] + 1
        if n_items <= first_id:
            continue
        for tid in range(first_id, n_items):
            if pos >= size:
                return colors, speeds
            while pos < size:
                attr = data[pos]; pos += 1
                if attr == 255:
                    break
                size_of_value = ATTR_SIZES.get(attr, 0)
                if size_of_value == 0:
                    pass
                elif size_of_value > 0:
                    if pos + size_of_value > size:
                        return colors, speeds
                    if cat == 0:
                        if attr == 0:
                            speeds[tid] = struct.unpack_from('<H', data, pos)[0]
                        elif attr == 28:
                            colors[tid] = struct.unpack_from('<H', data, pos)[0]
                    pos += size_of_value
                elif size_of_value == -1:
                    if pos + 10 > size:
                        return colors, speeds
                    pos += 6
                    slen = struct.unpack_from('<H', data, pos)[0]
                    pos += 2 + slen + 4
    return colors, speeds

def speed_to_color(speed):
    if speed <= 0: return b'\x00\x00\x00\x00'
    if speed < 50: return struct.pack('BBBB', 0x00,0x33,0x66,0xFF)
    elif speed < 80: return struct.pack('BBBB', 0x33,0x66,0x33,0xFF)
    elif speed < 100: return struct.pack('BBBB', 0x4C,0x99,0x33,0xFF)
    elif speed < 120: return struct.pack('BBBB', 0x66,0xCC,0x66,0xFF)
    elif speed < 140: return struct.pack('BBBB', 0x99,0xCC,0x99,0xFF)
    elif speed < 180: return struct.pack('BBBB', 0xCC,0xCC,0x99,0xFF)
    elif speed < 200: return struct.pack('BBBB', 0xE6,0xCC,0x99,0xFF)
    elif speed < 250: return struct.pack('BBBB', 0xCC,0x99,0x66,0xFF)
    else: return struct.pack('BBBB', 0xAA,0xAA,0xAA,0xFF)

def rgb565_to_rgba(c16):
    r = ((c16>>11)&0x1F)*255//31
    g = ((c16>>5)&0x3F)*255//63
    b = (c16&0x1F)*255//31
    return struct.pack('BBBB', r, g, b, 0xFF)

def parse_otbm(path):
    _, root_props, root_children, _ = parse_tree(path)
    if len(root_props) >= 16:
        version, width, height = struct.unpack_from('<IHH', root_props, 0)
        print(f"Map: {width}x{height}, version={version}", flush=True)
    else:
        width, height = 0, 0

    tiles = {}
    for child in root_children:
        if child['type'] != 2: continue
        for mc in child['children']:
            if mc['type'] != 4: continue
            p = mc['props']
            if len(p) < 5: continue
            bx = struct.unpack_from('<H', p, 0)[0]
            by = struct.unpack_from('<H', p, 2)[0]
            bz = p[4]
            for tn in mc['children']:
                if tn['type'] not in (5, 14): continue
                tp = tn['props']
                if len(tp) < 2: continue
                ax = bx + tp[0]
                ay = by + tp[1]
                for it in tn['children']:
                    if it['type'] == 6 and len(it['props']) >= 2:
                        iid = struct.unpack_from('<H', it['props'], 0)[0]
                        key = (ax, ay, bz)
                        if key not in tiles:
                            tiles[key] = iid
    return tiles, width, height

def generate_minimap(tiles, sid_to_color):
    TS = 256
    reg = {}
    for (x, y, z), sid in tiles.items():
        c = sid_to_color.get(sid, b'\x00\x00\x00\x00')
        ax, ay = x // TS, y // TS
        key = (ax, ay)
        if key not in reg:
            reg[key] = {}
        reg[key][(x % TS, y % TS, z)] = c

    if not os.path.exists(MINIMAP_DIR):
        os.makedirs(MINIMAP_DIR)

    count = 0
    for (ax, ay), tc in reg.items():
        for z in range(16):
            fname = f"floor-{ax}-{ay}-{z}.minimap"
            fp = os.path.join(MINIMAP_DIR, fname)
            data = bytearray(TS * TS * 4)
            p = 0
            for py in range(TS):
                for px in range(TS):
                    k = (px, py, z)
                    if k in tc:
                        data[p:p+4] = tc[k]
                    p += 4
            if any(data[i] != 0 for i in range(0, len(data), 4)):
                with open(fp, 'wb') as f:
                    f.write(data)
                count += 1
    return count

if __name__ == '__main__':
    print("Loading OTB mappings...", flush=True)
    otb = load_otb_mappings()
    print(f"  {len(otb)} items", flush=True)

    print("Loading DAT colors & speeds...", flush=True)
    dat_colors, dat_speeds = load_dat_colors_and_speeds()
    print(f"  {len(dat_colors)} colors, {len(dat_speeds)} speeds", flush=True)

    print("Loading OTBM tiles...", flush=True)
    tiles, w, h = parse_otbm(OTBM_PATH)
    print(f"  {len(tiles)} tiles", flush=True)

    missing = sum(1 for sid in set(tiles.values()) if sid not in dat_colors and sid not in dat_speeds)
    print(f"  {missing} tile SIDs without color or speed (will be transparent)", flush=True)

    print("Building color map...", flush=True)
    sid_color = {}
    for sid in set(tiles.values()):
        if sid in dat_colors:
            sid_color[sid] = rgb565_to_rgba(dat_colors[sid])
        elif sid in dat_speeds:
            sid_color[sid] = speed_to_color(dat_speeds[sid])

    print("Generating .minimap files...", flush=True)
    n = generate_minimap(tiles, sid_color)
    print(f"  {n} .minimap files written to {MINIMAP_DIR}", flush=True)
