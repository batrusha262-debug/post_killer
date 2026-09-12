import 'package:client_flutter/src/features/workspace/presentation/json_body_editor.dart';
import 'package:client_flutter/src/features/workspace/presentation/json_editing.dart';
import 'package:client_flutter/src/features/workspace/presentation/json_syntax.dart';
import 'package:client_flutter/src/features/workspace/presentation/response_view.dart';
import 'package:client_flutter/src/features/workspace/presentation/request_auth_editor.dart';
import 'package:client_flutter/src/features/workspace/domain/workspace_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('indent and outdent preserve selected lines and cursor', () {
    const value = TextEditingValue(
      text: 'a\nb',
      selection: TextSelection(baseOffset: 0, extentOffset: 3),
    );
    final indented = indentJson(value);
    expect(indented.text, '  a\n  b');
    expect(indentJson(indented, outdent: true).text, value.text);
    expect(
      indentJson(
        const TextEditingValue(
          text: '\n',
          selection: TextSelection.collapsed(offset: 0),
        ),
        outdent: true,
      ).text,
      '\n',
    );
  });
  test(
    'completion replaces a prefix and preserves the rest of the document',
    () {
      const value = TextEditingValue(
        text: '{"ok": tr}',
        selection: TextSelection.collapsed(offset: 9),
      );
      expect(jsonCompletions(value).single.apply(value).text, '{"ok": true}');
      const key = TextEditingValue(
        text: '{"na": 1}',
        selection: TextSelection.collapsed(offset: 4),
      );
      expect(jsonCompletions(key).single.apply(key).text, '{"name": 1}');
      expect(
        jsonCompletions(
          const TextEditingValue(
            text: '{"value":"tr',
            selection: TextSelection.collapsed(offset: 12),
          ),
        ),
        isEmpty,
      );
    },
  );
  test('pair insertion does not alter braces inside strings', () {
    const old = TextEditingValue(
      text: '"',
      selection: TextSelection.collapsed(offset: 1),
    );
    const next = TextEditingValue(
      text: '"{',
      selection: TextSelection.collapsed(offset: 2),
    );
    expect(const JsonPairFormatter().formatEditUpdate(old, next), next);
  });
  testWidgets(
    'Tab inserts spaces, Shift Tab removes them and Enter accepts inline completion',
    (tester) async {
      var edited = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonBodyEditor(value: '', onChanged: (text) => edited = text),
          ),
        ),
      );
      final field = find.byKey(const Key('json-body-editor'));
      await tester.tap(field);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(edited, '  ');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(edited, '');
      await tester.enterText(field, '{"ok": tr');
      await tester.pump();
      expect(find.byKey(const Key('json-autocomplete')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(edited, '{"ok": true');
      expect(
        tester.widget<TextField>(field).decoration!.hintStyle!.color,
        Colors.grey,
      );
    },
  );
  testWidgets(
    'response presents pretty JSON, raw body and headers separately',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponseView(
              execution: RequestExecutionView.response(
                requestId: 'one',
                status: 200,
                durationMillis: 12,
                headers: const [
                  RequestResponseHeader(
                    name: 'content-type',
                    value: 'application/json',
                  ),
                ],
                body: '{"ok":true}',
              ),
            ),
          ),
        ),
      );
      expect(find.text('HTTP 200'), findsOneWidget);
      final pretty = tester.widget<SelectableText>(
        find.byKey(const Key('response-content')),
      );
      expect(pretty.textSpan!.toPlainText(), '{\n  "ok": true\n}');
      await tester.tap(find.text('Raw'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SelectableText>(find.byKey(const Key('response-raw')))
            .data,
        '{"ok":true}',
      );
      await tester.tap(find.text('Headers (1)'));
      await tester.pumpAndSettle();
      expect(find.text('content-type'), findsOneWidget);
    },
  );

  testWidgets('response search reports and highlights body matches', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResponseView(
            execution: RequestExecutionView.response(
              requestId: 'one',
              status: 200,
              durationMillis: 12,
              headers: const [],
              body: 'alpha beta ALPHA',
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('response-search')).first,
      'alpha',
    );
    await tester.pump();
    expect(find.text('2 matches'), findsWidgets);
    final highlighted = tester.widget<SelectableText>(
      find.byKey(const Key('response-content')),
    );
    expect(highlighted.textSpan!.toPlainText(), 'alpha beta ALPHA');
  });

  testWidgets('binary response shows preview and save controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResponseView(
            execution: RequestExecutionView.response(
              requestId: 'binary',
              status: 200,
              durationMillis: 12,
              headers: const [
                RequestResponseHeader(
                  name: 'content-type',
                  value: 'application/octet-stream',
                ),
              ],
              body: 'lossy preview',
              bodyBytes: [0, 255, 12],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Binary'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.byKey(const Key('response-download')), findsWidgets);
    expect(
      find.text('3 bytes — save the response to inspect it locally.'),
      findsWidgets,
    );
  });

  testWidgets('auth editor exposes required-field errors for Basic auth', (
    tester,
  ) async {
    RequestAuth? edited;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RequestAuthEditor(
            auth: const RequestAuth(kind: RequestAuthKind.basic),
            onChanged: (auth) => edited = auth,
          ),
        ),
      ),
    );

    expect(find.text('Username is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('auth-password-field')),
              matching: find.byType(TextField),
            ),
          )
          .obscureText,
      isTrue,
    );
    await tester.enterText(find.byKey(const Key('auth-username-field')), 'ada');
    expect(edited!.username, 'ada');
  });

  testWidgets('API key auth selects header or query placement', (tester) async {
    RequestAuth? edited;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RequestAuthEditor(
            auth: const RequestAuth(kind: RequestAuthKind.apiKey),
            onChanged: (auth) => edited = auth,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('auth-api-placement-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Query parameter').last);
    expect(edited!.placement, ApiKeyPlacement.query);
  });

  testWidgets('auth editor redacts a runtime token obtained from login', (
    tester,
  ) async {
    const token = 'access-token-that-must-not-be-rendered';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RequestAuthEditor(
            auth: RequestAuth(
              kind: RequestAuthKind.bearer,
              loginRequestId: 'saved-login-request',
              acquiredToken: token,
            ),
            onChanged: _ignoreAuthChange,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('auth-acquired-token')), findsOneWidget);
    expect(find.text('Received token: ••••••••'), findsOneWidget);
    expect(find.textContaining(token), findsNothing);
  });
}

void _ignoreAuthChange(RequestAuth _) {}
