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
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<SavedRequest> onOpenRequest;
  final void Function(RequestCollection, SavedRequest) onDeleteRequest;
  final VoidCallback onNewRequest;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 10, 8),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Collections',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 2),
                  Text('Requests & folders', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              key: const Key('new-workspace-button'),
              tooltip: 'New workspace',
              onPressed: onNewWorkspace,
              icon: const Icon(Icons.workspaces_outlined, size: 20),
            ),
            IconButton(
              key: const Key('new-collection-button'),
              tooltip: 'New collection',
              onPressed: selectedWorkspaceId == null ? null : onNewCollection,
              icon: const Icon(Icons.create_new_folder_outlined, size: 20),
            ),
            IconButton(
              key: const Key('import-postman-button'),
              tooltip: 'Import Postman collection',
              onPressed: selectedWorkspaceId == null ? null : onImportPostman,
              icon: const Icon(Icons.file_upload_outlined, size: 20),
            ),
            IconButton(
              key: const Key('new-request-button'),
              tooltip: 'New request',
              onPressed: onNewRequest,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
      if (workspaces.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
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
                    message: 'Workspace',
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
                  tooltip: 'Delete workspace',
                  visualDensity: VisualDensity.compact,
                  onPressed: isLoading || selectedWorkspaceId == null
                      ? null
                      : () => onDeleteWorkspace(
                          workspaces.firstWhere(
                            (workspace) => workspace.id == selectedWorkspaceId,
                          ),
                        ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 14),
      if (error case final message?)
        Padding(padding: const EdgeInsets.all(12), child: Text(message)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: TextField(
          key: const Key('collection-search-field'),
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search requests',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : workspaces.isEmpty
            ? const _NoWorkspace()
            : ListView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                children: [
                  for (final collection in collections)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: .45),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ExpansionTile(
                        shape: const RoundedRectangleBorder(),
                        collapsedShape: const RoundedRectangleBorder(),
                        tilePadding: const EdgeInsets.only(left: 10, right: 2),
                        childrenPadding: const EdgeInsets.only(bottom: 4),
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
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '${collection.requests.length}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          key: Key('delete-collection-${collection.id}'),
                          tooltip: 'Delete folder',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => onDeleteCollection(collection),
                          icon: const Icon(Icons.delete_outline, size: 18),
                        ),
                        children: [
                          for (final request in collection.requests)
                            ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
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
                                tooltip: 'Delete request',
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
            'Create your first workspace',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Keep requests, folders and variables together.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
