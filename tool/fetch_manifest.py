#!/usr/bin/env python3
"""Кладёт настоящий манифест Ludusavi рядом с бинарником — для замеров.

В репозиторий он не входит: это чужие данные объёмом в десятки мегабайт,
которые приложение и так скачивает само. Нужен он ровно затем, чтобы
измерить цену разбора на настоящем объёме, а не на синтетическом примере.

    python3 tool/fetch_manifest.py
    fvm flutter test test/ludusavi_manifest_bench_test.dart
"""

import os
import sys
import urllib.request

URL = (
    'https://raw.githubusercontent.com/mtkennerly/ludusavi-manifest/'
    'master/data/manifest.yaml'
)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(ROOT, 'third_party', 'ludusavi', 'manifest.yaml')


def main():
    os.makedirs(os.path.dirname(TARGET), exist_ok=True)
    sys.stderr.write('качаю %s\n' % URL)
    with urllib.request.urlopen(URL, timeout=180) as response:
        data = response.read()
    with open(TARGET, 'wb') as out:
        out.write(data)
    sys.stderr.write(
        'готово: %s (%.1f МБ)\n' % (TARGET, len(data) / (1024 * 1024))
    )


if __name__ == '__main__':
    main()
