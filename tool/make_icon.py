#!/usr/bin/env python3
"""Собрать иконки приложения и трея из векторных исходников.

Каждый размер рисуется из SVG заново, а не уменьшением готового растра: у 16
и 32 точек это единственный способ остаться резкими. Рисует безголовый
браузер — он есть на всех трёх системах, в отличие от `sips`, который стоял
здесь раньше и привязывал упаковку к macOS.

Исходников два, и это не удобство, а необходимость. Крупные размеры берут
`evaporate-icon.svg` со свечением и искрами; мелкие — `evaporate-icon-small.svg`,
где ни того ни другого нет, а градиент короче и весь высветленный. Ореол
подсвечивает плашку и в 16 точек размывает контур буквы ровно на ту величину,
которой буква и нарисована.

    python3 tool/make_icon.py
    python3 tool/make_icon.py --browser /path/to/chrome

Браузер ищется сам; путь можно задать флагом или переменной окружения
`EVAPORATE_BROWSER`.
"""

import argparse
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
BRANDING = ROOT / 'docs/branding'
LARGE = BRANDING / 'evaporate-icon.svg'
SMALL = BRANDING / 'evaporate-icon-small.svg'

# Граница между исходниками. Ниже неё эффекты съедают букву, выше — держат.
SMALL_UP_TO = 32

CANDIDATES = (
    r'C:\Program Files\Google\Chrome\Application\chrome.exe',
    r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
    r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
    '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
)
ON_PATH = ('google-chrome', 'google-chrome-stable', 'chromium', 'chromium-browser', 'msedge')


def find_browser(explicit):
    """Ищем чем рисовать: флаг, переменная окружения, известные места, PATH."""
    for candidate in (explicit, os.environ.get('EVAPORATE_BROWSER')):
        if candidate:
            path = Path(candidate)
            if path.is_file():
                return path
            sys.exit(f'Браузер не найден: {candidate}')
    for candidate in CANDIDATES:
        if Path(candidate).is_file():
            return Path(candidate)
    for name in ON_PATH:
        found = shutil.which(name)
        if found:
            return Path(found)
    sys.exit(
        'Не нашёл браузер для отрисовки. Укажите его флагом --browser '
        'или переменной EVAPORATE_BROWSER.'
    )


def render(browser, source, target, size, profile):
    """Рисуем SVG в квадрат `size`.

    Окно всегда 1024, а нужный размер даёт масштаб вывода: браузер на
    некоторых размерах окна (проверено на 96, 128 и 160) возвращает пустой
    кадр с нулевым кодом возврата. Постоянное окно это обходит, а картинка при
    этом считается в 1024 точки и сжимается до нужной уже готовой — то есть
    со сглаживанием, а не потерей точек.

    У исходников намеренно нет width и height — только viewBox, поэтому
    рисунок растягивается в окно. Папка профиля своя на каждый заход: браузер
    держит на ней замок и отпускает не сразу.
    """
    target.parent.mkdir(parents=True, exist_ok=True)

    # Браузер изредка снимает кадр до отрисовки и отдаёт пустой PNG. Ловится
    # это только по размеру файла: код возврата у него при этом нулевой.
    for attempt in range(1, 4):
        subprocess.run(
            [
                str(browser), '--headless=new', '--disable-gpu', '--hide-scrollbars',
                f'--user-data-dir={profile}/{size}-{attempt}',
                f'--force-device-scale-factor={size / 1024}',
                '--default-background-color=00000000',
                '--window-size=1024,1024',
                '--virtual-time-budget=5000',
                f'--screenshot={target}',
                source.as_uri(),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if target.is_file() and target.stat().st_size >= 24 * size:
            return
    sys.exit(f'Пустой результат отрисовки: {size} точек из {source.name}')


def write_ico(png_by_size, target):
    """Контейнер ICO с PNG внутри, такие Windows понимает начиная с Vista."""
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
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(header + entries + payload)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--browser', help='чем рисовать SVG')
    parser.add_argument('--large', type=Path, default=LARGE)
    parser.add_argument('--small', type=Path, default=SMALL)
    args = parser.parse_args()

    for source in (args.large, args.small):
        if not source.is_file():
            parser.error(f'Исходник не найден: {source}')
    browser = find_browser(args.browser)

    mac = ROOT / 'macos/Runner/Assets.xcassets/AppIcon.appiconset'
    branding = ROOT / 'assets/branding'
    sizes = (16, 24, 32, 48, 64, 128, 256, 512, 1024)

    with tempfile.TemporaryDirectory(prefix='evaporate-icons-') as temporary:
        profile = Path(temporary) / 'profile'
        rendered = {}
        for size in sizes:
            source = args.small if size <= SMALL_UP_TO else args.large
            target = Path(temporary) / f'{size}.png'
            render(browser, source.resolve(), target, size, profile)
            rendered[size] = target

        shutil.copyfile(rendered[1024], branding / 'app_icon.png')
        shutil.copyfile(rendered[32], branding / 'tray_icon.png')
        for size in (16, 32, 64, 128, 256, 512, 1024):
            shutil.copyfile(rendered[size], mac / f'app_icon_{size}.png')
        write_ico(
            {size: rendered[size].read_bytes() for size in (16, 32, 48, 64, 128, 256)},
            ROOT / 'windows/runner/resources/app_icon.ico',
        )
        write_ico(
            {size: rendered[size].read_bytes() for size in (16, 24, 32, 48)},
            branding / 'tray_icon.ico',
        )

    print(f'Иконки собраны из {args.large.name} и {args.small.name} ({browser.name})')


if __name__ == '__main__':
    main()
