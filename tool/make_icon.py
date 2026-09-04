#!/usr/bin/env python3
"""Package generated artwork into PNG/ICO resources on macOS.

Only resizes the saved source with sips and packages PNGs in ICO containers.
No redrawing, image-generation API, or Pillow required.
Usage: python3 tool/make_icon.py [--source path/to/icon.png]
"""

import argparse
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'docs/branding/evaporate-icon-v2.png'


def resize(source, target, size):
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ['sips', '-s', 'format', 'png', '-z', str(size), str(size),
         str(source), '--out', str(target)],
        check=True, stdout=subprocess.DEVNULL,
    )


def write_ico(png_by_size, target):
    """ICO container with PNG payloads, supported since Windows Vista."""
    sizes = sorted(png_by_size)
    header = struct.pack('<HHH', 0, 1, len(sizes))
    entries = bytearray()
    payload = bytearray()
    offset = 6 + 16 * len(sizes)
    for size in sizes:
        blob = png_by_size[size]
        entries += struct.pack(
            '<BBBBHHII', 0 if size >= 256 else size,
            0 if size >= 256 else size, 0, 0, 1, 32, len(blob),
            offset + len(payload),
        )
        payload += blob
    target.write_bytes(header + entries + payload)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=SOURCE)
    source = parser.parse_args().source.resolve()
    if not source.is_file():
        parser.error(f'Icon source not found: {source}')
    if shutil.which('sips') is None:
        parser.error('Run on macOS (sips is required).')

    branding = ROOT / 'assets/branding'
    mac = ROOT / 'macos/Runner/Assets.xcassets/AppIcon.appiconset'
    sizes = (16, 24, 32, 48, 64, 128, 256, 512, 1024)
    with tempfile.TemporaryDirectory(prefix='evaporate-icons-') as temporary:
        generated = {}
        for size in sizes:
            target = Path(temporary) / f'{size}.png'
            resize(source, target, size)
            generated[size] = target

        branding.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(generated[1024], branding / 'app_icon.png')
        shutil.copyfile(generated[32], branding / 'tray_icon.png')
        for size in (16, 32, 64, 128, 256, 512, 1024):
            shutil.copyfile(generated[size], mac / f'app_icon_{size}.png')
        write_ico(
            {size: generated[size].read_bytes() for size in (16, 32, 48, 64, 128, 256)},
            ROOT / 'windows/runner/resources/app_icon.ico',
        )
        write_ico(
            {size: generated[size].read_bytes() for size in (16, 24, 32, 48)},
            branding / 'tray_icon.ico',
        )
    print(f'Packaged application and tray icons from {source}')


if __name__ == '__main__':
    main()
