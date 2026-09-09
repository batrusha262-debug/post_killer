import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

import 'features/updates/application/update_bloc.dart';
import 'features/updates/data/github_release_gateway.dart';
import 'features/updates/data/update_repository.dart';
import 'features/workspace/application/workspace_bloc.dart';
import 'features/workspace/data/workspace_gateway.dart';
import 'features/workspace/data/request_executor.dart';
import 'features/workspace/data/workspace_repository.dart';
import 'features/workspace/presentation/workspace_screen.dart';

class PostKillerApp extends StatelessWidget {
  const PostKillerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'Post Killer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: colorScheme.surface,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => WorkspaceBloc(
              GatewayWorkspaceRepository(const InMemoryWorkspaceGateway()),
              executor: const FrbRequestExecutor(),
            ),
          ),
          BlocProvider(
            create: (_) => UpdateBloc(
              GitHubUpdateRepository(
                gateway: HttpGitHubReleaseGateway(http.Client()),
                currentVersion: const String.fromEnvironment(
                  'APP_VERSION',
                  defaultValue: '0.1.0',
                ),
              ),
            ),
          ),
        ],
        child: const WorkspaceScreen(),
      ),
    );
  }
}
