#!/usr/bin/env python3
"""Package a SillyTavern character library into a single zip for NativeTavern.

Reads cards from <data-dir>/characters (*.png, *.charx) and tag assignments
from <data-dir>/settings.json, and produces a zip containing:

    manifest.json          - version, tags, per-card sha256 + tag ids
    cards/<card file>      - the original card files, unmodified

Only the Python standard library is used.
"""

import argparse
import hashlib
import json
import struct
import sys
import zipfile
from pathlib import Path

MANIFEST_VERSION = 1
CARD_EXTENSIONS = {".png", ".charx"}
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def parse_args(argv):
    parser = argparse.ArgumentParser(
        description="Package a SillyTavern library (cards + tags) into one zip."
    )
    parser.add_argument(
        "--data-dir",
        default="data/default-user",
        help="SillyTavern user data dir containing characters/ and settings.json "
        "(default: %(default)s)",
    )
    parser.add_argument(
        "--out",
        default="st_library.zip",
        help="Output zip path (default: %(default)s)",
    )
    return parser.parse_args(argv)


def load_settings(data_dir):
    """Return (tags, tag_map) from settings.json; empty on any problem."""
    settings_path = Path("/Volumes/Backup/ST/data/default-user/settings.json")
    if not settings_path.is_file():
        print(f"warning: {settings_path} not found; exporting without tags")
        return [], {}
    try:
        with open(settings_path, encoding="utf-8") as f:
            settings = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f"warning: could not read {settings_path} ({e}); exporting without tags")
        return [], {}

    tags = settings.get("tags") or []
    tag_map = settings.get("tag_map") or {}
    if not isinstance(tags, list) or not isinstance(tag_map, dict):
        print("warning: unexpected tags/tag_map shape in settings.json; ignoring tags")
        return [], {}
    return tags, tag_map


def png_has_card_chunk(data):
    """True if the PNG contains a 'chara' or 'ccv3' tEXt chunk."""
    if not data.startswith(PNG_SIGNATURE):
        return False
    offset = len(PNG_SIGNATURE)
    while offset + 8 <= len(data):
        (length,) = struct.unpack(">I", data[offset : offset + 4])
        chunk_type = data[offset + 4 : offset + 8]
        if chunk_type == b"tEXt":
            keyword = data[offset + 8 : offset + 8 + length].split(b"\x00", 1)[0]
            if keyword in (b"chara", b"ccv3"):
                return True
        if chunk_type == b"IEND":
            break
        offset += 12 + length  # length + type + data + crc
    return False


def main(argv=None):
    args = parse_args(argv)
    data_dir = Path(args.data_dir)
    characters_dir = Path("/Volumes/Backup/ST/data/default-user/characters")
    out_path = Path(args.out)

    if not characters_dir.is_dir():
        print(f"error: {characters_dir} is not a directory", file=sys.stderr)
        return 1

    raw_tags, tag_map = load_settings(data_dir)

    # Keep only well-formed tags; ST tag ids may be strings or numbers.
    tags = []
    known_tag_ids = set()
    for tag in raw_tags:
        if isinstance(tag, dict) and "id" in tag and "name" in tag:
            tag_id = str(tag["id"])
            known_tag_ids.add(tag_id)
            tags.append(
                {"id": tag_id, "name": str(tag["name"]), "color": tag.get("color") or ""}
            )

    card_files = sorted(
        (p for p in characters_dir.iterdir()
         if p.is_file() and p.suffix.lower() in CARD_EXTENSIONS),
        key=lambda p: p.name,
    )

    cards = []
    skipped_unreadable = 0
    orphan_tag_refs = 0
    cards_with_tags = 0
    pngs_without_card_data = []

    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for path in card_files:
            try:
                data = path.read_bytes()
            except OSError as e:
                print(f"warning: skipping unreadable file {path.name} ({e})")
                skipped_unreadable += 1
                continue

            if path.suffix.lower() == ".png" and not png_has_card_chunk(data):
                pngs_without_card_data.append(path.name)

            # tag_map keys are avatar filenames, matched exactly.
            raw_ids = tag_map.get(path.name) or []
            tag_ids = []
            if isinstance(raw_ids, list):
                for tag_id in raw_ids:
                    tag_id = str(tag_id)
                    if tag_id in known_tag_ids:
                        tag_ids.append(tag_id)
                    else:
                        orphan_tag_refs += 1
            if tag_ids:
                cards_with_tags += 1

            cards.append(
                {
                    "file": path.name,
                    "sha256": hashlib.sha256(data).hexdigest(),
                    "tag_ids": tag_ids,
                }
            )
            zf.writestr(f"cards/{path.name}", data)

        manifest = {"version": MANIFEST_VERSION, "tags": tags, "cards": cards}
        zf.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False, indent=2))

    packaged_names = {c["file"] for c in cards}
    unmatched_tag_map_keys = sum(1 for key in tag_map if key not in packaged_names)

    print(f"wrote {out_path}")
    print(f"  cards packaged:          {len(cards)}")
    print(f"  tags exported:           {len(tags)}")
    print(f"  cards with >=1 tag:      {cards_with_tags}")
    print(f"  orphan tag refs dropped: {orphan_tag_refs}")
    print(f"  unmatched tag_map keys:  {unmatched_tag_map_keys}")
    print(f"  unreadable files skipped:{skipped_unreadable}")
    if pngs_without_card_data:
        print(f"  PNGs without embedded card data ({len(pngs_without_card_data)}):")
        for name in pngs_without_card_data:
            print(f"    {name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
