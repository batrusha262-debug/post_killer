import 'package:flutter/material.dart';

import '../domain/workspace_models.dart';
import 'method_color.dart';

class HistoryPane extends StatelessWidget {
  const HistoryPane({super.key, required this.entries});

  final List<RequestHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SectionPlaceholder(
        title: 'History',
        icon: Icons.history,
        message: 'No request history yet',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('History', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final entry in entries)
          ListTile(
            key: Key('history-entry-${entry.id}'),
            dense: true,
            leading: Icon(
              entry.error == null
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              color: entry.error == null
                  ? methodColor(context, HttpMethod.get)
                  : Theme.of(context).colorScheme.error,
            ),
            title: Text('${entry.method.label} ${entry.title}'),
            subtitle: Text(
              entry.error ?? '${entry.url}\nHTTP ${entry.status ?? '—'}',
            ),
            isThreeLine: entry.error == null,
          ),
      ],
    );
  }
}

class VariablesPane extends StatelessWidget {
  const VariablesPane({super.key});

  @override
  Widget build(BuildContext context) => const SectionPlaceholder(
    title: 'Variables',
    icon: Icons.tune,
    message: 'No variables yet',
  );
}

class SectionPlaceholder extends StatelessWidget {
  const SectionPlaceholder({
    super.key,
    required this.title,
    required this.icon,
    required this.message,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(icon), const SizedBox(height: 8), Text(message)],
          ),
        ),
      ),
    ],
  );
}
