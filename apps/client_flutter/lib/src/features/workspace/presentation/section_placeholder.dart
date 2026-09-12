import 'package:flutter/material.dart';

import '../domain/workspace_models.dart';
import 'method_color.dart';

class HistoryPane extends StatelessWidget {
  const HistoryPane({
    super.key,
    required this.entries,
    required this.query,
    required this.onQueryChanged,
    required this.onOpen,
    required this.onClear,
  });

  final List<RequestHistoryEntry> entries;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onOpen;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'История',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: entries.isEmpty ? null : onClear,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Очистить'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('history-search'),
          onChanged: onQueryChanged,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Поиск по названию или методу',
          ),
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 36),
            child: Center(
              child: Text(
                query.isEmpty
                    ? 'История запросов пока пуста'
                    : 'Ничего не найдено',
              ),
            ),
          )
        else
          for (final entry in entries)
            ListTile(
              key: Key('history-entry-${entry.id}'),
              dense: true,
              onTap: () => onOpen(entry.requestId),
              leading: Icon(
                entry.result == ExecutionHistoryResult.response
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                color: entry.result == ExecutionHistoryResult.response
                    ? methodColor(context, entry.method)
                    : Theme.of(context).colorScheme.error,
              ),
              title: Text('${entry.method.label} ${entry.title}'),
              subtitle: Text(_summary(entry)),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            ),
      ],
    );
  }

  String _summary(RequestHistoryEntry entry) {
    if (entry.result != ExecutionHistoryResult.response) {
      return 'Ошибка · ${_errorLabel(entry.errorCategory)}';
    }
    return 'HTTP ${entry.status ?? '—'} · ${entry.durationMillis} ms · '
        '${_bytes(entry.responseSizeBytes)}';
  }

  String _errorLabel(ExecutionHistoryErrorCategory? category) =>
      switch (category) {
        ExecutionHistoryErrorCategory.timeout => 'тайм-аут',
        ExecutionHistoryErrorCategory.dns => 'DNS',
        ExecutionHistoryErrorCategory.connection => 'соединение',
        ExecutionHistoryErrorCategory.tls => 'TLS',
        ExecutionHistoryErrorCategory.proxy => 'прокси',
        ExecutionHistoryErrorCategory.redirect => 'перенаправление',
        ExecutionHistoryErrorCategory.requestBody => 'тело запроса',
        ExecutionHistoryErrorCategory.responseBody => 'тело ответа',
        _ => 'неизвестная ошибка',
      };

  String _bytes(int bytes) =>
      bytes < 1024 ? '$bytes B' : '${(bytes / 1024).toStringAsFixed(1)} KB';
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
          label: const Text('Создать окружение'),
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
                  labelText: 'Активное окружение',
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
              tooltip: 'Удалить окружение',
              onPressed: selected == null
                  ? null
                  : () => onDeleteEnvironment(selected.id),
              icon: const Icon(Icons.delete_outline),
            ),
            IconButton(
              tooltip: 'Создать окружение',
              onPressed: onNewEnvironment,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Переменные', style: Theme.of(context).textTheme.titleMedium),
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
              subtitle: SelectableText(
                _isSecretVariable(variable.key) ? '••••••••' : variable.value,
              ),
              trailing: IconButton(
                tooltip: 'Удалить переменную',
                onPressed: () => onDeleteVariable(variable.id),
                icon: const Icon(Icons.delete_outline, size: 19),
              ),
            ),
          TextButton.icon(
            onPressed: () => _showCreateVariableDialog(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Добавить переменную'),
          ),
        ],
      ],
    );
  }

  bool _isSecretVariable(String key) {
    final normalized = key.trim().toLowerCase();
    return [
      'token',
      'secret',
      'password',
      'api_key',
      'api-key',
      'apikey',
      'credential',
    ].any(normalized.contains);
  }

  Future<void> _showCreateVariableDialog(BuildContext context) async {
    final key = TextEditingController();
    final value = TextEditingController();
    final created = await showDialog<RequestKeyValue>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Новая переменная'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: key,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Ключ'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: value,
              decoration: const InputDecoration(labelText: 'Значение'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
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
            child: const Text('Добавить'),
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
