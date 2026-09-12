import 'dart:io';

import 'package:client_flutter/src/app.dart';
import 'package:client_flutter/src/rust/frb_generated.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sends a request through the native FRB transport', (
    tester,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      expect(request.method, 'GET');
      expect(request.uri.path, '/native-frb');
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"transport":"native-frb"}');
      await request.response.close();
    });
    addTearDown(server.close);

    await PostKillerRustLib.init();
    await tester.pumpWidget(const PostKillerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Новая вкладка'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('request-url-field')),
      'http://${server.address.address}:${server.port}/native-frb',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-request-button')));

    for (
      var attempt = 0;
      attempt < 40 && find.text('HTTP 200').evaluate().isEmpty;
      attempt += 1
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('response-tab')));
    await tester.pumpAndSettle();

    expect(find.text('HTTP 200'), findsOneWidget);
    final response = tester.widget<SelectableText>(
      find.byKey(const Key('response-content')),
    );
    expect(response.textSpan!.toPlainText(), contains('native-frb'));
  });
}
