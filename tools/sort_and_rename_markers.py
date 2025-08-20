#!/usr/bin/env python3
"""
Script to sort Marker2D nodes in a Godot .tscn file by their X position
and rename each node sequentially with the prefix "Note".
"""

import re
import argparse
import shutil
import sys

def parse_blocks(lines):
    """
    Identify all Marker2D node blocks. Return list of dicts:
    { 'start': int, 'end': int, 'lines': [str], 'x': float }
    """
    header_idxs = [i for i, line in enumerate(lines) if line.startswith("[node name=")]
    blocks = []
    for idx, start in enumerate(header_idxs):
        header = lines[start]
        if 'type="Marker2D"' not in header:
            continue
        end = header_idxs[idx + 1] if idx + 1 < len(header_idxs) else len(lines)
        block_lines = lines[start:end]
        # find X position
        x_pos = None
        for l in block_lines:
            m = re.match(r'\s*position\s*=\s*Vector2\(\s*([0-9\.\-]+)\s*,', l)
            if m:
                x_pos = float(m.group(1))
                break
        if x_pos is None:
            # if no position found, treat as infinity so they go last
            x_pos = float('inf')
        blocks.append({
            'start': start,
            'end': end,
            'lines': block_lines,
            'x': x_pos
        })
    return blocks

def rebuild_scene(lines, blocks):
    """
    Remove original marker blocks, then re-insert sorted and renamed blocks.
    """
    if not blocks:
        return lines

    # Determine preamble and postamble
    first = blocks[0]
    last = blocks[-1]
    preamble = lines[: first['start']]
    postamble = lines[last['end']:]

    # Sort by x
    sorted_blocks = sorted(blocks, key=lambda b: b['x'])

    # Rename and collect lines
    new_blocks_lines = []
    for idx, blk in enumerate(sorted_blocks, start=1):
        new_name = f'Note{idx}'
        header = blk['lines'][0]
        # replace name="..." only
        new_header = re.sub(r'name="[^"]+"', f'name="{new_name}"', header)
        new_blocks_lines.append(new_header)
        new_blocks_lines.extend(blk['lines'][1:])

    return preamble + new_blocks_lines + postamble

def main():
    parser = argparse.ArgumentParser(
        description="Sort Marker2D node blocks in a .tscn by X position and rename them sequentially."
    )
    parser.add_argument("scene_file", help="Path to the .tscn file to process")
    args = parser.parse_args()

    scene_path = args.scene_file

    # backup original
    backup_path = scene_path + ".bak"
    try:
        shutil.copy(scene_path, backup_path)
        print(f"Backup created at {backup_path}")
    except Exception as e:
        print(f"Warning: could not create backup ({e})", file=sys.stderr)

    # read file
    with open(scene_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # parse and rebuild
    blocks = parse_blocks(lines)
    new_lines = rebuild_scene(lines, blocks)

    # write out
    with open(scene_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

    print(f"Rewrote {scene_path} with {len(blocks)} markers sorted and renamed.")

if __name__ == "__main__":
    main()
