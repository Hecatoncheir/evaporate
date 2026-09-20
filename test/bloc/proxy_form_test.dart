import 'package:evaporate/bloc/proxy_form/proxy_form_bloc.dart';
import 'package:evaporate/models/proxy_settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// Прокси включают ради скрытности, и молча подменять в нём что-либо
/// нельзя: применится именно набранное или не применится ничего.
void main() {
  const saved = ProxySettings(
    enabled: true,
    host: 'прокси.местный',
    port: 1080,
  );

  ProxyFormBloc form([ProxySettings settings = saved]) {
    final bloc = ProxyFormBloc(settings);
    addTearDown(bloc.close);
    return bloc;
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  test('форма открывается на сохранённом', () {
    final state = form().state;

    expect(state.host, 'прокси.местный');
    expect(state.port, '1080');
    expect(state.dirty, isFalse);
    expect(state.canApply, isFalse, reason: 'применять нечего');
  });

  // Прежде негодный порт молча подменялся прежним, и «Применить» уносило в
  // настройки совсем не тот адрес, который стоял в поле.
  test('порт вне диапазона — отказ, а не тихая подмена', () async {
    final bloc = form();

    bloc.add(const ProxyPortChanged('80800'));
    await settle();

    expect(bloc.state.portInvalid, isTrue);
    expect(bloc.state.canApply, isFalse);
  });

  test('ноль портом не бывает', () async {
    final bloc = form();

    bloc.add(const ProxyPortChanged('0'));
    await settle();

    expect(bloc.state.portInvalid, isTrue);
  });

  test('пустой порт — ещё не отказ: его просто стёрли', () async {
    final bloc = form();

    bloc.add(const ProxyPortChanged(''));
    await settle();

    expect(bloc.state.portInvalid, isFalse);
    expect(bloc.state.parsedPort, isNull);
  });

  // Строка рядом с клавишей показывала сохранённое: человек сверял не то,
  // что применит.
  test('черновик собирается из набранного', () async {
    final bloc = form();

    bloc
      ..add(const ProxyHostChanged('  другой.прокси  '))
      ..add(const ProxyPortChanged('3128'));
    await settle();

    expect(bloc.state.draft.host, 'другой.прокси');
    expect(bloc.state.draft.port, 3128);
    expect(bloc.state.draft.uri, contains('другой.прокси:3128'));
    expect(bloc.state.canApply, isTrue);
  });

  test('выключенный прокси применять нечем', () async {
    final bloc = form(const ProxySettings(host: 'прокси', port: 1080));

    bloc.add(const ProxyHostChanged('другой'));
    await settle();

    expect(bloc.state.dirty, isTrue);
    expect(bloc.state.canApply, isFalse);
  });

  // Нажал — клавиша погасла: это и есть ответ вместо всплывающего
  // сообщения.
  test('после применения применять снова нечего', () async {
    final bloc = form();

    bloc.add(const ProxyHostChanged('другой.прокси'));
    await settle();
    expect(bloc.state.canApply, isTrue);

    bloc.add(ProxySavedChanged(bloc.state.draft));
    await settle();

    expect(bloc.state.canApply, isFalse);
    expect(bloc.state.host, 'другой.прокси');
  });

  test('пароль не обрезается по краям: пробел в нём — знак пароля', () async {
    final bloc = form();

    bloc.add(const ProxyPasswordChanged(' тайна '));
    await settle();

    expect(bloc.state.draft.password, ' тайна ');
  });
}
