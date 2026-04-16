# X-Scape Protocol

**X-Scape Protocol** is a **6502 Assembly NES game** developed for the course  
**CIIC 5995 – Selected Topics in Computer Science and Engineering (Spring 2026)**  
at the **University of Puerto Rico, Mayagüez**.

You control **Nibsy**, a lab-created creature attempting to escape a hostile underground facility.
> *Curious about the story? [Click here to read the story](LORE.md)*

## Technical Overview

This project is a **low-level game engine implementation** built under real NES hardware constraints, focusing on performance, memory efficiency, and deterministic systems design.
**Pure 6502 Assembly**

## Map Compression (2-bit Metatiles)

The NES has **very limited ROM space**. To store a 16×15 tilemap efficiently, the game uses **2-bit metatile compression**:

- Each **metatile** = 16×16 pixels (4 hardware tiles)
- Only **4 metatile types** are used: ground (00), wall A (01), wall B (10), grass (11)
- Each metatile is stored in **2 bits** → 4 metatiles per byte
- Total map size: **60 bytes** (instead of 240 bytes uncompressed)

### Tooling & Tile Memory Organization

Map layout, tile art, and memory arrangement were created using **[NEXXT Studio](https://frankengraphics.itch.io/nexxt)** , a modern NES graphics editor. 

<img width="814" height="669" alt="image" src="https://github.com/user-attachments/assets/f38c88e6-c6bb-4c2b-968a-3ee211b1247c" />

This tool allowed precise placement of each tile into its respective memory bank:

| Bank     | Address Range | Content           |
|----------|---------------|-------------------|
| Bank A   | `$0000-$0FF0` | Background tiles  |
| Bank B   | `$1000-$1FF0` | Sprite tiles      |

This separation is critical: the PPU fetches background tiles from Bank A and sprite tiles from Bank B simultaneously during rendering.

### Custom Python Converter

NEXXT exports maps in a **byte-per-tile format** (one byte per 8×8 tile). To achieve 2-bit metatile compression, a **custom Python script** was written:

1. Reads the NEXXT `.asm` export (960 bytes of tile data + 64 bytes of attribute table)
2. Groups tiles into **2×2 blocks** (one metatile)
3. Detects the metatile type by looking at the **top-left tile** of each block
4. Packs **4 metatiles into a single byte** (2 bits each)
5. Preserves the original attribute table unchanged

**Before (NEXXT export):**
```asm
map:
  .byte $01,$02,$05,$06,$05,$06,...  ; 960 bytes of tile data
  .byte $24,$06,$06,$36,...          ; 64 bytes of attribute table
```

**After (compressed format):**
``` asm
map1:
  .byte %01101010, %10101010, %10101010, %10101001  ; 60 bytes total
  .byte %10000000, %00001100, %00000000, %00110010
  ...
  .byte $24, $06, $06, $36, $06, $06, $C6, $42     ; attribute table

```

**The converter script:**
```python
import re

INPUT_FILE = "map.asm" # Map that NEXXT gives you in ASM format
OUTPUT_FILE = "map1.asm" # Output file with compressed nametable and original attribute table ;3

MAP_WIDTH_TILES = 32   # 16 metatiles * 2
MAP_HEIGHT_TILES = 30  # 15 metatiles * 2

# --- METATILE DETECTION (top-left tile) ---
def get_metatile(t0):
    if t0 == 0x00:
        return 0b00
    elif t0 == 0x01:
        return 0b01
    elif t0 == 0x05:
        return 0b10
    elif t0 == 0x09:
        return 0b11
    else:
        raise ValueError(f"Unknown tile: {t0:#02x}")

def parse_bytes(text):
    hex_values = re.findall(r"\$([0-9A-Fa-f]{2})", text)
    return [int(x, 16) for x in hex_values]

def main():
    with open(INPUT_FILE, "r") as f:
        data = f.read()

    all_bytes = parse_bytes(data)

    # --- Validation ---
    expected_tiles = MAP_WIDTH_TILES * MAP_HEIGHT_TILES
    if len(all_bytes) < expected_tiles + 64:
        raise ValueError("File does not have enough bytes for map + attribute table")

    # --- Separate nametable and attribute table ---
    nametable_tiles = all_bytes[:expected_tiles]
    attribute_bytes = all_bytes[expected_tiles:expected_tiles + 64]

    # --- Convert to grid ---
    grid = []
    for i in range(0, len(nametable_tiles), MAP_WIDTH_TILES):
        grid.append(nametable_tiles[i:i+MAP_WIDTH_TILES])

    metatiles = []

    # --- Read Metatiles (2x2) ---
    for y in range(0, MAP_HEIGHT_TILES, 2):
        row = []
        for x in range(0, MAP_WIDTH_TILES, 2):
            t0 = grid[y][x]  # top-left
            m = get_metatile(t0)
            row.append(m)
        metatiles.append(row)

    # --- Pack 4 Metatiles → 1 BYTE ---
    packed_bytes = []
    for row in metatiles:
        for i in range(0, len(row), 4):
            byte = (
                (row[i] << 6) |
                (row[i+1] << 4) |
                (row[i+2] << 2) |
                (row[i+3])
            )
            packed_bytes.append(byte)

    # --- Write Output ---
    with open(OUTPUT_FILE, "w") as f:
        f.write("map:\n")

        # Nametable (compressed)
        for i in range(0, len(packed_bytes), 4):
            line = packed_bytes[i:i+4]
            binary = [f"%{b:08b}" for b in line]
            f.write("  .byte " + ", ".join(binary) + "\n")

        # Attribute table ORIGINAL
        f.write("\n  ; ATTRIBUTE TABLE - 64 bytes\n")
        for i in range(0, 64, 8):
            line = attribute_bytes[i:i+8]
            hexs = [f"${b:02X}" for b in line]
            f.write("  .byte " + ", ".join(hexs) + "\n")

if __name__ == "__main__":
    main()
```

This pipeline allows rapid iteration: design the map visually in NEXXT, then run the converter to generate the compressed assembly code.

## Pseudo-Random System (8-bit LFSR)

The game uses an **8-bit Galois Linear Feedback Shift Register (LFSR)** for deterministic pseudo-randomness.

- **Polynomial:** `0xB8` (taps at bits 7, 5, 4, 3)
- **Cycle length:** 255 non-zero values
- **No repeated values** until full cycle completes

### Used for:

- **Item spawn positioning** – Coins, diamonds, and the key appear in random passable locations
- **Enemy 2 movement** – 100% random direction selection
- **Enemy 1 randomness** – 20% of the time, Dr. Morrow moves randomly instead of pursuing

The LFSR is **lightweight** (a few bytes and cycles) and produces "random enough" behavior without complex lookup tables.

## Sprite Scanline Limit & HUD Design

### The Hardware Constraint

The NES can only display **8 sprites per scanline**. Exceeding this causes:
- Sprite flickering
- Missing graphics
- Rendering instability

### The HUD Tradeoff

The score display (`SCR: 000`) alone uses **7 sprites**. Placing both `SCR: 000` and `VIT: ❤❤❤` on the same horizontal line would exceed the 8-sprite limit.

**Solution:** Split the HUD across **two scanlines**:
- Row 1 (`Y = $D7`): `SCR: 000`
- Row 2 (`Y = $DF`): `VIT: ❤❤❤`

Each row stays safely under 8 sprites.

### Game Over / Victory Rendering Technique

When showing **GAME OVER** or **YOU ESCAPED**:

1. The game **disables** (hides) the regular HUD sprites (`SCR` and `VIT`)
2. It then **activates** the message sprites in their place
3. Both messages blink using a timer (30 frames visible / 30 frames hidden)

This technique avoids exceeding sprite limits while reusing the same sprite OAM slots.

<img width="1918" height="943" alt="image" src="https://github.com/user-attachments/assets/0cc6a364-5741-495f-87c3-2eb159a07b99" />

## Tools & Technologies

- **[6502 Assembly](https://famicom.party/book/03-gettingstarted/)** – Core logic
- **[Mesen Emulator](https://www.mesen.ca/)** – Development and debugging
- **[NEXXT Studio](https://frankengraphics.itch.io/nexxt)** – Graphics, tile layout, and memory bank arrangement

## License

This project is licensed under the **MIT License**.
See the [LICENSE](LICENSE) file for details.

## Contact

If you have any questions or suggestions, feel free to reach out:

* **GitHub:** [Neowizen](https://github.com/Yamil-Serrano)
