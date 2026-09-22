import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Окончания строк заданы дважды — для git (`.gitattributes`) и для
/// редактора (`.editorconfig`), — и расходиться им нельзя: редактор,
/// пишущий не то, что ждёт git, оставляет файл «изменённым» с пустым
/// `git diff`. На Windows так висели 93 файла.
void main() {
  test('CRLF в редакторе ровно у тех, у кого он в git', () {
    final attributes = File('.gitattributes').readAsStringSync();
    final editor = File('.editorconfig').readAsStringSync();

    final inGit = {
      for (final m in RegExp(
        r'^\*\.(\w+)\s+text eol=crlf',
        multiLine: true,
      ).allMatches(attributes))
        m.group(1)!,
    };
    final crlfSection = RegExp(
      r'^\[\*\.\{([\w,]+)\}\]\nend_of_line = crlf',
      multiLine: true,
    ).firstMatch(editor);

    expect(inGit, isNotEmpty);
    expect(crlfSection, isNotNull, reason: 'в .editorconfig нет раздела CRLF');
    expect(crlfSection!.group(1)!.split(',').toSet(), inGit);
  });

  test('по умолчанию и там и там LF', () {
    expect(
      File('.gitattributes').readAsStringSync(),
      matches(RegExp(r'^\*\s+text=auto eol=lf$', multiLine: true)),
    );
    expect(
      File('.editorconfig').readAsStringSync(),
      matches(RegExp(r'\[\*\]\n(?:.+\n)*?end_of_line = lf\n')),
    );
  });
}
