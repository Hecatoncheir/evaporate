import 'dart:io';

/// Достаёт описание версии из `CHANGELOG.md`.
///
/// Нужен выпуску: описание релиза и запись в истории изменений — это один и
/// тот же текст, и писать его дважды значит однажды разойтись. Раньше в
/// релиз уезжала заглушка «Описание пока не написано», а настоящий текст
/// лежал рядом в файле.
///
///     dart run tool/changelog_notes.dart 0.8.0
///
/// Печатает описание в stdout. Если раздела нет — ничего не печатает и
/// завершается с ненулевым кодом: вызывающий решает, что с этим делать.
void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln(
      'Использование: dart run tool/changelog_notes.dart <версия>',
    );
    exit(2);
  }

  final file = File('CHANGELOG.md');
  if (!file.existsSync()) {
    stderr.writeln('Не нашёл CHANGELOG.md рядом — запускайте из корня проекта');
    exit(2);
  }

  final notes = changelogNotes(file.readAsStringSync(), args.single);
  if (notes == null) {
    stderr.writeln('В CHANGELOG.md нет раздела для версии ${args.single}');
    exit(1);
  }
  stdout.write(notes);
}

/// Текст раздела [version] из [changelog], без заголовка самой версии.
///
/// Возвращает `null`, когда раздела нет: молча подставить пустую строку
/// значило бы выпустить релиз без описания и не заметить этого.
String? changelogNotes(String changelog, String version) {
  final lines = changelog.split('\n');
  final header = '## [$version]';

  var start = -1;
  for (var i = 0; i < lines.length; i++) {
    // Именно startsWith: за версией идёт ещё дата, и она у каждой своя.
    if (lines[i].startsWith(header)) {
      start = i + 1;
      break;
    }
  }
  if (start == -1) return null;

  final collected = <String>[];
  for (var i = start; i < lines.length; i++) {
    final line = lines[i];
    if (line.startsWith('## ')) break;
    // Ссылки на релизы идут сплошным блоком в конце файла и к описанию
    // последней версии не относятся — она просто стоит перед ними.
    if (_isLinkReference(line)) break;
    collected.add(line);
  }

  final notes = collected.join('\n').trim();
  return notes.isEmpty ? null : notes;
}

/// Самая свежая версия в [changelog] — та, что выпускают следующей.
///
/// Нужна тесту-стражу: тег теперь и есть версия, и проверить заранее, что
/// её раздел на месте, можно только со стороны файла. `null`, когда ни
/// одного разобранного заголовка версии нет.
String? latestVersion(String changelog) {
  // Именно первый сверху: разделы идут от новых к старым, и «Не выпущено»
  // с «не выпущена» под эту мерку не подходят — там, где стоит версия,
  // стоит именно версия.
  final header = RegExp(r'^## \[([0-9]+\.[0-9]+\.[0-9]+)\]', multiLine: true);
  return header.firstMatch(changelog)?.group(1);
}

/// Есть ли внизу файла определение ссылки на тег [version].
///
/// Заголовок раздела написан ссылкой (`## [0.8.0]`), и без определения он
/// останется на странице квадратными скобками вокруг числа.
bool hasLinkReference(String changelog, String version) => RegExp(
  '^\\[${RegExp.escape(version)}\\]:\\s',
  multiLine: true,
).hasMatch(changelog);

/// Строка вида `[0.8.0]: https://...` — определение ссылки, не текст.
final _linkReference = RegExp(r'^\[[^\]]+\]:\s');

bool _isLinkReference(String line) => _linkReference.hasMatch(line);
