import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'features/workspace/application/workspace_bloc.dart';
import 'features/workspace/data/workspace_gateway.dart';
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
      home: BlocProvider(
        create: (_) => WorkspaceBloc(
          GatewayWorkspaceRepository(const InMemoryWorkspaceGateway()),
        ),
        child: const WorkspaceScreen(),
      ),
    );
  }
}
