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
    padding: EdgeInsets.zero,
    children: [
      if (isHeader && onHeaderPreset != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: HeaderPresets(onSelected: onHeaderPreset!),
        ),
      const _TableHeader(),
      for (final entry in values)
        Container(
          key: ValueKey(entry.id),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
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
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
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
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
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
          padding: const EdgeInsets.all(18),
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
        child: TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add row'),
        ),
      ),
    ],
  );
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      border: Border(
        top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: const Row(
      children: [
        SizedBox(width: 32),
        Expanded(child: Text('KEY', style: _TableHeader.style)),
        Expanded(child: Text('VALUE', style: _TableHeader.style)),
        SizedBox(width: 44),
      ],
    ),
  );

  static const style = TextStyle(fontSize: 10, fontWeight: FontWeight.w800);
}
