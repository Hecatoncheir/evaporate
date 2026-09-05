#!/usr/bin/env bash
# Собирает самораспаковывающийся установщик .run из готовой сборки Linux.
#
# Пакет .deb годится Debian и Ubuntu, а ложится он в /opt — туда без прав
# администратора не записать, и обновляться такое должно тем же способом,
# каким ставили. Для остальных систем оставался только архив, который
# распаковывают руками и который так и остаётся жить в «Загрузках».
#
# Этот файл ставит приложение в папку пользователя: прав администратора не
# просит, запись в меню делает сам, а обновление по нажатию потом работает —
# в свою папку приложение записать может.
#
# Самораспаковка — это заголовок-скрипт и приклеенный следом tar.gz.
# Отдельный упаковщик (makeself) ради тридцати строк в сборку не тянем.
#
#   tool/package_run.sh 1.2.3 build/linux/x64/release/bundle dist
set -euo pipefail

version="${1:?версия}"
bundle="${2:?папка сборки}"
out="${3:-dist}"

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Комментарии из заготовки выбрасываем: они писались для нас, а не для
# системы. Пути подставляет уже сам установщик — до установки он их не знает.
sed -e '/^#/d' "$root/linux/packaging/evaporate.desktop.in" > "$work/desktop"

{
  cat <<HEAD
#!/bin/sh
# Установщик Evaporate $version. Файл самораспаковывающийся: сначала этот
# скрипт, следом приклеен tar.gz со сборкой.
set -eu

version='$version'
HEAD

  cat <<'HEAD'
name="$(basename "$0")"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
target="$data/evaporate"
apps="$data/applications"
bin="$HOME/.local/bin"
mode=install
extract_to=

usage() {
  cat <<USAGE
Evaporate $version

  ./$name                  поставить в $target
  ./$name --prefix DIR     поставить в другую папку
  ./$name --extract DIR    только распаковать, ничего больше не трогая
  ./$name --help           это сообщение

Ставится в папку пользователя: прав администратора не нужно, и приложение
сможет обновляться само. Удалить — evaporate-uninstall.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --prefix) target="${2:?--prefix ждёт папку}"; shift 2 ;;
    --extract) mode=extract; extract_to="${2:?--extract ждёт папку}"; shift 2 ;;
    *) echo "Непонятный ключ: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# Полезная нагрузка начинается со следующей строки после метки. awk до
# двоичной части не доходит: на метке он и останавливается.
payload=$(awk '/^@@PAYLOAD@@$/ { print NR + 1; exit 0 }' "$0")
if [ -z "$payload" ]; then
  echo "Файл повреждён: сборка внутри не найдена" >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM
tail -n +"$payload" "$0" | tar -xzf - -C "$work"

if [ "$mode" = extract ]; then
  mkdir -p "$extract_to"
  cp -a "$work/." "$extract_to/"
  echo "Распаковано: $extract_to"
  exit 0
fi

# Заменяем папку целиком, а не докладываем поверх: файлы прошлой версии,
# которых в новой нет, иначе остались бы лежать. Прежняя не удаляется, а
# отодвигается — если замена сорвётся, откатиться есть куда.
mkdir -p "$(dirname "$target")"
if [ -e "$target" ]; then
  rm -rf "$target.old"
  mv "$target" "$target.old"
fi
if ! mv "$work" "$target"; then
  if [ -e "$target.old" ]; then mv "$target.old" "$target"; fi
  echo "Не удалось поставить в $target" >&2
  exit 1
fi
# mktemp создаёт папку только для себя, а приложение потом читают и другие
# программы — тот же поиск записей в меню.
chmod 755 "$target"
rm -rf "$target.old"

# Одним проходом, а не правкой на месте: у sed -i на разных системах
# разные требования к ключам, а тут он ещё и чужой.
mkdir -p "$apps"
sed -e "s|@EXEC@|$target/evaporate|" \
    -e "s|@ICON@|$target/data/app_icon.png|" \
    > "$apps/evaporate.desktop" <<'DESKTOP'
HEAD

  cat "$work/desktop"

  cat <<'TAIL'
DESKTOP
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$apps" >/dev/null 2>&1 || true
fi

mkdir -p "$bin"
ln -sf "$target/evaporate" "$bin/evaporate"

# Снаружи папки приложения, и это не мелочь: обновление по нажатию заменяет
# её целиком, и лежи удаление внутри — оно исчезло бы после первого же
# обновления.
cat > "$bin/evaporate-uninstall" <<UNINSTALL
#!/bin/sh
# Убирает то, что положил установщик. Настройки, библиотека и снимки
# сохранений остаются: они лежат не здесь и переживают переустановку.
set -eu
rm -rf '$target' '$target.old'
rm -f '$apps/evaporate.desktop'
rm -f '$bin/evaporate'
rm -f '$bin/evaporate-uninstall'
echo 'Evaporate удалён. Настройки и сохранения остались на месте.'
UNINSTALL
chmod +x "$bin/evaporate-uninstall"

echo "Evaporate $version поставлен: $target"
echo "Запуск — из меню приложений или командой evaporate."
case ":$PATH:" in
  *":$bin:"*) ;;
  *) echo "Команда лежит в $bin — этой папки нет в PATH." ;;
esac
echo "Удалить — evaporate-uninstall."

# Дальше двоичные данные, и выполнять их нельзя.
exit 0
@@PAYLOAD@@
TAIL
} > "$work/installer"

mkdir -p "$out"
package="$out/evaporate-$version-linux-x86_64.run"
cat "$work/installer" > "$package"
tar -czf - -C "$bundle" . >> "$package"
chmod +x "$package"
echo "$package"
