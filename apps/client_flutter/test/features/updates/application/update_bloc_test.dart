import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:client_flutter/src/features/updates/application/update_bloc.dart';
import 'package:client_flutter/src/features/updates/data/github_release_gateway.dart';
import 'package:client_flutter/src/features/updates/data/update_repository.dart';
import 'package:client_flutter/src/features/updates/domain/update_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('duplicate checks share the active lookup', () async {
    final repository = _DelayedUpdateRepository();
    final bloc = UpdateBloc(repository);
    final checking = bloc.stream.firstWhere((state) => state is UpdateChecking);
    bloc.add(const UpdateCheckRequested());
    await checking;
    bloc.add(const UpdateCheckRequested());
    await Future<void>.delayed(Duration.zero);
    expect(repository.calls, 1);
    final complete = bloc.stream.firstWhere((state) => state is UpdateCurrent);
    repository.result.complete(const UpdateIsCurrent());
    await complete;
    await bloc.close();
  });

  blocTest<UpdateBloc, UpdateState>(
    'offers a newer release for explicit download',
    build: () => UpdateBloc(
      _FakeUpdateRepository(
        UpdateIsAvailable(
          AppUpdate(
            version: 'v0.1.7',
            assetName: 'Post-Killer-0.1.7-macos.dmg',
            downloadUri: Uri.parse(
              'https://example.test/Post-Killer-0.1.7-macos.dmg',
            ),
          ),
        ),
      ),
    ),
    act: (bloc) => bloc.add(const UpdateCheckRequested()),
    expect: () => [isA<UpdateChecking>(), isA<UpdateAvailable>()],
  );

  blocTest<UpdateBloc, UpdateState>(
    'keeps the UI recoverable when GitHub is unavailable',
    build: () => UpdateBloc(_FailingUpdateRepository()),
    act: (bloc) => bloc.add(const UpdateCheckRequested()),
    expect: () => [isA<UpdateChecking>(), isA<UpdateCheckFailed>()],
  );

  test('only stable semantic versions newer than current are offered', () {
    expect(isNewerStableVersion('v0.1.7', '0.1.6'), isTrue);
    expect(isNewerStableVersion('v0.1.6', '0.1.6'), isFalse);
    expect(isNewerStableVersion('v0.1.5', '0.1.6'), isFalse);
    expect(isNewerStableVersion('v0.1.7-beta.1', '0.1.6'), isFalse);
  });
}

class _FakeUpdateRepository implements UpdateRepository {
  const _FakeUpdateRepository(this.result);
  final UpdateCheckResult result;

  @override
  Future<UpdateCheckResult> checkForUpdate() async => result;
}

class _FailingUpdateRepository implements UpdateRepository {
  @override
  Future<UpdateCheckResult> checkForUpdate() =>
      Future<UpdateCheckResult>.error(const UpdateLookupException());
}

class _DelayedUpdateRepository implements UpdateRepository {
  final result = Completer<UpdateCheckResult>();
  int calls = 0;
  @override
  Future<UpdateCheckResult> checkForUpdate() {
    calls += 1;
    return result.future;
  }
}
