import 'package:client_flutter/src/app.dart';
import 'package:client_flutter/src/features/workspace/data/request_executor.dart';
import 'package:client_flutter/src/features/workspace/data/workspace_repository.dart';
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
    await tester.pumpWidget(
      PostKillerApp(
        workspaceRepository: const _WidgetWorkspaceRepository(),
        requestExecutor: requestExecutor,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows desktop workspace with collection and active request', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Post Killer'), findsOneWidget);
    expect(find.text('Getting started'), findsOneWidget);
    expect(find.text('Health check'), findsNWidgets(3));
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
    expect(find.text('Untitled 1'), findsNWidgets(2));

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
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('json-body-editor')),
      '{"enabled": true}',
    );
    await tester.pump();

    expect(find.text('Health check •'), findsOneWidget);
  });

  testWidgets('validates, formats and completes a JSON request body', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Body'));
    await tester.pumpAndSettle();
    final editor = find.byKey(const Key('json-body-editor'));

    await tester.enterText(editor, '{"enabled": ');
    await tester.pump();
    expect(find.byKey(const Key('json-validation-error')), findsOneWidget);
    expect(find.text('Fix JSON to send'), findsOneWidget);

    await tester.enterText(editor, '{"enabled": tr');
    await tester.pump();
    await tester.tap(find.text('true'));
    await tester.pump();
    expect(
      tester.widget<TextField>(editor).controller!.text,
      '{"enabled": true',
    );

    await tester.enterText(editor, '{"enabled": true}');
    await tester.pump();
    expect(find.byKey(const Key('json-validation-error')), findsNothing);
    expect(find.text('Send'), findsOneWidget);

    await tester.tap(find.byKey(const Key('format-json-button')));
    await tester.pump();
    expect(
      tester.widget<TextField>(editor).controller!.text,
      '{\n  "enabled": true\n}',
    );
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
    expect(find.text('Health check'), findsNWidgets(2));

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
    expect(find.text('Health check'), findsNWidgets(3));
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

class _WidgetWorkspaceRepository implements WorkspaceRepository {
  const _WidgetWorkspaceRepository();

  @override
  Future<List<WorkspaceSummary>> listWorkspaces() async => const [
    WorkspaceSummary(id: 'workspace', name: 'Workspace'),
  ];

  @override
  Future<List<RequestCollection>> listCollections(String workspaceId) async =>
      const [
        RequestCollection(
          id: 'starter',
          name: 'Getting started',
          requests: [
            SavedRequest(
              id: 'health-check',
              name: 'Health check',
              method: HttpMethod.get,
              url: 'https://api.example.com/health',
            ),
            SavedRequest(
              id: 'create-user',
              name: 'Create user',
              method: HttpMethod.post,
              url: 'https://api.example.com/users',
            ),
          ],
        ),
      ];

  @override
  Future<WorkspaceSummary> createWorkspace(String name) async =>
      WorkspaceSummary(id: 'new-workspace', name: name);

  @override
  Future<RequestCollection> createCollection({
    required String workspaceId,
    required String name,
  }) async =>
      RequestCollection(id: 'new-collection', name: name, requests: const []);

  @override
  Future<SavedRequest> saveRequest({
    required String collectionId,
    required RequestTab request,
  }) async => SavedRequest(
    id: request.id,
    name: request.title,
    method: request.method,
    url: request.url,
    query: request.query,
    headers: request.headers,
    body: request.body,
  );
}
