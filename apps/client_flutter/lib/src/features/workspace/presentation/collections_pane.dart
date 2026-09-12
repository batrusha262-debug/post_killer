import 'method_color.dart';

import 'package:flutter/material.dart';

import '../domain/workspace_models.dart';

class CollectionsPane extends StatelessWidget {
  const CollectionsPane({
    super.key,
    required this.workspaces,
    required this.selectedWorkspaceId,
    required this.collections,
    required this.isLoading,
    required this.error,
    required this.onWorkspaceSelected,
    required this.onNewWorkspace,
    required this.onDeleteWorkspace,
    required this.onNewCollection,
    required this.onDeleteCollection,
    required this.onImportPostman,
    required this.onImportOpenApi,
    required this.onExportCollection,
    required this.onSearchChanged,
    required this.onOpenRequest,
    required this.onDeleteRequest,
    required this.onNewRequest,
  });

  final List<WorkspaceSummary> workspaces;
  final String? selectedWorkspaceId;
  final List<RequestCollection> collections;
  final bool isLoading;
  final String? error;
  final ValueChanged<String> onWorkspaceSelected;
  final VoidCallback onNewWorkspace;
  final ValueChanged<WorkspaceSummary> onDeleteWorkspace;
  final VoidCallback onNewCollection;
  final ValueChanged<RequestCollection> onDeleteCollection;
  final VoidCallback onImportPostman;
  final VoidCallback onImportOpenApi;
  final ValueChanged<RequestCollection> onExportCollection;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<SavedRequest> onOpenRequest;
  final void Function(RequestCollection, SavedRequest) onDeleteRequest;
  final VoidCallback onNewRequest;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 35, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COLLECTIONS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .4,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('new-workspace-button'),
                  tooltip: 'Создать рабочее пространство',
                  onPressed: onNewWorkspace,
                  icon: const Icon(Icons.workspaces_outlined, size: 20),
                ),
                PopupMenuButton<void>(
                  tooltip: 'Импортировать API',
                  icon: const Icon(Icons.file_upload_outlined, size: 20),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      enabled: selectedWorkspaceId != null,
                      onTap: onImportPostman,
                      child: const Text('Коллекцию Postman'),
                    ),
                    PopupMenuItem(
                      enabled: selectedWorkspaceId != null,
                      onTap: onImportOpenApi,
                      child: const Text('Спецификацию OpenAPI'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('new-request-button'),
                    onPressed: onNewRequest,
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: const Text('Новый запрос'),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Новая коллекция',
                  child: OutlinedButton(
                    key: const Key('new-collection-button'),
                    onPressed: selectedWorkspaceId == null
                        ? null
                        : onNewCollection,
                    child: const Icon(
                      Icons.create_new_folder_outlined,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      if (workspaces.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            height: 72,
            child: Container(
              padding: const EdgeInsets.only(left: 10, right: 3),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.layers_outlined,
                    size: 17,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Tooltip(
                      message: 'Рабочее пространство',
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedWorkspaceId,
                          items: [
                            for (final workspace in workspaces)
                              DropdownMenuItem(
                                value: workspace.id,
                                child: Text(
                                  workspace.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                          onChanged: isLoading
                              ? null
                              : (id) {
                                  if (id != null) onWorkspaceSelected(id);
                                },
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('delete-workspace-button'),
                    tooltip: 'Удалить рабочее пространство',
                    visualDensity: VisualDensity.compact,
                    onPressed: isLoading || selectedWorkspaceId == null
                        ? null
                        : () => onDeleteWorkspace(
                            workspaces.firstWhere(
                              (workspace) =>
                                  workspace.id == selectedWorkspaceId,
                            ),
                          ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      const SizedBox(height: 8),
      if (error case final message?)
        Padding(padding: const EdgeInsets.all(12), child: Text(message)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          height: 74,
          child: TextField(
            key: const Key('collection-search-field'),
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Поиск в коллекциях…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Expanded(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : workspaces.isEmpty
            ? const _NoWorkspace()
            : ListView(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                children: [
                  for (final collection in collections)
                    Container(
                      margin: EdgeInsets.zero,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      child: ExpansionTile(
                        shape: const RoundedRectangleBorder(),
                        collapsedShape: const RoundedRectangleBorder(),
                        tilePadding: const EdgeInsets.only(left: 8, right: 0),
                        childrenPadding: EdgeInsets.zero,
                        dense: true,
                        initiallyExpanded: true,
                        leading: const Icon(Icons.folder_outlined, size: 19),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                collection.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${collection.requests.length}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: Key('export-collection-${collection.id}'),
                              tooltip: 'Экспортировать коллекцию',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => onExportCollection(collection),
                              icon: const Icon(
                                Icons.file_download_outlined,
                                size: 18,
                              ),
                            ),
                            IconButton(
                              key: Key('delete-collection-${collection.id}'),
                              tooltip: 'Удалить коллекцию',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => onDeleteCollection(collection),
                              icon: const Icon(Icons.delete_outline, size: 18),
                            ),
                          ],
                        ),
                        children: [
                          for (final request in collection.requests)
                            ListTile(
                              dense: true,
                              key: Key('saved-request-${request.id}'),
                              leading: SizedBox(
                                width: 38,
                                child: Text(
                                  request.method.label,
                                  style: TextStyle(
                                    color: methodColor(context, request.method),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              title: Text(request.name),
                              onTap: () => onOpenRequest(request),
                              trailing: IconButton(
                                key: Key('delete-request-${request.id}'),
                                tooltip: 'Удалить запрос',
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    onDeleteRequest(collection, request),
                                icon: const Icon(Icons.close_rounded, size: 17),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    ],
  );
}

class _NoWorkspace extends StatelessWidget {
  const _NoWorkspace();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.space_dashboard_outlined,
            size: 34,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Создайте первое рабочее пространство',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Храните запросы, коллекции и переменные в одном месте.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
