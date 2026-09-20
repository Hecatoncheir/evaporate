import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/proxy_settings.dart';

part 'proxy_form_event.dart';
part 'proxy_form_state.dart';

/// Адрес прокси, пока его набирают.
///
/// Настройки применяются кнопкой, а не по каждому знаку: смена прокси
/// перезапускает активные задачи, а на полпути набранный адрес — не адрес.
/// Но то, что уже набрано, должно быть видно сразу: прежде строка рядом с
/// клавишей показывала сохранённое, и человек сверял не то, что применит.
///
/// Неверный порт прежде молча подменялся прежним — и «Применить» уносило в
/// настройки совсем не тот адрес, который стоял в поле.
class ProxyFormBloc extends Bloc<ProxyFormEvent, ProxyForm> {
  ProxyFormBloc(ProxySettings saved) : super(ProxyForm.of(saved)) {
    on<ProxyHostChanged>((event, emit) => emit(state.withHost(event.host)));
    on<ProxyPortChanged>((event, emit) => emit(state.withPort(event.port)));
    on<ProxyUserChanged>((event, emit) => emit(state.withUser(event.user)));
    on<ProxyPasswordChanged>(
      (event, emit) => emit(state.withPassword(event.password)),
    );
    on<ProxySavedChanged>((event, emit) => emit(ProxyForm.of(event.saved)));
  }
}
