import 'package:client_flutter/src/features/updates/data/github_release_gateway.dart';
import 'package:client_flutter/src/features/updates/application/update_bloc.dart';
import 'package:client_flutter/src/features/updates/data/update_repository.dart';
import 'package:client_flutter/src/features/updates/domain/update_models.dart';
import 'package:client_flutter/src/features/updates/presentation/update_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('failed check explains the problem and offers release page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider(
            create: (_) => UpdateBloc(_PrivateReleaseRepository()),
            child: const UpdateAction(),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('check-updates-button')));
    await tester.pumpAndSettle();
    expect(find.text('Нужен вход в GitHub'), findsOneWidget);
    expect(find.text('Открыть релизы'), findsOneWidget);
    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('check-updates-button')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('exposes a named update button to accessibility services', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider(
            create: (_) => UpdateBloc(const _CurrentVersionRepository()),
            child: const UpdateAction(),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Проверить обновления'), findsOneWidget);
  });

  testWidgets('asks before opening an update download', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider(
            create: (_) => UpdateBloc(_AvailableUpdateRepository()),
            child: const UpdateAction(),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('check-updates-button')));
    await tester.pumpAndSettle();

    expect(find.text('Доступна v0.1.8'), findsOneWidget);
    expect(find.text('Скачать и установить'), findsOneWidget);
  });
}

class _CurrentVersionRepository implements UpdateRepository {
  const _CurrentVersionRepository();

  @override
  Future<UpdateCheckResult> checkForUpdate() async => const UpdateIsCurrent();
}

class _AvailableUpdateRepository implements UpdateRepository {
  @override
  Future<UpdateCheckResult> checkForUpdate() async => UpdateIsAvailable(
    AppUpdate(
      version: 'v0.1.8',
      assetName: 'Post-Killer-0.1.8-macos.dmg',
      downloadUri: Uri.parse(
        'https://example.test/Post-Killer-0.1.8-macos.dmg',
      ),
    ),
  );
}

class _PrivateReleaseRepository implements UpdateRepository {
  @override
  Future<UpdateCheckResult> checkForUpdate() async =>
      throw const UpdateLookupException('Нужен вход в GitHub');
}
