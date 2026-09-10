import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/settings/app_settings.dart';
import 'src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PostKillerRustLib.init();
  final settings = await AppSettings.loadDesktop();
  runApp(PostKillerApp(settings: settings));
}
