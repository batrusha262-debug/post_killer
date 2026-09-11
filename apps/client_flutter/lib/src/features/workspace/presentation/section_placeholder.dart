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
  const VariablesPane({
    super.key,
    required this.environments,
    required this.selectedEnvironmentId,
    required this.onSelected,
    required this.onNewEnvironment,
    required this.onDeleteEnvironment,
    required this.onSaveVariable,
    required this.onDeleteVariable,
  });

  final List<WorkspaceEnvironment> environments;
  final String? selectedEnvironmentId;
  final ValueChanged<String?> onSelected;
  final VoidCallback onNewEnvironment;
  final ValueChanged<String> onDeleteEnvironment;
  final ValueChanged<RequestKeyValue> onSaveVariable;
  final ValueChanged<String> onDeleteVariable;

  @override
  Widget build(BuildContext context) {
    final selected = environments
        .where((environment) => environment.id == selectedEnvironmentId)
        .firstOrNull;
    if (environments.isEmpty) {
      return Center(
        child: FilledButton.icon(
          onPressed: onNewEnvironment,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create environment'),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: selectedEnvironmentId,
                decoration: const InputDecoration(
                  labelText: 'Active environment',
                ),
                items: [
                  for (final environment in environments)
                    DropdownMenuItem(
                      value: environment.id,
                      child: Text(environment.name),
                    ),
                ],
                onChanged: onSelected,
              ),
            ),
            IconButton(
              tooltip: 'Delete environment',
              onPressed: selected == null
                  ? null
                  : () => onDeleteEnvironment(selected.id),
              icon: const Icon(Icons.delete_outline),
            ),
            IconButton(
              tooltip: 'New environment',
              onPressed: onNewEnvironment,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Variables', style: Theme.of(context).textTheme.titleMedium),
        if (selected != null) ...[
          for (final variable in selected.variables)
            ListTile(
              dense: true,
              leading: Checkbox(
                value: variable.enabled,
                onChanged: (enabled) => onSaveVariable(
                  variable.copyWith(enabled: enabled ?? false),
                ),
              ),
              title: Text(variable.key),
              subtitle: SelectableText(variable.value),
              trailing: IconButton(
                tooltip: 'Delete variable',
                onPressed: () => onDeleteVariable(variable.id),
                icon: const Icon(Icons.delete_outline, size: 19),
              ),
            ),
          TextButton.icon(
            onPressed: () => _showCreateVariableDialog(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add variable'),
          ),
        ],
      ],
    );
  }

  Future<void> _showCreateVariableDialog(BuildContext context) async {
    final key = TextEditingController();
    final value = TextEditingController();
    final created = await showDialog<RequestKeyValue>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New variable'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: key,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Key'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: value,
              decoration: const InputDecoration(labelText: 'Value'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              RequestKeyValue(
                id: 'environment-${DateTime.now().microsecondsSinceEpoch}',
                key: key.text.trim(),
                value: value.text,
              ),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    key.dispose();
    value.dispose();
    if (created != null && created.key.isNotEmpty) onSaveVariable(created);
  }
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
