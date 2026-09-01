#!/usr/bin/env python3
"""Кладёт Ludusavi в third_party, откуда его забирает сборка.

Бинарник в репозиторий не коммитится: он скачивается по закреплённой версии
и проверяется по контрольной сумме. Без проверки исполняемый файл в сборку
попадать не должен — совпадение суммы и есть единственное подтверждение,
что скачалось именно то, что мы закрепили.

Использование:
    python3 tool/fetch_ludusavi.py                # под текущую систему
    python3 tool/fetch_ludusavi.py --platform linux
    python3 tool/fetch_ludusavi.py --print-checksums  # посчитать суммы заново
"""

import argparse
import hashlib
import io
import json
import os
import shutil
import sys
import tarfile
import urllib.request
import zipfile

VERSION = 'v0.31.0'
BASE = 'https://github.com/mtkennerly/ludusavi/releases/download/' + VERSION

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, 'third_party', 'ludusavi')
CHECKSUMS = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         'ludusavi_checksums.json')

# Имя архива и имя исполняемого файла внутри него.
ASSETS = {
    'linux': ('ludusavi-%s-linux.tar.gz' % VERSION, 'ludusavi'),
    'macos': ('ludusavi-%s-mac.tar.gz' % VERSION, 'ludusavi'),
    'windows': ('ludusavi-%s-win64.zip' % VERSION, 'ludusavi.exe'),
}
LEGAL = 'ludusavi-%s-legal.zip' % VERSION


def current_platform():
    if sys.platform.startswith('linux'):
        return 'linux'
    if sys.platform == 'darwin':
        return 'macos'
    if sys.platform in ('win32', 'cygwin'):
        return 'windows'
    sys.exit('неизвестная система: ' + sys.platform)


def download(asset):
    url = '%s/%s' % (BASE, asset)
    sys.stderr.write('качаю %s\n' % url)
    with urllib.request.urlopen(url, timeout=120) as response:
        return response.read()


def verify(asset, blob, expected):
    digest = hashlib.sha256(blob).hexdigest()
    if expected is None:
        sys.exit(
            'нет закреплённой суммы для %s.\n'
            'Посчитать заново: python3 tool/fetch_ludusavi.py '
            '--print-checksums' % asset
        )
    if digest != expected:
        sys.exit(
            'сумма не совпала для %s\n  ожидалась: %s\n  получена:  %s'
            % (asset, expected, digest)
        )
    return digest


def extract_member(blob, asset, wanted, target_dir, executable):
    """Достаёт один файл из архива, не разворачивая всё подряд."""
    os.makedirs(target_dir, exist_ok=True)
    target = os.path.join(target_dir, os.path.basename(wanted))

    if asset.endswith('.zip'):
        with zipfile.ZipFile(io.BytesIO(blob)) as archive:
            name = _find(archive.namelist(), wanted, asset)
            data = archive.read(name)
    else:
        with tarfile.open(fileobj=io.BytesIO(blob), mode='r:gz') as archive:
            name = _find(archive.getnames(), wanted, asset)
            handle = archive.extractfile(name)
            if handle is None:
                sys.exit('в архиве %s нет файла %s' % (asset, wanted))
            data = handle.read()

    with open(target, 'wb') as out:
        out.write(data)
    if executable:
        os.chmod(target, 0o755)
    return target


def _find(names, wanted, asset):
    for name in names:
        if os.path.basename(name) == wanted:
            return name
    sys.exit('в архиве %s нет файла %s' % (asset, wanted))


def extract_all(blob, target_dir):
    """Тексты лицензий кладём целиком: MIT обязывает их приложить."""
    if os.path.isdir(target_dir):
        shutil.rmtree(target_dir)
    os.makedirs(target_dir, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(blob)) as archive:
        for member in archive.namelist():
            if member.endswith('/'):
                continue
            # Путь из архива не должен уводить за пределы папки.
            name = os.path.basename(member)
            if not name:
                continue
            with open(os.path.join(target_dir, name), 'wb') as out:
                out.write(archive.read(member))


def load_checksums():
    if not os.path.exists(CHECKSUMS):
        return {}
    with open(CHECKSUMS, encoding='utf-8') as handle:
        return json.load(handle).get('sha256', {})


def print_checksums():
    sums = {}
    for asset, _ in list(ASSETS.values()) + [(LEGAL, None)]:
        sums[asset] = hashlib.sha256(download(asset)).hexdigest()
    print(json.dumps({'version': VERSION, 'sha256': sums},
                     indent=2, ensure_ascii=False))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--platform', choices=sorted(ASSETS))
    parser.add_argument('--print-checksums', action='store_true')
    args = parser.parse_args()

    if args.print_checksums:
        print_checksums()
        return

    platform = args.platform or current_platform()
    asset, exe = ASSETS[platform]
    expected = load_checksums()
    # Проверяем до загрузки: качать десятки мегабайт, чтобы затем отказаться
    # из-за незакреплённой суммы, незачем.
    for name in (asset, LEGAL):
        if expected.get(name) is None:
            sys.exit(
                'нет закреплённой суммы для %s.\n'
                'Посчитать заново: python3 tool/fetch_ludusavi.py '
                '--print-checksums' % name
            )

    blob = download(asset)
    verify(asset, blob, expected.get(asset))
    target = extract_member(blob, asset, exe, os.path.join(DEST, platform),
                            executable=platform != 'windows')
    sys.stderr.write('готово: %s\n' % target)

    legal = download(LEGAL)
    verify(LEGAL, legal, expected.get(LEGAL))
    extract_all(legal, os.path.join(DEST, 'legal'))
    sys.stderr.write('лицензии: %s\n' % os.path.join(DEST, 'legal'))


if __name__ == '__main__':
    main()
