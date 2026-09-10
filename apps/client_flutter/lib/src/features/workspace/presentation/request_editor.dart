import 'key_value_editor.dart';
import 'json_body_editor.dart';
import 'text_body_editor.dart';
import 'response_view.dart';

import 'package:flutter/material.dart';

import '../domain/workspace_models.dart';

class RequestEditor extends StatelessWidget {
  const RequestEditor({
    super.key,
    required this.tab,
    required this.onMethodChanged,
    required this.onTitleChanged,
    required this.onUrlChanged,
    required this.onBodyChanged,
    required this.onBodyFormatChanged,
    required this.onAddQuery,
    required this.onAddHeader,
    required this.onHeaderPreset,
    required this.onQueryChanged,
    required this.onHeaderChanged,
    required this.onDeleteHeader,
    required this.collections,
    required this.onSave,
    required this.onSend,
    required this.isExecuting,
    required this.execution,
  });

  final RequestTab tab;
  final ValueChanged<HttpMethod> onMethodChanged;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onUrlChanged;
  final ValueChanged<String> onBodyChanged;
  final ValueChanged<RequestBodyFormat> onBodyFormatChanged;
  final VoidCallback onAddQuery;
  final VoidCallback onAddHeader;
  final void Function(String, String) onHeaderPreset;
  final void Function(String, {String? key, String? value, bool? enabled})
  onQueryChanged;
  final void Function(String, {String? key, String? value, bool? enabled})
  onHeaderChanged;
  final ValueChanged<String> onDeleteHeader;
  final List<RequestCollection> collections;
  final ValueChanged<String> onSave;
  final VoidCallback onSend;
  final bool isExecuting;
  final RequestExecutionView? execution;

  @override
  Widget build(BuildContext context) {
    final canSend =
        tab.bodyFormat == RequestBodyFormat.text || isValidJson(tab.body);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('request-name-field'),
                  initialValue: tab.title,
                  onChanged: onTitleChanged,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Request name',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                key: const Key('save-request-menu'),
                tooltip: 'Save to folder',
                enabled: collections.isNotEmpty,
                onSelected: onSave,
                itemBuilder: (context) => [
                  for (final collection in collections)
                    PopupMenuItem(
                      value: collection.id,
                      child: Text(collection.name),
                    ),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Icon(Icons.folder_outlined, size: 18),
                      SizedBox(width: 4),
                      Text('Save'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                      DropdownMenuItem(
                        value: method,
                        child: Text(method.label),
                      ),
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
                onPressed: isExecuting || !canSend ? null : onSend,
                icon: const Icon(Icons.send, size: 17),
                label: Text(
                  isExecuting
                      ? 'Sending…'
                      : canSend
                      ? 'Send'
                      : 'Fix JSON to send',
                ),
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
                      Tab(key: Key('response-tab'), text: 'Response'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        KeyValueEditor(
                          values: tab.query,
                          emptyLabel: 'No query parameters',
                          onAdd: onAddQuery,
                          onChanged: onQueryChanged,
                        ),
                        KeyValueEditor(
                          values: tab.headers,
                          isHeader: true,
                          onHeaderPreset: onHeaderPreset,
                          emptyLabel: 'No headers',
                          onAdd: onAddHeader,
                          onChanged: onHeaderChanged,
                          onDelete: onDeleteHeader,
                        ),
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                              child: DropdownButtonFormField<RequestBodyFormat>(
                                key: const Key('body-format-picker'),
                                initialValue: tab.bodyFormat,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  labelText: 'Body format',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: RequestBodyFormat.json,
                                    child: Text('JSON'),
                                  ),
                                  DropdownMenuItem(
                                    value: RequestBodyFormat.text,
                                    child: Text('Text (raw)'),
                                  ),
                                ],
                                onChanged: (format) {
                                  if (format != null) {
                                    onBodyFormatChanged(format);
                                  }
                                },
                              ),
                            ),
                            Expanded(
                              child: tab.bodyFormat == RequestBodyFormat.json
                                  ? JsonBodyEditor(
                                      value: tab.body,
                                      onChanged: onBodyChanged,
                                    )
                                  : TextBodyEditor(
                                      value: tab.body,
                                      onChanged: onBodyChanged,
                                    ),
                            ),
                          ],
                        ),
                        ResponseView(execution: execution),
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
}
