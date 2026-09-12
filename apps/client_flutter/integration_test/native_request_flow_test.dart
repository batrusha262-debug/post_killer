import 'dart:io';

import 'package:client_flutter/src/app.dart';
import 'package:client_flutter/src/rust/frb_generated.dart';
import 'package:flutter/widgets.dart';
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

    await tester.tap(find.byTooltip('New tab'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('request-url-field')),
      'http://${server.address.address}:${server.port}/native-frb',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-request-button')));

    await tester.pumpAndSettle(const Duration(seconds: 10));
    await tester.tap(find.byKey(const Key('response-tab')));
    await tester.pumpAndSettle();

    expect(find.text('HTTP 200'), findsOneWidget);
    expect(find.textContaining('native-frb'), findsOneWidget);
  });
}
