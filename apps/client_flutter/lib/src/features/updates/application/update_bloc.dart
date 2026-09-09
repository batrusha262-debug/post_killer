import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/update_repository.dart';
import '../data/github_release_gateway.dart';
import '../domain/update_models.dart';

sealed class UpdateEvent {
  const UpdateEvent();
}

class UpdateCheckRequested extends UpdateEvent {
  const UpdateCheckRequested();
}

sealed class UpdateState {
  const UpdateState();
}

class UpdateIdle extends UpdateState {
  const UpdateIdle();
}

class UpdateChecking extends UpdateState {
  const UpdateChecking();
}

class UpdateCurrent extends UpdateState {
  const UpdateCurrent();
}

class UpdateAvailable extends UpdateState {
  const UpdateAvailable(this.update);
  final AppUpdate update;
}

class UpdateCheckFailed extends UpdateState {
  const UpdateCheckFailed([
    this.message = 'Не удалось проверить обновления. Попробуйте позже.',
  ]);
  final String message;
}

class UpdateBloc extends Bloc<UpdateEvent, UpdateState> {
  UpdateBloc(this._repository) : super(const UpdateIdle()) {
    on<UpdateCheckRequested>(_checkForUpdate);
  }

  final UpdateRepository _repository;

  Future<void> _checkForUpdate(
    UpdateCheckRequested event,
    Emitter<UpdateState> emit,
  ) async {
    if (state is UpdateChecking) return;
    emit(const UpdateChecking());
    try {
      switch (await _repository.checkForUpdate()) {
        case UpdateIsCurrent():
          emit(const UpdateCurrent());
        case UpdateIsAvailable(:final update):
          emit(UpdateAvailable(update));
      }
    } on UpdateLookupException catch (error) {
      emit(UpdateCheckFailed(error.message));
    } on Object {
      emit(const UpdateCheckFailed());
    }
  }
}
