#!/usr/bin/env python3
"""Кладёт Ludusavi внутрь собранного .app и переподписывает его.

На macOS это отдельный шаг, а не правило сборки: вложенный исполняемый файл
ломает уже наложенную подпись, поэтому подписывать надо после копирования —
сначала сам файл, затем всё приложение. Неподписанный вложенный бинарник
Gatekeeper просто не запустит.

Использование:
    python3 tool/bundle_macos.py build/macos/Build/Products/Release/Evaporate.app
"""

import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, 'third_party', 'ludusavi', 'macos', 'ludusavi')
LEGAL = os.path.join(ROOT, 'third_party', 'ludusavi', 'legal')


def sign(target, identity):
    subprocess.check_call([
        'codesign', '--force', '--timestamp=none',
        '--options', 'runtime', '--sign', identity, target,
    ])


def main():
    if len(sys.argv) < 2:
        sys.exit('укажите путь к .app')
    app = sys.argv[1]
    # Своей учётной записи для подписи в сборке может не быть: тогда
    # подписываем «на месте», как это делает и сам Flutter.
    identity = os.environ.get('MACOS_SIGN_IDENTITY', '-')

    if not os.path.isdir(app):
        sys.exit('нет такого приложения: ' + app)
    if not os.path.exists(SOURCE):
        sys.exit('нет файла Ludusavi: сначала python3 tool/fetch_ludusavi.py')

    # Рядом с исполняемым файлом приложения — там его и ищет сам лончер.
    macos_dir = os.path.join(app, 'Contents', 'MacOS')
    target = os.path.join(macos_dir, 'ludusavi')
    shutil.copy2(SOURCE, target)
    os.chmod(target, 0o755)

    if os.path.isdir(LEGAL):
        legal_dir = os.path.join(app, 'Contents', 'Resources', 'ludusavi-legal')
        if os.path.isdir(legal_dir):
            shutil.rmtree(legal_dir)
        shutil.copytree(LEGAL, legal_dir)

    # Порядок важен: сначала вложенное, потом внешнее.
    sign(target, identity)
    sign(app, identity)
    print('Ludusavi вложен в ' + app)


if __name__ == '__main__':
    main()
