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
    required this.onNewCollection,
    required this.onImportPostman,
    required this.onSearchChanged,
    required this.onOpenRequest,
    required this.onNewRequest,
  });

  final List<WorkspaceSummary> workspaces;
  final String? selectedWorkspaceId;
  final List<RequestCollection> collections;
  final bool isLoading;
  final String? error;
  final ValueChanged<String> onWorkspaceSelected;
  final VoidCallback onNewWorkspace;
  final VoidCallback onNewCollection;
  final VoidCallback onImportPostman;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<SavedRequest> onOpenRequest;
  final VoidCallback onNewRequest;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
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
          child: DropdownButtonFormField<String>(
            initialValue: selectedWorkspaceId,
            decoration: const InputDecoration(
              labelText: 'Workspace',
              isDense: true,
            ),
            items: [
              for (final workspace in workspaces)
                DropdownMenuItem(
                  value: workspace.id,
                  child: Text(workspace.name),
                ),
            ],
            onChanged: isLoading
                ? null
                : (id) {
                    if (id != null) onWorkspaceSelected(id);
                  },
          ),
        ),
      const SizedBox(height: 12),
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
      const SizedBox(height: 8),
      Expanded(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : workspaces.isEmpty
            ? const Center(child: Text('Создайте первую workspace'))
            : ListView(
                children: [
                  for (final collection in collections)
                    ExpansionTile(
                      initiallyExpanded: true,
                      leading: const Icon(Icons.folder_outlined, size: 20),
                      title: Text(collection.name),
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
                          ),
                      ],
                    ),
                ],
              ),
      ),
    ],
  );
}
