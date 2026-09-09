import 'package:client_flutter/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const PostKillerApp());
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
