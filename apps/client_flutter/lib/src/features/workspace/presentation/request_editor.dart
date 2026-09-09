import 'key_value_editor.dart';
import 'json_body_editor.dart';
import 'response_view.dart';

import 'package:flutter/material.dart';

import '../domain/workspace_models.dart';

class RequestEditor extends StatelessWidget {
  const RequestEditor({
    super.key,
    required this.tab,
    required this.onMethodChanged,
    required this.onUrlChanged,
    required this.onBodyChanged,
    required this.onAddQuery,
    required this.onAddHeader,
    required this.onHeaderPreset,
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
  final void Function(String, String) onHeaderPreset;
  final void Function(String, {String? key, String? value, bool? enabled})
  onQueryChanged;
  final void Function(String, {String? key, String? value, bool? enabled})
  onHeaderChanged;
  final VoidCallback onSend;
  final bool isExecuting;
  final RequestExecutionView? execution;

  @override
  Widget build(BuildContext context) {
    final isJsonValid = isValidJson(tab.body);
    return Padding(
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
                onPressed: isExecuting || !isJsonValid ? null : onSend,
                icon: const Icon(Icons.send, size: 17),
                label: Text(
                  isExecuting
                      ? 'Sending…'
                      : isJsonValid
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
                        ),
                        JsonBodyEditor(
                          value: tab.body,
                          onChanged: onBodyChanged,
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
