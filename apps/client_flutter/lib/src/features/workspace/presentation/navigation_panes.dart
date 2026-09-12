import 'package:flutter/material.dart';

import '../domain/workspace_models.dart';

/// Compact section rail for the left-hand workspace. It deliberately uses
/// text labels beside small vector icons, so the rail remains scannable at a
/// glance instead of becoming a second mobile-style navigation bar.
class PrimaryNavigation extends StatelessWidget {
  const PrimaryNavigation({
    super.key,
    required this.selectedSection,
    required this.onSelected,
  });

  final WorkspaceSection selectedSection;
  final ValueChanged<WorkspaceSection> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 18, 10, 14),
    child: Column(
      children: [
        _Destination(
          icon: Icons.article_outlined,
          label: 'Запросы',
          selected: selectedSection == WorkspaceSection.collections,
          onTap: () => onSelected(WorkspaceSection.collections),
        ),
        _Destination(
          icon: Icons.language_outlined,
          label: 'Переменные',
          selected: selectedSection == WorkspaceSection.variables,
          onTap: () => onSelected(WorkspaceSection.variables),
        ),
        _Destination(
          icon: Icons.inventory_2_outlined,
          label: 'История',
          selected: selectedSection == WorkspaceSection.history,
          onTap: () => onSelected(WorkspaceSection.history),
        ),
        const _Destination(
          icon: Icons.public_outlined,
          label: 'Сниппеты',
          selected: false,
        ),
      ],
    ),
  );
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? colors.surfaceContainerHighest.withValues(alpha: .88)
                : Colors.transparent,
            border: selected
                ? Border(left: BorderSide(color: colors.primary, width: 2))
                : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? colors.primary : colors.onSurfaceVariant,
                size: 17,
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: selected ? colors.onSurface : colors.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
