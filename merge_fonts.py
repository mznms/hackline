#!/usr/bin/env python3
"""
HackLine Font Generator v3
Merges Hack (Latin) and LINE Seed JP (Japanese) to create HackLine.
Uses proper GlyphCoordinates for scaled glyphs.
"""

import sys
import os
import copy
from fontTools.ttLib import TTFont
from fontTools.ttLib.tables._g_l_y_f import GlyphCoordinates

# Paths
HACK_REGULAR = "hack_font/ttf/Hack-Regular.ttf"
HACK_BOLD = "hack_font/ttf/Hack-Bold.ttf"
LINE_SEED_JP_REGULAR = "line_seed_font/LINESeedJP_20241105/Desktop/TTF/LINESeedJP_TTF_Rg.ttf"
LINE_SEED_JP_BOLD = "line_seed_font/LINESeedJP_20241105/Desktop/TTF/LINESeedJP_TTF_Bd.ttf"

OUTPUT_REGULAR = "build/HackLine-Regular.ttf"
OUTPUT_BOLD = "build/HackLine-Bold.ttf"

# Japanese Unicode ranges (Hiragana, Katakana, CJK, etc.)
JAPANESE_RANGES = [
    (0x3000, 0x303F),  # CJK Symbols and Punctuation
    (0x3040, 0x309F),  # Hiragana
    (0x30A0, 0x30FF),  # Katakana
    (0x31F0, 0x31FF),  # Katakana Phonetic Extensions
    (0x4E00, 0x9FFF),  # CJK Unified Ideographs
    (0xFF00, 0xFFEF),  # Halfwidth and Fullwidth Forms
    (0x2E80, 0x2EFF),  # CJK Radicals Supplement
    (0x3400, 0x4DBF),  # CJK Unified Ideographs Extension A
]


def is_japanese_codepoint(cp):
    """Check if codepoint is in Japanese ranges."""
    for start, end in JAPANESE_RANGES:
        if start <= cp <= end:
            return True
    return False


def scale_glyph(glyph, scale, glyf_table):
    """Scale a glyph's coordinates and bounds."""
    if glyph.numberOfContours == 0:
        # Empty glyph
        return glyph
    
    if glyph.numberOfContours == -1:
        # Composite glyph - scale all components
        if hasattr(glyph, 'components') and glyph.components:
            for comp in glyph.components:
                # Scale the offset
                if hasattr(comp, 'x'):
                    comp.x = int(comp.x * scale)
                if hasattr(comp, 'y'):
                    comp.y = int(comp.y * scale)
        return glyph
    
    # Simple glyph
    if hasattr(glyph, 'coordinates') and glyph.coordinates:
        # Scale coordinates
        scaled_coords = [(int(x * scale), int(y * scale)) for x, y in glyph.coordinates]
        glyph.coordinates = GlyphCoordinates(scaled_coords)
    
    # Recalculate bounds after scaling
    if hasattr(glyph, 'coordinates') and glyph.coordinates:
        glyph.recalcBounds(glyf_table)
    
    return glyph


def merge_fonts(hack_path, jp_path, output_path):
    """Merge Japanese glyphs from LINE Seed JP into Hack font."""
    print(f"Loading {hack_path}...")
    hack = TTFont(hack_path)

    print(f"Loading {jp_path}...")
    jp_font = TTFont(jp_path)

    # Get unitsPerEm
    hack_upm = hack['head'].unitsPerEm
    jp_upm = jp_font['head'].unitsPerEm
    scale = hack_upm / jp_upm
    print(f"Hack unitsPerEm: {hack_upm}, LINE Seed JP unitsPerEm: {jp_upm}, scale: {scale:.4f}")

    # Get Hack's standard character width (Latin characters are monospaced)
    hack_cmap = hack.getBestCmap()
    hack_standard_width = None
    for test_cp in [0x41, 0x4D, 0x61, 0x6D]:  # A, M, a, m
        if test_cp in hack_cmap:
            glyph_name = hack_cmap[test_cp]
            width, _ = hack['hmtx'].metrics[glyph_name]
            hack_standard_width = width
            break

    if hack_standard_width is None:
        print("Error: Could not determine Hack's standard character width")
        sys.exit(1)

    # Japanese characters should be 2x the width of Latin characters
    target_jp_width = hack_standard_width * 2
    print(f"Hack standard width: {hack_standard_width}, Target Japanese width: {target_jp_width}")
    
    # Get cmap tables
    hack_cmap = hack.getBestCmap()
    jp_cmap = jp_font.getBestCmap()
    
    # Get glyph tables
    hack_glyf = hack['glyf']
    jp_glyf = jp_font['glyf']
    
    # Get glyph order
    hack_glyph_order = list(hack.getGlyphOrder())
    
    # Find Japanese glyphs to copy
    glyphs_copied = 0
    for codepoint, jp_glyph_name in jp_cmap.items():
        if not is_japanese_codepoint(codepoint):
            continue
        
        # Skip if Hack already has this character
        if codepoint in hack_cmap:
            continue
        
        # Get glyph from LINE Seed JP
        if jp_glyph_name not in jp_glyf:
            continue
        
        jp_glyph = jp_glyf[jp_glyph_name]
        
        # Create new glyph name for Hack (avoid conflicts)
        new_glyph_name = f"uni{codepoint:04X}"
        if new_glyph_name in hack_glyph_order:
            new_glyph_name = f"jp_{codepoint:04X}"
        
        # Copy and scale the glyph
        try:
            new_glyph = copy.deepcopy(jp_glyph)
            new_glyph = scale_glyph(new_glyph, scale, hack_glyf)
            
            # Add to Hack's glyf table
            hack_glyf[new_glyph_name] = new_glyph
            
            # Add to glyph order
            hack_glyph_order.append(new_glyph_name)
            
            # Add to cmap
            hack_cmap[codepoint] = new_glyph_name
            
            # Set Japanese character width based on original width
            if jp_glyph_name in jp_font['hmtx'].metrics:
                jp_width, jp_lsb = jp_font['hmtx'].metrics[jp_glyph_name]

                # Scale the glyph's original metrics
                scaled_width = int(jp_width * scale)
                scaled_lsb = int(jp_lsb * scale)

                # Determine target width based on original width
                # LINE Seed JP uses 500 for halfwidth and 1000 for fullwidth
                # Halfwidth (≈500) → 1x Hack width (1233)
                # Fullwidth (≈1000) → 2x Hack width (2466)
                if jp_width <= 600:  # Halfwidth character
                    target_width = hack_standard_width
                else:  # Fullwidth character
                    target_width = target_jp_width

                # Calculate centered position
                width_diff = target_width - scaled_width
                centered_lsb = scaled_lsb + (width_diff // 2)

                hack['hmtx'].metrics[new_glyph_name] = (target_width, centered_lsb)
            
            glyphs_copied += 1
            
        except Exception as e:
            print(f"Warning: Failed to copy glyph U+{codepoint:04X} ({jp_glyph_name}): {e}")
            continue
    
    print(f"Copied {glyphs_copied} Japanese glyphs")
    
    # Update glyph order
    hack.setGlyphOrder(hack_glyph_order)
    
    # Update maxp table
    hack['maxp'].numGlyphs = len(hack_glyph_order)
    
    # Update font name
    if 'name' in hack:
        for record in hack['name'].names:
            if record.nameID in [1, 4, 6]:  # Family, Full, PostScript name
                try:
                    old_name = record.toUnicode()
                    new_name = old_name.replace("Hack", "HackLine")
                    record.string = new_name.encode(record.getEncoding())
                except:
                    pass
    
    # Save
    print(f"Saving to {output_path}...")
    hack.save(output_path)
    print(f"Saved {output_path}")
    
    hack.close()
    jp_font.close()


def main():
    """Main entry point."""
    print("=" * 60)
    print("HackLine Font Generator v3")
    print("=" * 60)
    
    # Check input files
    if not os.path.exists(HACK_REGULAR):
        print(f"Error: {HACK_REGULAR} not found")
        sys.exit(1)
    
    if not os.path.exists(LINE_SEED_JP_REGULAR):
        print(f"Error: {LINE_SEED_JP_REGULAR} not found")
        sys.exit(1)
    
    # Create build directory
    os.makedirs("build", exist_ok=True)
    
    # Merge Regular
    print("\n--- Generating Regular weight ---")
    merge_fonts(HACK_REGULAR, LINE_SEED_JP_REGULAR, OUTPUT_REGULAR)
    
    # Merge Bold (if available)
    if os.path.exists(HACK_BOLD) and os.path.exists(LINE_SEED_JP_BOLD):
        print("\n--- Generating Bold weight ---")
        merge_fonts(HACK_BOLD, LINE_SEED_JP_BOLD, OUTPUT_BOLD)
    
    print("\n" + "=" * 60)
    print("Done!")
    print("=" * 60)


if __name__ == "__main__":
    main()
