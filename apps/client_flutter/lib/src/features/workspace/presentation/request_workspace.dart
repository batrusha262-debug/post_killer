import 'request_tab_button.dart';
import 'request_editor.dart';
import 'empty_workspace.dart';

import 'package:flutter/material.dart';

import '../domain/workspace_models.dart';

class RequestWorkspace extends StatelessWidget {
  const RequestWorkspace({
    super.key,
    required this.workspace,
    required this.onSelectTab,
    required this.onCloseTab,
    required this.onNewTab,
    required this.onMethodChanged,
    required this.onTitleChanged,
    required this.onUrlChanged,
    required this.onBodyChanged,
    required this.onBodyFormatChanged,
    required this.onAuthChanged,
    required this.onAddQuery,
    required this.onAddHeader,
    required this.onHeaderPreset,
    required this.onQueryChanged,
    required this.onHeaderChanged,
    required this.onDeleteHeader,
    required this.onSave,
    required this.onSend,
    required this.onCancel,
  });

  final WorkspaceState workspace;
  final ValueChanged<String> onSelectTab;
  final ValueChanged<String> onCloseTab;
  final VoidCallback onNewTab;
  final ValueChanged<HttpMethod> onMethodChanged;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onUrlChanged;
  final ValueChanged<String> onBodyChanged;
  final ValueChanged<RequestBodyFormat> onBodyFormatChanged;
  final ValueChanged<RequestAuth> onAuthChanged;
  final VoidCallback onAddQuery;
  final VoidCallback onAddHeader;
  final void Function(String, String) onHeaderPreset;
  final void Function(String, {String? key, String? value, bool? enabled})
  onQueryChanged;
  final void Function(String, {String? key, String? value, bool? enabled})
  onHeaderChanged;
  final ValueChanged<String> onDeleteHeader;
  final ValueChanged<String> onSave;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(8),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      children: [
        SizedBox(
          height: 40,
          child: Row(
            children: [
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: workspace.tabs.length,
                  itemBuilder: (context, index) {
                    final tab = workspace.tabs[index];
                    return RequestTabButton(
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
              ? const EmptyWorkspace()
              : RequestEditor(
                  key: ValueKey(workspace.selectedTab!.id),
                  tab: workspace.selectedTab!,
                  onMethodChanged: onMethodChanged,
                  onTitleChanged: onTitleChanged,
                  onUrlChanged: onUrlChanged,
                  onBodyChanged: onBodyChanged,
                  onBodyFormatChanged: onBodyFormatChanged,
                  onAuthChanged: onAuthChanged,
                  onAddQuery: onAddQuery,
                  onAddHeader: onAddHeader,
                  onHeaderPreset: onHeaderPreset,
                  onQueryChanged: onQueryChanged,
                  onHeaderChanged: onHeaderChanged,
                  onDeleteHeader: onDeleteHeader,
                  collections: workspace.collections,
                  loginEndpoints: [
                    for (final collection in workspace.collections)
                      ...collection.requests,
                  ],
                  onSave: onSave,
                  onSend: onSend,
                  onCancel: onCancel,
                  isExecuting: workspace.isExecuting,
                  execution: workspace.selectedExecution,
                ),
        ),
      ],
    ),
  );
}
