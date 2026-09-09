import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
      ),
      body: Row(
        children: [
          _PrimaryNavigation(
            selectedSection: workspace.selectedSection,
            onSelected: (section) =>
                controller.add(WorkspaceSectionSelected(section)),
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 260,
            child: switch (workspace.selectedSection) {
              WorkspaceSection.collections => _CollectionsPane(
                collections: workspace.filteredCollections,
                onSearchChanged: (query) =>
                    controller.add(WorkspaceCollectionSearchChanged(query)),
                onOpenRequest: (request) =>
                    controller.add(WorkspaceRequestOpened(request)),
                onNewRequest: () =>
                    controller.add(const WorkspaceRequestCreated()),
              ),
              WorkspaceSection.history => const _HistoryPane(),
              WorkspaceSection.variables => const _VariablesPane(),
            },
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _RequestWorkspace(
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
}

class _PrimaryNavigation extends StatelessWidget {
  const _PrimaryNavigation({
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

class _CollectionsPane extends StatelessWidget {
  const _CollectionsPane({
    required this.collections,
    required this.onSearchChanged,
    required this.onOpenRequest,
    required this.onNewRequest,
  });

  final List<RequestCollection> collections;
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
              key: const Key('new-request-button'),
              tooltip: 'New request',
              onPressed: onNewRequest,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
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
        child: ListView(
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
                            color: _methodColor(context, request.method),
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

class _HistoryPane extends StatelessWidget {
  const _HistoryPane();

  @override
  Widget build(BuildContext context) => const _SectionPlaceholder(
    title: 'History',
    icon: Icons.history,
    message: 'No request history yet',
  );
}

class _VariablesPane extends StatelessWidget {
  const _VariablesPane();

  @override
  Widget build(BuildContext context) => const _SectionPlaceholder(
    title: 'Variables',
    icon: Icons.tune,
    message: 'No variables yet',
  );
}

class _SectionPlaceholder extends StatelessWidget {
  const _SectionPlaceholder({
    required this.title,
    required this.icon,
    required this.message,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(icon), const SizedBox(height: 8), Text(message)],
          ),
        ),
      ),
    ],
  );
}

class _RequestWorkspace extends StatelessWidget {
  const _RequestWorkspace({
    required this.workspace,
    required this.onSelectTab,
    required this.onCloseTab,
    required this.onNewTab,
    required this.onMethodChanged,
    required this.onUrlChanged,
    required this.onBodyChanged,
    required this.onAddQuery,
    required this.onAddHeader,
    required this.onQueryChanged,
    required this.onHeaderChanged,
    required this.onSend,
  });

  final WorkspaceState workspace;
  final ValueChanged<String> onSelectTab;
  final ValueChanged<String> onCloseTab;
  final VoidCallback onNewTab;
  final ValueChanged<HttpMethod> onMethodChanged;
  final ValueChanged<String> onUrlChanged;
  final ValueChanged<String> onBodyChanged;
  final VoidCallback onAddQuery;
  final VoidCallback onAddHeader;
  final void Function(String, {String? key, String? value, bool? enabled})
  onQueryChanged;
  final void Function(String, {String? key, String? value, bool? enabled})
  onHeaderChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 46,
        child: Row(
          children: [
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: workspace.tabs.length,
                itemBuilder: (context, index) {
                  final tab = workspace.tabs[index];
                  return _RequestTabButton(
                    tab: tab,
                    selected: tab.id == workspace.selectedTabId,
                    onTap: () => onSelectTab(tab.id),
                    onClose: () => onCloseTab(tab.id),
                  );
                },
              ),
            ),
            IconButton(
              tooltip: 'New tab',
              onPressed: onNewTab,
              icon: const Icon(Icons.add, size: 20),
            ),
          ],
        ),
      ),
      const Divider(height: 1),
      Expanded(
        child: workspace.selectedTab == null
            ? const _EmptyWorkspace()
            : _RequestEditor(
                key: ValueKey(workspace.selectedTab!.id),
                tab: workspace.selectedTab!,
                onMethodChanged: onMethodChanged,
                onUrlChanged: onUrlChanged,
                onBodyChanged: onBodyChanged,
                onAddQuery: onAddQuery,
                onAddHeader: onAddHeader,
                onQueryChanged: onQueryChanged,
                onHeaderChanged: onHeaderChanged,
                onSend: onSend,
                isExecuting: workspace.isExecuting,
                execution: workspace.execution,
              ),
      ),
    ],
  );
}

class _RequestTabButton extends StatelessWidget {
  const _RequestTabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  final RequestTab tab;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Colors.transparent,
    child: InkWell(
      key: Key('request-tab-${tab.id}'),
      onTap: onTap,
      child: Container(
        width: 176,
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 2,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
            ),
            right: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              tab.method.label,
              style: TextStyle(
                color: _methodColor(context, tab.method),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${tab.title}${tab.isDirty ? ' •' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              key: Key('close-tab-${tab.id}'),
              tooltip: 'Close ${tab.title}',
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 16),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RequestEditor extends StatelessWidget {
  const _RequestEditor({
    super.key,
    required this.tab,
    required this.onMethodChanged,
    required this.onUrlChanged,
    required this.onBodyChanged,
    required this.onAddQuery,
    required this.onAddHeader,
    required this.onQueryChanged,
    required this.onHeaderChanged,
    required this.onSend,
    required this.isExecuting,
    required this.execution,
  });

  final RequestTab tab;
  final ValueChanged<HttpMethod> onMethodChanged;
  final ValueChanged<String> onUrlChanged;
  final ValueChanged<String> onBodyChanged;
  final VoidCallback onAddQuery;
  final VoidCallback onAddHeader;
  final void Function(String, {String? key, String? value, bool? enabled})
  onQueryChanged;
  final void Function(String, {String? key, String? value, bool? enabled})
  onHeaderChanged;
  final VoidCallback onSend;
  final bool isExecuting;
  final RequestExecutionView? execution;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<HttpMethod>(
                key: const Key('method-picker'),
                initialValue: tab.method,
                decoration: const InputDecoration(isDense: true),
                items: [
                  for (final method in HttpMethod.values)
                    DropdownMenuItem(value: method, child: Text(method.label)),
                ],
                onChanged: (method) {
                  if (method != null) onMethodChanged(method);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                key: const Key('request-url-field'),
                initialValue: tab.url,
                onChanged: onUrlChanged,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'https://api.example.com/resource',
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: isExecuting ? null : onSend,
              icon: const Icon(Icons.send, size: 17),
              label: Text(isExecuting ? 'Sending…' : 'Send'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: DefaultTabController(
            length: 4,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Query'),
                    Tab(text: 'Headers'),
                    Tab(text: 'Body'),
                    Tab(text: 'Response'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _KeyValueEditor(
                        values: tab.query,
                        emptyLabel: 'No query parameters',
                        onAdd: onAddQuery,
                        onChanged: onQueryChanged,
                      ),
                      _KeyValueEditor(
                        values: tab.headers,
                        emptyLabel: 'No headers',
                        onAdd: onAddHeader,
                        onChanged: onHeaderChanged,
                      ),
                      _BodyEditor(value: tab.body, onChanged: onBodyChanged),
                      _ResponseView(execution: execution),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _KeyValueEditor extends StatelessWidget {
  const _KeyValueEditor({
    required this.values,
    required this.emptyLabel,
    required this.onAdd,
    required this.onChanged,
  });
  final List<RequestKeyValue> values;
  final String emptyLabel;
  final VoidCallback onAdd;
  final void Function(String, {String? key, String? value, bool? enabled})
  onChanged;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      for (final entry in values)
        Row(
          children: [
            Checkbox(
              value: entry.enabled,
              onChanged: (value) =>
                  onChanged(entry.id, enabled: value ?? false),
            ),
            Expanded(
              child: TextFormField(
                initialValue: entry.key,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Key',
                ),
                onChanged: (value) => onChanged(entry.id, key: value),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: entry.value,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Value',
                ),
                onChanged: (value) => onChanged(entry.id, value: value),
              ),
            ),
          ],
        ),
      if (values.isEmpty)
        Padding(padding: const EdgeInsets.all(16), child: Text(emptyLabel)),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add row'),
        ),
      ),
    ],
  );
}

class _BodyEditor extends StatelessWidget {
  const _BodyEditor({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: TextFormField(
      initialValue: value,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      decoration: const InputDecoration(hintText: 'Request body'),
      onChanged: onChanged,
    ),
  );
}

class _ResponseView extends StatelessWidget {
  const _ResponseView({required this.execution});
  final RequestExecutionView? execution;

  @override
  Widget build(BuildContext context) {
    final result = execution;
    if (result?.error case final error?) {
      return Center(child: Text(error, key: const Key('response-error')));
    }
    if (result?.status case final status?) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          'HTTP $status · ${result!.durationMillis} ms\n\n${result.body}',
          key: const Key('response-content'),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.data_object, size: 36),
          SizedBox(height: 8),
          Text('Response will appear here'),
          SizedBox(height: 4),
          Text('Send a request to inspect status, headers and body'),
        ],
      ),
    );
  }
}

class _EmptyWorkspace extends StatelessWidget {
  const _EmptyWorkspace();

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Open a saved request or create a new tab'));
}

Color _methodColor(BuildContext context, HttpMethod method) => switch (method) {
  HttpMethod.get => Colors.green.shade700,
  HttpMethod.post => Colors.orange.shade800,
  HttpMethod.put => Colors.blue.shade700,
  HttpMethod.patch => Colors.purple.shade600,
  HttpMethod.delete => Theme.of(context).colorScheme.error,
};
