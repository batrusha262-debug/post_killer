import 'method_color.dart';

import 'package:flutter/material.dart';

import '../domain/workspace_models.dart';

class RequestTabButton extends StatelessWidget {
  const RequestTabButton({
    super.key,
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  final RequestTab tab;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .55)
        : Colors.transparent,
    child: InkWell(
      key: Key('request-tab-${tab.id}'),
      onTap: onTap,
      child: Container(
        width: 190,
        padding: const EdgeInsets.only(left: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 3,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
            ),
            right: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              tab.method.label,
              style: TextStyle(
                color: methodColor(context, tab.method),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${tab.title}${tab.isDirty ? ' •' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              key: Key('close-tab-${tab.id}'),
              tooltip: 'Close ${tab.title}',
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 16),
            ),
          ],
        ),
      ),
    ),
  );
}
