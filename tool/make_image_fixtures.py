#!/usr/bin/env python3
"""Regenerates test/fixtures/images/ (macOS: uses `sips` for JPEG/HEIC).

Images are 40x30 (landscape as stored) with a left-to-right gradient, so
orientation and size handling can be checked. EXIF blocks are written by
hand because no EXIF tool is assumed to be installed.
"""
import os
import struct
import subprocess
import sys
import tempfile
import zlib

OUT = os.path.join(os.path.dirname(__file__), '..', 'test', 'fixtures', 'images')
W, H = 40, 30


def png_bytes(w, h):
    rows = b''.join(
        b'\x00' + bytes(v for x in range(w) for v in (x * 6, 80, 255 - x * 6))
        for _ in range(h))
    def chunk(kind, data):
        return (struct.pack('>I', len(data)) + kind + data +
                struct.pack('>I', zlib.crc32(kind + data) & 0xFFFFFFFF))
    return (b'\x89PNG\r\n\x1a\n' +
            chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) +
            chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b''))


def exif_app1(orientation, date=None, offset=None):
    """APP1 segment with IFD0 Orientation and an Exif IFD with dates."""
    exif_entries = []
    if date:
        exif_entries.append((0x9003, 2, (date + '\x00').encode()))
    if offset:
        exif_entries.append((0x9011, 2, (offset + '\x00').encode()))
    ifd0_count = 1 + (1 if exif_entries else 0)
    ifd0_size = 2 + 12 * ifd0_count + 4
    exif_ifd_off = 8 + ifd0_size
    exif_ifd_size = 2 + 12 * len(exif_entries) + 4 if exif_entries else 0
    data_off = exif_ifd_off + exif_ifd_size

    ifd0 = struct.pack('>H', ifd0_count)
    ifd0 += struct.pack('>HHIHH', 0x0112, 3, 1, orientation, 0)
    if exif_entries:
        ifd0 += struct.pack('>HHII', 0x8769, 4, 1, exif_ifd_off)
    ifd0 += struct.pack('>I', 0)

    exif_ifd, blob = b'', b''
    if exif_entries:
        exif_ifd = struct.pack('>H', len(exif_entries))
        for tag, typ, value in exif_entries:
            if len(value) <= 4:
                exif_ifd += struct.pack('>HHI', tag, typ, len(value)) + value.ljust(4, b'\x00')
            else:
                exif_ifd += struct.pack('>HHII', tag, typ, len(value), data_off + len(blob))
                blob += value
        exif_ifd += struct.pack('>I', 0)

    tiff = b'MM\x00\x2a' + struct.pack('>I', 8) + ifd0 + exif_ifd + blob
    payload = b'Exif\x00\x00' + tiff
    return b'\xff\xe1' + struct.pack('>H', len(payload) + 2) + payload


def with_exif(jpeg, app1):
    assert jpeg[:2] == b'\xff\xd8'
    return jpeg[:2] + app1 + jpeg[2:]


def sips(src, fmt, dst):
    subprocess.run(['sips', '-s', 'format', fmt, src, '--out', dst],
                   check=True, capture_output=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(tmp, 'src.png')
        with open(src, 'wb') as f:
            f.write(png_bytes(W, H))
        jpg = os.path.join(tmp, 'base.jpg')
        sips(src, 'jpeg', jpg)
        sips(src, 'heic', os.path.join(OUT, 'landscape.heic'))
        with open(jpg, 'rb') as f:
            base = f.read()

    fixtures = {
        'plain.png': png_bytes(W, H),
        'no_exif.jpg': base,
        'orientation_1_offset.jpg': with_exif(
            base, exif_app1(1, '2026:11:14 09:30:00', '+02:00')),
        'orientation_6.jpg': with_exif(base, exif_app1(6, '2026:03:05 14:00:00')),
        'orientation_8.jpg': with_exif(base, exif_app1(8)),
        'not_an_image.txt': b'just some text, not a picture\n',
    }
    for name, data in fixtures.items():
        with open(os.path.join(OUT, name), 'wb') as f:
            f.write(data)
    print('wrote', ', '.join(sorted(os.listdir(OUT))))


if __name__ == '__main__':
    sys.exit(main())
