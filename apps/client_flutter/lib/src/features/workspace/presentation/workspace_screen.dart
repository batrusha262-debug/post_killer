import 'dart:io';

import '../../../settings/app_settings.dart';
import '../../../settings/settings_dialog.dart';
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
    final colors = Theme.of(context).colorScheme;
    final settings = SettingsScope.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: Platform.isMacOS ? 90 : 20,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.tertiary],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                settings.appearance == AppAppearance.slay
                    ? Icons.auto_awesome
                    : Icons.bolt_rounded,
                color: colors.onPrimary,
                size: 22,
              ),
            ),
            SizedBox(width: 8),
            const Text('Post Killer'),
          ],
        ),
        actions: [
          const UpdateAction(),
          IconButton(
            key: const Key('settings-button'),
            tooltip: 'Настройки',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => SettingsDialog(settings: settings),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: constraints.maxWidth < 1100 ? 1100 : constraints.maxWidth,
            height: constraints.maxHeight,
            child: Row(
              children: [
                PrimaryNavigation(
                  selectedSection: workspace.selectedSection,
                  onSelected: (section) =>
                      controller.add(WorkspaceSectionSelected(section)),
                ),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 240,
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
                      onSearchChanged: (query) => controller.add(
                        WorkspaceCollectionSearchChanged(query),
                      ),
                      onOpenRequest: (request) =>
                          controller.add(WorkspaceRequestOpened(request)),
                      onNewRequest: () =>
                          controller.add(const WorkspaceRequestCreated()),
                    ),
                    WorkspaceSection.history => HistoryPane(
                      entries: workspace.history,
                    ),
                    WorkspaceSection.variables => const VariablesPane(),
                  },
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: RequestWorkspace(
                    workspace: workspace,
                    onSelectTab: (id) =>
                        controller.add(WorkspaceTabSelected(id)),
                    onCloseTab: (id) => controller.add(WorkspaceTabClosed(id)),
                    onNewTab: () =>
                        controller.add(const WorkspaceRequestCreated()),
                    onMethodChanged: (method) =>
                        controller.add(WorkspaceMethodChanged(method)),
                    onTitleChanged: (title) =>
                        controller.add(WorkspaceRequestTitleChanged(title)),
                    onUrlChanged: (url) =>
                        controller.add(WorkspaceUrlChanged(url)),
                    onBodyChanged: (body) =>
                        controller.add(WorkspaceBodyChanged(body)),
                    onBodyFormatChanged: (format) =>
                        controller.add(WorkspaceBodyFormatChanged(format)),
                    onAddQuery: () => controller.add(
                      const WorkspaceKeyValueAdded(isHeader: false),
                    ),
                    onAddHeader: () => controller.add(
                      const WorkspaceKeyValueAdded(isHeader: true),
                    ),
                    onQueryChanged: (id, {key, value, enabled}) =>
                        controller.add(
                          WorkspaceKeyValueChanged(
                            id: id,
                            isHeader: false,
                            key: key,
                            value: value,
                            enabled: enabled,
                          ),
                        ),
                    onHeaderChanged: (id, {key, value, enabled}) =>
                        controller.add(
                          WorkspaceKeyValueChanged(
                            id: id,
                            isHeader: true,
                            key: key,
                            value: value,
                            enabled: enabled,
                          ),
                        ),
                    onDeleteHeader: (id) => controller.add(
                      WorkspaceKeyValueDeleted(id: id, isHeader: true),
                    ),
                    onHeaderPreset: (name, value) =>
                        controller.add(WorkspaceHeaderPresetAdded(name, value)),
                    onSend: () => controller.add(const WorkspaceRequestSent()),
                    onSave: (collectionId) => controller.add(
                      WorkspaceRequestSaveRequested(collectionId),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
