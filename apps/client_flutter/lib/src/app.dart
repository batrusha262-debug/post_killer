import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

import 'settings/app_settings.dart';
import 'settings/app_theme.dart';
import 'features/updates/application/update_bloc.dart';
import 'features/updates/data/github_release_gateway.dart';
import 'features/updates/data/update_repository.dart';
import 'features/workspace/application/workspace_bloc.dart';
import 'features/workspace/data/request_executor.dart';
import 'features/workspace/data/workspace_gateway.dart';
import 'features/workspace/data/workspace_repository.dart';
import 'features/workspace/presentation/workspace_screen.dart';

class PostKillerApp extends StatefulWidget {
  const PostKillerApp({
    super.key,
    this.workspaceRepository,
    this.requestExecutor,
    this.updateRepository,
    this.settings,
  });

  final WorkspaceRepository? workspaceRepository;
  final RequestExecutor? requestExecutor;
  final UpdateRepository? updateRepository;

  final AppSettings? settings;

  @override
  State<PostKillerApp> createState() => _PostKillerAppState();
}

class _PostKillerAppState extends State<PostKillerApp> {
  late final AppSettings settings = widget.settings ?? AppSettings();

  @override
  void dispose() {
    if (widget.settings == null) settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsScope(
    settings: settings,
    child: ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'Post Killer',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(settings, Brightness.light),
        darkTheme: buildAppTheme(settings, Brightness.dark),
        themeMode: switch (settings.appearance) {
          AppAppearance.system => ThemeMode.system,
          AppAppearance.dark || AppAppearance.slay => ThemeMode.dark,
          AppAppearance.light => ThemeMode.light,
        },
        themeAnimationDuration: settings.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations:
                settings.reduceMotion ||
                MediaQuery.of(context).disableAnimations,
          ),
          child: child!,
        ),
        home: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => WorkspaceBloc(
                widget.workspaceRepository ??
                    GatewayWorkspaceRepository(const FrbWorkspaceGateway()),
                executor: widget.requestExecutor ?? const FrbRequestExecutor(),
              ),
            ),
            BlocProvider(
              create: (_) => UpdateBloc(
                widget.updateRepository ??
                    GitHubUpdateRepository(
                      gateway: HttpGitHubReleaseGateway(http.Client()),
                      currentVersion: const String.fromEnvironment(
                        'APP_VERSION',
                        defaultValue: '0.2.26',
                      ),
                    ),
              ),
            ),
          ],
          child: const WorkspaceScreen(),
        ),
      ),
    ),
  );
}
