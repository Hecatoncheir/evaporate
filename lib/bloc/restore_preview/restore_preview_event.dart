part of 'restore_preview_bloc.dart';

sealed class RestorePreviewEvent extends Equatable {
  const RestorePreviewEvent();

  @override
  List<Object?> get props => [];
}

/// Посмотреть, куда лягут файлы снимка и что лежит там сейчас.
final class RestorePreviewRequested extends RestorePreviewEvent {
  const RestorePreviewRequested({required this.game, required this.snapshot});

  final Game game;
  final SaveSnapshot snapshot;

  @override
  List<Object?> get props => [game, snapshot];
}
