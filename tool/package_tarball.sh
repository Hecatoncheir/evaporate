#!/usr/bin/env bash
# Собирает архив Linux — тот, что ставят руками и которым приложение
# обновляется по нажатию.
#
# Внутри одна папка `evaporate/`, а не россыпь файлов. Россыпью архив
# распаковывали прямо в «Загрузки», папкой приложения становились сами
# «Загрузки», и обновление, заменяющее папку приложения целиком, уносило их
# со всем содержимым. В папке лежит маркер `.evaporate-install`: по нему
# приложение и помощник обновления узнают папку, которую положила сборка
# (`InstallLayout.marker`). Без маркера обновлять себя приложение не станет.
#
#   tool/package_tarball.sh 1.2.3 build/linux/x64/release/bundle dist
set -euo pipefail

version="${1:?версия}"
bundle="${2:?папка сборки}"
out="${3:-dist}"

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

cp -a "$bundle" "$stage/evaporate"
printf 'Эту папку положила сборка Evaporate: обновление заменяет её целиком.\n' \
  > "$stage/evaporate/.evaporate-install"

mkdir -p "$out"
package="$out/evaporate-$version-linux-x64.tar.gz"
tar -czf "$package" -C "$stage" evaporate
echo "$package"
