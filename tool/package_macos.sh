#!/usr/bin/env bash
# Собирает .dmg из готового бандла macOS.
#
# Zip с бандлом внутри раскрывается куда попало — чаще всего в «Загрузки», и
# приложение так и остаётся там жить. В образе рядом с бандлом лежит ярлык
# «Программы», и установка сводится к перетаскиванию одного в другое: на
# macOS это и есть «Далее — Далее — Готово».
#
#   tool/package_macos.sh 1.2.3 build/macos/Build/Products/Release/Evaporate.app dist
set -euo pipefail

version="${1:?версия}"
app="${2:?путь до .app}"
out="${3:-dist}"

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

# ditto, а не cp: внутри бандла есть симлинки и права на запуск, и обычное
# копирование их теряет — подписанный ad-hoc бандл после этого не запустится.
ditto "$app" "$stage/$(basename "$app")"
ln -s /Applications "$stage/Applications"

mkdir -p "$out"
image="$out/evaporate-$version-macos.dmg"
rm -f "$image"

# UDZO — сжатый образ только для чтения: он меньше и его нельзя случайно
# изменить, а больше от установочного образа ничего и не нужно.
hdiutil create \
  -volname "Evaporate $version" \
  -srcfolder "$stage" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  "$image" >/dev/null
echo "$image"
