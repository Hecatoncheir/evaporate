#!/usr/bin/env python3
"""Рисует иконку приложения и раскладывает её по платформам.

Готовых графических инструментов на машине разработки нет — ни PIL, ни
конвертера SVG, — поэтому PNG собирается байтами вручную. Для геометричной
иконки этого достаточно, а заодно она перерисовывается одной командой и не
лежит в репозитории двоичным файлом непонятного происхождения.

Рисунок: скруглённый квадрат с диагональным градиентом фирменных цветов,
на нём тёмный треугольник «запуск», от вершины которого вверх уходят три
капли — испарение. Сюжет читается на крупных размерах, а на 16 пикселях
остаётся узнаваемый силуэт треугольника.

Использование:
    python3 tool/make_icon.py
"""

import io
import math
import os
import struct
import subprocess
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MASTER = 1024
SUPERSAMPLE = 3

# Поле вокруг рисунка для macOS: там иконки не доходят до края холста.
MAC_INSET = 0.09

# Палитра приложения (lib/ui/theme.dart).
BACKGROUND = (0x0D, 0x11, 0x17)
PRIMARY = (0x4F, 0xC3, 0xF7)
ACCENT = (0x7D, 0xD3, 0xC0)


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    return tuple(lerp(c1[i], c2[i], t) for i in range(3))


def rounded_rect(x, y, size, radius):
    """Знаковое расстояние до скруглённого квадрата: <0 внутри."""
    half = size / 2.0
    dx = abs(x - half) - (half - radius)
    dy = abs(y - half) - (half - radius)
    if dx <= 0 and dy <= 0:
        return max(dx, dy)
    dx = max(dx, 0.0)
    dy = max(dy, 0.0)
    return math.hypot(dx, dy) - radius


def inside_triangle(x, y, pts):
    def side(ax, ay, bx, by):
        return (bx - ax) * (y - ay) - (by - ay) * (x - ax)

    d1 = side(pts[0][0], pts[0][1], pts[1][0], pts[1][1])
    d2 = side(pts[1][0], pts[1][1], pts[2][0], pts[2][1])
    d3 = side(pts[2][0], pts[2][1], pts[0][0], pts[0][1])
    has_neg = d1 < 0 or d2 < 0 or d3 < 0
    has_pos = d1 > 0 or d2 > 0 or d3 > 0
    return not (has_neg and has_pos)


def bubble(x, y, cx, cy, r):
    """Просто круг.

    Хитрая «каплевидная» форма на 16 пикселях превращается в зазубренное
    пятно, а круг читается на любом размере.
    """
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def sample(x, y, size, inset=0.0):
    """Цвет и прозрачность в точке. Координаты — в пикселях итогового размера.

    [inset] — доля холста, оставляемая пустой с каждой стороны. На macOS
    иконка обязана иметь поля, иначе в доке она выглядит крупнее соседних.
    """
    pad = size * inset
    s = size - 2 * pad
    if s <= 0:
        return None
    x -= pad
    y -= pad
    if x < 0 or y < 0 or x > s or y > s:
        return None
    if rounded_rect(x, y, s, s * 0.225) > 0:
        return None

    # Фон: диагональный градиент.
    t = max(0.0, min(1.0, (x + y) / (2.0 * s)))
    color = mix(PRIMARY, ACCENT, t)

    # Треугольник «запуск» — смещён влево-вниз, освобождая место каплям.
    tri = [
        (s * 0.285, s * 0.335),
        (s * 0.285, s * 0.775),
        (s * 0.655, s * 0.555),
    ]
    if inside_triangle(x, y, tri):
        return BACKGROUND

    # След пара от вершины треугольника: чем выше, тем мельче — так читается
    # рассеивание, а не просто три точки.
    drops = [
        (s * 0.700, s * 0.395, s * 0.072),
        (s * 0.787, s * 0.263, s * 0.048),
        (s * 0.851, s * 0.156, s * 0.029),
    ]
    for cx, cy, r in drops:
        if bubble(x, y, cx, cy, r):
            return BACKGROUND

    return color


def render(size, inset=0.0):
    """Рисует с передискретизацией — иначе края будут рваными."""
    scale = SUPERSAMPLE
    rows = []
    for py in range(size):
        row = bytearray()
        for px in range(size):
            r = g = b = a = 0.0
            for sy in range(scale):
                for sx in range(scale):
                    x = (px * scale + sx + 0.5) / scale
                    y = (py * scale + sy + 0.5) / scale
                    got = sample(x, y, size, inset)
                    if got is not None:
                        r += got[0]
                        g += got[1]
                        b += got[2]
                        a += 255.0
            n = scale * scale
            if a > 0:
                # Цвет усредняем по закрытым выборкам, иначе края темнеют.
                covered = a / 255.0
                row += bytes(
                    (
                        int(r / covered + 0.5),
                        int(g / covered + 0.5),
                        int(b / covered + 0.5),
                        int(a / n + 0.5),
                    )
                )
            else:
                row += b'\x00\x00\x00\x00'
        rows.append(bytes(row))
    return rows


def write_png(rows, width, path):
    raw = bytearray()
    for row in rows:
        raw.append(0)  # тип фильтра строки: без предсказания
        raw += row

    def chunk(tag, data):
        out = struct.pack('>I', len(data)) + tag + data
        return out + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)

    header = struct.pack('>IIBBBBB', width, len(rows), 8, 6, 0, 0, 0)
    blob = (
        b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', header)
        + chunk(b'IDAT', zlib.compress(bytes(raw), 9))
        + chunk(b'IEND', b'')
    )
    with open(path, 'wb') as out:
        out.write(blob)
    return blob


def write_ico(png_by_size, path):
    """ICO — контейнер: начиная с Vista внутрь кладут готовые PNG."""
    sizes = sorted(png_by_size)
    header = struct.pack('<HHH', 0, 1, len(sizes))
    entries = bytearray()
    payload = bytearray()
    offset = 6 + 16 * len(sizes)
    for size in sizes:
        blob = png_by_size[size]
        entries += struct.pack(
            '<BBBBHHII',
            0 if size >= 256 else size,
            0 if size >= 256 else size,
            0,
            0,
            1,
            32,
            len(blob),
            offset + len(payload),
        )
        payload += blob
    with open(path, 'wb') as out:
        out.write(header + bytes(entries) + bytes(payload))


def main():
    out_dir = os.path.join(ROOT, 'assets', 'branding')
    os.makedirs(out_dir, exist_ok=True)

    sys.stderr.write('рисую %dx%d\n' % (MASTER, MASTER))
    master_path = os.path.join(out_dir, 'app_icon.png')
    write_png(render(MASTER), MASTER, master_path)

    # macOS: набор размеров из Contents.json.
    mac_dir = os.path.join(ROOT, 'macos', 'Runner', 'Assets.xcassets',
                           'AppIcon.appiconset')
    if os.path.isdir(mac_dir):
        sys.stderr.write('рисую вариант для macOS, с полями\n')
        mac_master = os.path.join(out_dir, '_mac_master.png')
        write_png(render(MASTER, MAC_INSET), MASTER, mac_master)
        for size in (16, 32, 64, 128, 256, 512, 1024):
            target = os.path.join(mac_dir, 'app_icon_%d.png' % size)
            if size == MASTER:
                with open(mac_master, 'rb') as src, open(target, 'wb') as dst:
                    dst.write(src.read())
                continue
            subprocess.check_call(
                ['sips', '-z', str(size), str(size), mac_master,
                 '--out', target],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
        os.remove(mac_master)
        sys.stderr.write('macOS: %s\n' % mac_dir)

    # Windows: один .ico с несколькими размерами внутри.
    win_icon = os.path.join(ROOT, 'windows', 'runner', 'resources',
                            'app_icon.ico')
    if os.path.isdir(os.path.dirname(win_icon)):
        blobs = {}
        for size in (16, 32, 48, 64, 128, 256):
            sys.stderr.write('  ico %d\n' % size)
            blobs[size] = write_png(
                render(size), size,
                os.path.join(out_dir, '_ico_%d.png' % size),
            )
        write_ico(blobs, win_icon)
        for size in blobs:
            os.remove(os.path.join(out_dir, '_ico_%d.png' % size))
        sys.stderr.write('Windows: %s\n' % win_icon)

    # Linux: иконку ставит окно, файл кладём рядом с остальными ресурсами.
    sys.stderr.write('мастер-файл: %s\n' % master_path)


if __name__ == '__main__':
    main()
