import 'header_presets.dart';

import 'package:flutter/material.dart';

import '../domain/workspace_models.dart';

class KeyValueEditor extends StatelessWidget {
  const KeyValueEditor({
    super.key,
    required this.values,
    this.isHeader = false,
    this.onHeaderPreset,
    required this.emptyLabel,
    required this.onAdd,
    required this.onChanged,
    this.onDelete,
  });
  final List<RequestKeyValue> values;
  final bool isHeader;
  final void Function(String, String)? onHeaderPreset;
  final String emptyLabel;
  final VoidCallback onAdd;
  final void Function(String, {String? key, String? value, bool? enabled})
  onChanged;
  final ValueChanged<String>? onDelete;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (isHeader && onHeaderPreset != null)
        HeaderPresets(onSelected: onHeaderPreset!),
      for (final entry in values)
        Container(
          key: ValueKey(entry.id),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest
                .withValues(alpha: .35),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Checkbox(
                value: entry.enabled,
                onChanged: (value) =>
                    onChanged(entry.id, enabled: value ?? false),
              ),
              Expanded(
                child: TextFormField(
                  initialValue: entry.key,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Key',
                  ),
                  onChanged: (value) => onChanged(entry.id, key: value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: entry.value,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Value',
                  ),
                  onChanged: (value) => onChanged(entry.id, value: value),
                ),
              ),
              if (onDelete != null)
                IconButton(
                  key: Key('delete-key-value-${entry.id}'),
                  tooltip: 'Delete row',
                  onPressed: () => onDelete!(entry.id),
                  icon: const Icon(Icons.delete_outline, size: 19),
                ),
            ],
          ),
        ),
      if (values.isEmpty)
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Icon(
                Icons.playlist_add_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(emptyLabel),
            ],
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add row'),
        ),
      ),
    ],
  );
}
