#!/usr/bin/env bash
# Собирает .deb из готовой сборки Linux.
#
# Архив с папкой файлов человеку ставить некуда: ни ярлыка в меню, ни
# значка, ни способа потом удалить. Пакет всё это приносит, а установка
# сводится к двойному щелчку.
#
#   tool/package_linux.sh 1.2.3 build/linux/x64/release/bundle dist
set -euo pipefail

version="${1:?версия}"
bundle="${2:?папка сборки}"
out="${3:-dist}"

root="$(cd "$(dirname "$0")/.." && pwd)"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

# Приложение целиком — в /opt: оно приносит с собой библиотеки Flutter и
# ресурсы, и раскладывать это по /usr значило бы мешать своё с системным.
install -d "$stage/opt/evaporate"
cp -a "$bundle/." "$stage/opt/evaporate/"

# Запуск из терминала и из скриптов — тем же именем, что и пакет.
install -d "$stage/usr/bin"
ln -s /opt/evaporate/evaporate "$stage/usr/bin/evaporate"

install -Dm644 "$root/linux/packaging/evaporate.desktop" \
  "$stage/usr/share/applications/evaporate.desktop"

# В pixmaps, а не в hicolor: тема hicolor раскладывается по точным размерам,
# а иконка у нас одна на 1024 точки — класть её в папку «512x512» значило бы
# соврать о содержимом. Каталог pixmaps размера не обещает и просматривается
# всеми оболочками.
install -Dm644 "$root/assets/branding/app_icon.png" \
  "$stage/usr/share/pixmaps/evaporate.png"

install -Dm644 "$root/LICENSE" \
  "$stage/usr/share/doc/evaporate/copyright"

size_kb=$(du -sk "$stage" | cut -f1)

# Зависимости перечислены руками, а не через dpkg-shlibdeps: тот требует
# дерева исходного пакета Debian, которого здесь нет. Список короткий и
# известен: gtk тянет за собой почти всё остальное, appindicator нужен
# значку в трее, xdg-utils — открытию ссылок.
install -d "$stage/DEBIAN"
cat > "$stage/DEBIAN/control" <<CONTROL
Package: evaporate
Version: $version
Section: games
Priority: optional
Architecture: amd64
Depends: libgtk-3-0, libayatana-appindicator3-1, xdg-utils
Installed-Size: $size_kb
Maintainer: Hecatoncheir <noreply@github.com>
Homepage: https://github.com/Hecatoncheir/evaporate
Description: Game launcher with BitTorrent and portable saves
 Evaporate keeps a library of games, downloads them over BitTorrent and
 carries saves between computers. There is no content catalogue: every
 source is set by the user.
CONTROL

mkdir -p "$out"
package="$out/evaporate-$version-linux-amd64.deb"
# Владельцем файлов делаем root: иначе пакет разложит их с правами того, кто
# собирал, и dpkg на это ругается.
dpkg-deb --root-owner-group --build "$stage" "$package"
echo "$package"
