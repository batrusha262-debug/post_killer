import 'dart:io';

import 'package:file_selector/file_selector.dart';

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
    final motionDuration = settings.reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: Platform.isMacOS ? 90 : 20,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                settings.appearance == AppAppearance.slay
                    ? Icons.auto_awesome
                    : Icons.bolt_rounded,
                color: colors.onPrimary,
                size: 19,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Post Killer'),
            AnimatedSwitcher(
              duration: motionDuration,
              child: workspace.isExecuting
                  ? Container(
                      key: const Key('request-live-indicator'),
                      margin: const EdgeInsets.only(left: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('Live', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
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
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: constraints.maxWidth < 1000 ? 1000 : constraints.maxWidth,
            height: constraints.maxHeight,
            child: Row(
              children: [
                PrimaryNavigation(
                  selectedSection: workspace.selectedSection,
                  onSelected: (section) =>
                      controller.add(WorkspaceSectionSelected(section)),
                ),
                SizedBox(
                  width: 260,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border(
                        left: BorderSide(color: colors.outlineVariant),
                        right: BorderSide(color: colors.outlineVariant),
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: motionDuration,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (currentChild, previousChildren) =>
                          currentChild ?? const SizedBox.shrink(),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.025, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(workspace.selectedSection),
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
                              onSubmit: (name) => controller.add(
                                WorkspaceCreateRequested(name),
                              ),
                            ),
                            onDeleteWorkspace: (workspace) async {
                              if (await _confirmDelete(
                                context,
                                title: 'Удалить workspace?',
                                message: 'Будут удалены все его папки, запросы и переменные. Это действие нельзя отменить.',
                                confirmLabel: 'Удалить workspace',
                              )) {
                                controller.add(
                                  WorkspaceDeleteRequested(workspace.id),
                                );
                              }
                            },
                            onNewCollection: () => _showNameDialog(
                              context,
                              title: 'Новая collection',
                              onSubmit: (name) => controller.add(
                                CollectionCreateRequested(name),
                              ),
                            ),
                            onDeleteCollection: (collection) async {
                              if (await _confirmDelete(
                                context,
                                title: 'Удалить папку «${collection.name}»?',
                                message: 'Все запросы в этой папке будут удалены. Это действие нельзя отменить.',
                                confirmLabel: 'Удалить папку',
                              )) {
                                controller.add(
                                  CollectionDeleteRequested(collection.id),
                                );
                              }
                            },
                            onImportPostman: () =>
                                _importPostmanCollection(context, controller),
                            onSearchChanged: (query) => controller.add(
                              WorkspaceCollectionSearchChanged(query),
                            ),
                            onOpenRequest: (request) =>
                                controller.add(WorkspaceRequestOpened(request)),
                            onDeleteRequest: (collection, request) async {
                              if (await _confirmDelete(
                                context,
                                title: 'Удалить запрос «${request.name}»?',
                                message: 'История этого запроса также будет удалена.',
                                confirmLabel: 'Удалить запрос',
                              )) {
                                controller.add(
                                  WorkspaceSavedRequestDeleteRequested(
                                    collectionId: collection.id,
                                    requestId: request.id,
                                  ),
                                );
                              }
                            },
                            onNewRequest: () =>
                                controller.add(const WorkspaceRequestCreated()),
                          ),
                          WorkspaceSection.history => HistoryPane(
                            entries: workspace.history,
                          ),
                          WorkspaceSection.variables => const VariablesPane(),
                        },
                      ),
                    ),
                  ),
                ),
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
                    onAuthChanged: (auth) =>
                        controller.add(WorkspaceAuthChanged(auth)),
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
                    onCancel: () =>
                        controller.add(const WorkspaceRequestCancelled()),
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

  static Future<void> _importPostmanCollection(
    BuildContext context,
    WorkspaceBloc workspace,
  ) async {
    const typeGroup = XTypeGroup(
      label: 'Postman collection',
      extensions: ['json'],
      mimeTypes: ['application/json'],
    );
    try {
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null || !context.mounted) return;
      workspace.add(WorkspacePostmanImportRequested(await file.readAsString()));
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть файл коллекции.')),
      );
    }
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

  static Future<bool> _confirmDelete(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}
