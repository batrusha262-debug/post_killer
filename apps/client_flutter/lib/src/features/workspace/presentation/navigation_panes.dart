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
  Widget build(BuildContext context) => NavigationRail(
    minWidth: 64,
    minExtendedWidth: 64,
    groupAlignment: -0.86,
    selectedIndex: selectedSection.index,
    onDestinationSelected: (index) =>
        onSelected(WorkspaceSection.values[index]),
    labelType: NavigationRailLabelType.all,
    leading: Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Tooltip(
        message: 'Ваше API-пространство',
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.hub_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
      ),
    ),
    destinations: const [
      NavigationRailDestination(
        icon: Icon(Icons.folder_outlined),
        selectedIcon: Icon(Icons.folder_rounded),
        label: Text('Collections'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.history_outlined),
        selectedIcon: Icon(Icons.history_rounded),
        label: Text('History'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.tune_outlined),
        selectedIcon: Icon(Icons.tune_rounded),
        label: Text('Variables'),
      ),
    ],
  );
}
