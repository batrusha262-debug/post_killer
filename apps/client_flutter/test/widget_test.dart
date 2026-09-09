import 'package:client_flutter/src/app.dart';
import 'package:client_flutter/src/features/workspace/data/request_executor.dart';
import 'package:client_flutter/src/features/workspace/domain/workspace_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    RequestExecutor? requestExecutor,
  }) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(PostKillerApp(requestExecutor: requestExecutor));
  }

  testWidgets('shows desktop workspace with collection and active request', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Post Killer'), findsOneWidget);
    expect(find.text('Getting started'), findsOneWidget);
    expect(find.text('Health check'), findsNWidgets(2));
    expect(find.text('https://api.example.com/health'), findsOneWidget);
    expect(find.text('No query parameters'), findsOneWidget);
  });

  testWidgets('switches request tabs', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('request-tab-create-user')));
    await tester.pump();

    expect(find.text('https://api.example.com/users'), findsOneWidget);
    expect(find.text('POST'), findsWidgets);
  });

  testWidgets('creates a local request tab and tracks draft edits', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('new-request-button')));
    await tester.pump();
    expect(find.text('Untitled 1'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('request-url-field')),
      'https://localhost:8080/ping',
    );
    await tester.pump();

    expect(find.text('Untitled 1 •'), findsOneWidget);
  });

  testWidgets('renders the Rust validation error after Send', (tester) async {
    await pumpApp(tester, requestExecutor: const _ValidationErrorExecutor());

    await tester.tap(find.byKey(const Key('new-request-button')));
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('response-tab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('response-error')), findsOneWidget);
    expect(
      find.text('invalid request: request URL must not be empty'),
      findsOneWidget,
    );
  });

  testWidgets('edits a request body through the body tab', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Body'));
    await tester.pump();
    await tester.enterText(
      find.byType(TextFormField).last,
      '{"enabled": true}',
    );
    await tester.pump();

    expect(find.text('Health check •'), findsOneWidget);
  });

  testWidgets('navigates to History and Variables through the workspace BLoC', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('History').first);
    await tester.pump();
    expect(find.text('No request history yet'), findsOneWidget);
    expect(find.text('Getting started'), findsNothing);

    await tester.tap(find.text('Variables').first);
    await tester.pump();
    expect(find.text('No variables yet'), findsOneWidget);
  });

  testWidgets('filters collections without losing the original list', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.enterText(
      find.byKey(const Key('collection-search-field')),
      'create user',
    );
    await tester.pump();
    expect(find.text('Create user'), findsNWidgets(2));
    expect(find.text('Health check'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('collection-search-field')),
      'not found',
    );
    await tester.pump();
    expect(find.text('Getting started'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('collection-search-field')),
      '',
    );
    await tester.pump();
    expect(find.text('Health check'), findsNWidgets(2));
  });

  testWidgets(
    'hides environment and settings controls until their flows exist',
    (tester) async {
      await pumpApp(tester);

      expect(find.text('No environment'), findsNothing);
      expect(find.byIcon(Icons.settings_outlined), findsNothing);
    },
  );
}

class _ValidationErrorExecutor implements RequestExecutor {
  const _ValidationErrorExecutor();

  @override
  Future<RequestExecutionView> execute(RequestTab request) async =>
      RequestExecutionView.error(
        requestId: request.id,
        error: 'invalid request: request URL must not be empty',
      );
}
