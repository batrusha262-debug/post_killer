import 'navigation_panes.dart';
import 'collections_pane.dart';
import 'section_placeholder.dart';
import 'request_workspace.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../updates/presentation/update_action.dart';
import '../application/workspace_bloc.dart';
import '../domain/workspace_models.dart';

class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceBloc>().state;
    final controller = context.read<WorkspaceBloc>();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded),
            SizedBox(width: 8),
            Text('Post Killer'),
          ],
        ),
        actions: const [UpdateAction(), SizedBox(width: 8)],
      ),
      body: Row(
        children: [
          PrimaryNavigation(
            selectedSection: workspace.selectedSection,
            onSelected: (section) =>
                controller.add(WorkspaceSectionSelected(section)),
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 260,
            child: switch (workspace.selectedSection) {
              WorkspaceSection.collections => CollectionsPane(
                workspaces: workspace.workspaces,
                selectedWorkspaceId: workspace.selectedWorkspaceId,
                collections: workspace.filteredCollections,
                isLoading: workspace.isLoading,
                error: workspace.storageError,
                onWorkspaceSelected: (id) =>
                    controller.add(WorkspaceSelected(id)),
                onNewWorkspace: () => _showNameDialog(
                  context,
                  title: 'Новая workspace',
                  onSubmit: (name) =>
                      controller.add(WorkspaceCreateRequested(name)),
                ),
                onNewCollection: () => _showNameDialog(
                  context,
                  title: 'Новая collection',
                  onSubmit: (name) =>
                      controller.add(CollectionCreateRequested(name)),
                ),
                onSearchChanged: (query) =>
                    controller.add(WorkspaceCollectionSearchChanged(query)),
                onOpenRequest: (request) =>
                    controller.add(WorkspaceRequestOpened(request)),
                onNewRequest: () =>
                    controller.add(const WorkspaceRequestCreated()),
              ),
              WorkspaceSection.history => const HistoryPane(),
              WorkspaceSection.variables => const VariablesPane(),
            },
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: RequestWorkspace(
              workspace: workspace,
              onSelectTab: (id) => controller.add(WorkspaceTabSelected(id)),
              onCloseTab: (id) => controller.add(WorkspaceTabClosed(id)),
              onNewTab: () => controller.add(const WorkspaceRequestCreated()),
              onMethodChanged: (method) =>
                  controller.add(WorkspaceMethodChanged(method)),
              onUrlChanged: (url) => controller.add(WorkspaceUrlChanged(url)),
              onBodyChanged: (body) =>
                  controller.add(WorkspaceBodyChanged(body)),
              onAddQuery: () =>
                  controller.add(const WorkspaceKeyValueAdded(isHeader: false)),
              onAddHeader: () =>
                  controller.add(const WorkspaceKeyValueAdded(isHeader: true)),
              onQueryChanged: (id, {key, value, enabled}) => controller.add(
                WorkspaceKeyValueChanged(
                  id: id,
                  isHeader: false,
                  key: key,
                  value: value,
                  enabled: enabled,
                ),
              ),
              onHeaderChanged: (id, {key, value, enabled}) => controller.add(
                WorkspaceKeyValueChanged(
                  id: id,
                  isHeader: true,
                  key: key,
                  value: value,
                  enabled: enabled,
                ),
              ),
              onSend: () => controller.add(const WorkspaceRequestSent()),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _showNameDialog(
    BuildContext context, {
    required String title,
    required ValueChanged<String> onSubmit,
  }) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          autofocus: true,
          controller: controller,
          decoration: const InputDecoration(labelText: 'Название'),
          onSubmitted: (value) {
            if (value.trim().isEmpty) return;
            Navigator.of(dialogContext).pop();
            onSubmit(value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.of(dialogContext).pop();
              onSubmit(controller.text);
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}
