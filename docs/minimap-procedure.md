# RME Minimap Export for OTClient

Procedure to regenerate the client minimap PNGs when the OTBM (server map) changes.

## Prerequisites
- **RME (Remere's Map Editor)** — prebuilt at `C:\baiak-yourots\tools\rme-clientid\Editor_x64.exe`
  - Source: `https://github.com/h3ndrk/rme` (CLIENTID variant for OTClient compatibility)
  - DLLs already in same folder (35+ files: wxWidgets, boost, libarchive, freeglut, libpng, etc.)
- **Python 3.12+** with `Pillow` installed
- **Server `world.otbm`** at `C:\baiak-yourots\server\data\world\world.otbm`
- **7-Zip** (only for re-extracting RME build if needed)

## OTBM Extent
The current OTBM (`world.otbm`) covers:
- X: 722 - 1285 (564 tiles wide)
- Y: 791 - 1344 (554 tiles tall)
- Z: 0 - 15 (16 floors)

If the map changes, update `OTBM_X_MIN/OTBM_X_MAX/OTBM_Y_MIN/OTBM_Y_MAX` in the converter script.

## Procedure

### Step 1: Export minimap from RME
1. Run `C:\baiak-yourots\tools\rme-clientid\Editor_x64.exe`
2. **File → Open** → `C:\baiak-yourots\server\data\world\world.otbm`
3. **View → Minimap** (or Ctrl+M)
4. In the minimap window: **Minimap → Export...**
5. Save to `C:\baiak-yourots\server\data\world\` (will create `minimap_0.bmp` through `minimap_15.bmp`, one per floor)

RME exports 16 BMPs using the **6x6x6 web-safe palette** (216 colors) — the same cube the OTClient uses internally via `Color::to8bit/from8bit` in `client/src/framework/util/color.h:97-113`. This means PERFECT color roundtrip.

### Step 2: Convert BMPs to OTClient PNGs
```powershell
python C:\baiak-yourots\server\tools\rme_bmp_to_png.py
```

This script:
- Reads all `minimap_*.bmp` from `server/data/world/`
- Splits each 564x554 BMP into 256x256 sectors matching OTClient's expected `X_Y_Z.png` format
- Sets alpha=0 (transparent) for void tiles (palette index 0) so the minimap widget background shows through
- Saves to `C:\baiak-yourots\client\data\minimap\` (deletes old PNGs first)

Output: 192 PNGs (16 floors × ~12 sectors each) with exact RME colors.

### Step 3: Reset client + test
For a fresh load (recommended when map changes):
```powershell
# Kill client
Stop-Process -Name "AstraClient" -Force -ErrorAction SilentlyContinue

# Wipe user data (config, exploration, character data)
Remove-Item -Recurse -Force "$env:APPDATA\AstraClient"

# Open AstraClient fresh - it will load the new PNGs on startup
```

The client caches PNGs in memory at startup, so **always restart after regenerating**.

## Notes
- Void tiles (areas the OTBM doesn't define) appear as the minimap widget's background color (`color: black` in `client/data/styles/40-minimap.otui:89`).
- To change the void color, edit `40-minimap.otui:89` and replace `color: black` with e.g. `#1a3d6b` (dark water blue).
- Exploration (`minimap.otmm`) is per-account and stored in `$env:APPDATA\AstraClient\otclientv8\minimap.otmm`. Deleting it shows fresh colors; keeping it preserves which tiles you've already walked through.
- The previous RME build attempt (compiling from source) crashed with 0xC0000005 for unknown reasons — the prebuilt `Editor_x64.exe` works correctly.

## File locations
| What | Path |
|---|---|
| OTBM (source map) | `C:\baiak-yourots\server\data\world\world.otbm` |
| RME exports (input) | `C:\baiak-yourots\server\data\world\minimap_*.bmp` |
| OTClient PNGs (output) | `C:\baiak-yourots\client\data\minimap\X_Y_Z.png` |
| Minimap widget style | `C:\baiak-yourots\client\data\styles\40-minimap.otui:89` |
| Converter script | `C:\baiak-yourots\server\tools\rme_bmp_to_png.py` |
| RME binary | `C:\baiak-yourots\tools\rme-clientid\Editor_x64.exe` |
| Client user data | `%APPDATA%\AstraClient\` |
