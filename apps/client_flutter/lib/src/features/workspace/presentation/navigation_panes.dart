import 'package:flutter/material.dart';

import '../domain/workspace_models.dart';

class PrimaryNavigation extends StatelessWidget {
  const PrimaryNavigation({
    super.key,
    required this.selectedSection,
    required this.onSelected,
  });

  final WorkspaceSection selectedSection;
  final ValueChanged<WorkspaceSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 14),
            child: Tooltip(
              message: 'Ваше API-пространство',
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.outline),
                ),
                child: Icon(Icons.bolt_rounded, color: colors.primary),
              ),
            ),
          ),
          _Destination(
            icon: Icons.folder_outlined,
            selectedIcon: Icons.folder_rounded,
            label: 'Запросы',
            selected: selectedSection == WorkspaceSection.collections,
            onTap: () => onSelected(WorkspaceSection.collections),
          ),
          _Destination(
            icon: Icons.history_outlined,
            selectedIcon: Icons.history_rounded,
            label: 'История',
            selected: selectedSection == WorkspaceSection.history,
            onTap: () => onSelected(WorkspaceSection.history),
          ),
          _Destination(
            icon: Icons.tune_outlined,
            selectedIcon: Icons.tune_rounded,
            label: 'Переменные',
            selected: selectedSection == WorkspaceSection.variables,
            onTap: () => onSelected(WorkspaceSection.variables),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Tooltip(
              message: 'Все данные хранятся локально',
              child: Icon(
                Icons.shield_outlined,
                color: colors.onSurfaceVariant,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(5),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? colors.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: selected
                  ? Border(left: BorderSide(color: colors.primary, width: 2))
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                    fontSize: 9,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
