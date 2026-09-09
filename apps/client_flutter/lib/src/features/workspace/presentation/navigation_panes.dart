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
    selectedIndex: selectedSection.index,
    onDestinationSelected: (index) =>
        onSelected(WorkspaceSection.values[index]),
    labelType: NavigationRailLabelType.all,
    destinations: const [
      NavigationRailDestination(
        icon: Icon(Icons.folder_outlined),
        selectedIcon: Icon(Icons.folder),
        label: Text('Collections'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.history),
        label: Text('History'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.tune),
        label: Text('Variables'),
      ),
    ],
  );
}
