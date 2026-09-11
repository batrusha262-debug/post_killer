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
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Collections',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              key: const Key('new-workspace-button'),
              tooltip: 'New workspace',
              onPressed: onNewWorkspace,
              icon: const Icon(Icons.workspaces_outline),
            ),
            IconButton(
              key: const Key('new-collection-button'),
              tooltip: 'New collection',
              onPressed: selectedWorkspaceId == null ? null : onNewCollection,
              icon: const Icon(Icons.create_new_folder_outlined),
            ),
            IconButton(
              key: const Key('import-postman-button'),
              tooltip: 'Import Postman collection',
              onPressed: selectedWorkspaceId == null ? null : onImportPostman,
              icon: const Icon(Icons.upload_file_outlined),
            ),
            IconButton(
              key: const Key('new-request-button'),
              tooltip: 'New request',
              onPressed: onNewRequest,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
      if (workspaces.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
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
                icon: const Icon(Icons.delete_outline, size: 19),
              ),
            ],
          ),
        ),
      const SizedBox(height: 8),
      if (error case final message?)
        Padding(padding: const EdgeInsets.all(12), child: Text(message)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          key: const Key('collection-search-field'),
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search',
            prefixIcon: Icon(Icons.search, size: 20),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Expanded(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : workspaces.isEmpty
            ? const Center(child: Text('Создайте первую workspace'))
            : ListView(
                children: [
                  for (final collection in collections)
                    ExpansionTile(
                      tilePadding: const EdgeInsets.only(left: 12, right: 4),
                      childrenPadding: const EdgeInsets.only(bottom: 2),
                      dense: true,
                      initiallyExpanded: true,
                      leading: const Icon(Icons.folder_outlined, size: 20),
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
                ],
              ),
      ),
    ],
  );
}
