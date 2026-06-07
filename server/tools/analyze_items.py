"""Debug why minimap has 0 files."""
import struct

OTBM_PATH = r"C:\baiak-yourots\server\data\world\world.otbm"
OTB_PATH = r"C:\baiak-yourots\server\data\items\items.otb"
DAT_PATH = r"C:\baiak-yourots\client\data\things\860\Tibia.dat"

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
                node_end = pos + 1
                break
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

# Load OTB
_, _, root_children, _ = parse_tree(OTB_PATH)
otb_map = {}
for child in root_children:
    props = child['props']
    if len(props) < 4:
        continue
    pos = 4
    server_id = 0
    client_id = 0
    speed = 0
    while pos < len(props):
        if pos + 3 > len(props): break
        attr = props[pos]
        if attr == 0: break
        dl = struct.unpack_from('<H', props, pos + 1)[0]
        if pos + 3 + dl > len(props): break
        if attr == 0x10:
            server_id = struct.unpack_from('<H', props, pos + 3)[0]
        elif attr == 0x11:
            client_id = struct.unpack_from('<H', props, pos + 3)[0]
        elif attr == 0x0E:
            speed = struct.unpack_from('<H', props, pos + 3)[0]
        pos += 3 + dl
    if server_id:
        otb_map[server_id] = (client_id, speed)

# Load DAT colors
with open(DAT_PATH, 'rb') as f:
    dat = f.read()
dat_colors = {}
pos = 4
counts = [struct.unpack_from('<H', dat, pos + i*2)[0] for i in range(4)]
pos += 8

for cat in range(4):
    first_id = 100 if cat == 0 else 1
    for tid in range(first_id, counts[cat] + 1):
        while pos < len(dat):
            attr = dat[pos]; pos += 1
            if attr == 255: break
            if attr == 28:
                dat_colors[tid] = struct.unpack_from('<H', dat, pos)[0]; pos += 2
            elif attr == 21: pos += 4
            elif attr == 24: pos += 4
            elif attr == 25: pos += 2
            elif attr in (8, 9, 29, 32): pos += 2
            elif attr == 33:
                nl = struct.unpack_from('<H', dat, pos)[0]; pos += 2 + nl + 8
            elif attr == 38: pos += 32
        if pos >= len(dat): break
        w = dat[pos]; pos += 1
        h = dat[pos]; pos += 1
        if w > 1 or h > 1: pos += 1
        pos += 5  # layers + patterns + anim phases
        pos += w * h * dat[pos-5] * dat[pos-4] * dat[pos-3] * dat[pos-2] * dat[pos-1] * 2

# Check items found in OTBM
_, _, root_children, _ = parse_tree(OTBM_PATH)
otbm_items = set()
for child in root_children:
    if child['type'] != 2: continue
    for mc in child['children']:
        if mc['type'] != 4: continue
        p = mc['props']
        if len(p) < 5: continue
        for tn in mc['children']:
            if tn['type'] not in (5, 14): continue
            tp = tn['props']
            if len(tp) < 2: continue
            for it in tn['children']:
                if it['type'] == 6 and len(it['props']) >= 2:
                    otbm_items.add(struct.unpack_from('<H', it['props'], 0)[0])

print(f"Total unique item IDs in map: {len(otbm_items)}")
print(f"OTB mappings: {len(otb_map)}")
print(f"DAT colors: {len(dat_colors)}")

# Check each OTBM item
missing_in_otb = 0
no_color = 0
with_color = 0
for iid in sorted(otbm_items):
    if iid in otb_map:
        cid, spd = otb_map[iid]
        c16 = dat_colors.get(cid, 0)
        if c16:
            with_color += 1
        else:
            no_color += 1
    else:
        missing_in_otb += 1

print(f"Items in map: {len(otbm_items)}")
print(f"  Found in OTB: {len(otbm_items) - missing_in_otb}")
print(f"  Missing in OTB: {missing_in_otb}")
print(f"  With DAT color: {with_color}")
print(f"  Without DAT color: {no_color}")

# Check specific common items
for iid in [6218, 6217, 3682, 6216, 4445, 4458, 1082, 4448]:
    if iid in otbm_items:
        if iid in otb_map:
            cid, spd = otb_map[iid]
            c16 = dat_colors.get(cid, 0)
            print(f"  Item {iid}: OTB OK (cid={cid}, speed={spd}), DAT color={c16}")
        else:
            print(f"  Item {iid}: NOT IN OTB")
