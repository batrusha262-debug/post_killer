import 'key_value_editor.dart';
import 'json_body_editor.dart';
import 'text_body_editor.dart';
import 'response_view.dart';
import 'request_auth_editor.dart';

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
    required this.onAddBodyField,
    required this.onBodyFieldChanged,
    required this.onDeleteBodyField,
    required this.onPickBodyFile,
    required this.onDeleteBodyFile,
    required this.onNetworkChanged,
    required this.onPickCustomCa,
    required this.onAuthChanged,
    required this.onAddQuery,
    required this.onAddHeader,
    required this.onHeaderPreset,
    required this.onQueryChanged,
    required this.onHeaderChanged,
    required this.onDeleteHeader,
    required this.collections,
    required this.loginEndpoints,
    required this.onSave,
    required this.onSend,
    required this.onCancel,
    required this.isExecuting,
    required this.execution,
  });

  final RequestTab tab;
  final ValueChanged<HttpMethod> onMethodChanged;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onUrlChanged;
  final ValueChanged<String> onBodyChanged;
  final ValueChanged<RequestBodyFormat> onBodyFormatChanged;
  final VoidCallback onAddBodyField;
  final void Function(String, {String? key, String? value, bool? enabled})
  onBodyFieldChanged;
  final ValueChanged<String> onDeleteBodyField;
  final VoidCallback onPickBodyFile;
  final ValueChanged<String> onDeleteBodyFile;
  final ValueChanged<RequestNetworkSettings> onNetworkChanged;
  final VoidCallback onPickCustomCa;
  final ValueChanged<RequestAuth> onAuthChanged;
  final VoidCallback onAddQuery;
  final VoidCallback onAddHeader;
  final void Function(String, String) onHeaderPreset;
  final void Function(String, {String? key, String? value, bool? enabled})
  onQueryChanged;
  final void Function(String, {String? key, String? value, bool? enabled})
  onHeaderChanged;
  final ValueChanged<String> onDeleteHeader;
  final List<RequestCollection> collections;
  final List<SavedRequest> loginEndpoints;
  final ValueChanged<String> onSave;
  final VoidCallback onSend;
  final VoidCallback onCancel;
  final bool isExecuting;
  final RequestExecutionView? execution;

  @override
  Widget build(BuildContext context) {
    final canSend =
        (tab.bodyFormat != RequestBodyFormat.json || isValidJson(tab.body)) &&
        tab.auth.isValid;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: constraints.maxWidth < 620
                      ? 620
                      : constraints.maxWidth,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 150,
                        child: TextFormField(
                          key: const Key('request-name-field'),
                          initialValue: tab.title,
                          onChanged: onTitleChanged,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Request name',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 96,
                        child: DropdownButtonFormField<HttpMethod>(
                          key: const Key('method-picker'),
                          initialValue: tab.method,
                          isExpanded: true,
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
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.bookmark_add_outlined,
                            size: 19,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        child: isExecuting
                            ? FilledButton.icon(
                                key: const Key('cancel-request-button'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .error,
                                  foregroundColor: Theme.of(context)
                                      .colorScheme
                                      .onError,
                                ),
                                onPressed: onCancel,
                                icon: const Icon(Icons.close_rounded, size: 17),
                                label: const Text('Cancel'),
                              )
                            : FilledButton.icon(
                                key: const Key('send-request-button'),
                                onPressed: canSend ? onSend : null,
                                icon: const Icon(Icons.send_rounded, size: 17),
                                label: Text(
                                  canSend ? 'Send' : 'Fix JSON to send',
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: DefaultTabController(
              length: 6,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Query'),
                      Tab(text: 'Headers'),
                      Tab(key: Key('auth-tab'), text: 'Auth'),
                      Tab(text: 'Body'),
                      Tab(text: 'Network'),
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
                        RequestAuthEditor(
                          auth: tab.auth,
                          loginEndpoints: loginEndpoints,
                          onChanged: onAuthChanged,
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
                                  DropdownMenuItem(
                                    value: RequestBodyFormat.formUrlEncoded,
                                    child: Text('Form URL encoded'),
                                  ),
                                  DropdownMenuItem(
                                    value: RequestBodyFormat.multipart,
                                    child: Text('Multipart form'),
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
                              child: _BodyEditor(
                                tab: tab,
                                onBodyChanged: onBodyChanged,
                                onAddBodyField: onAddBodyField,
                                onBodyFieldChanged: onBodyFieldChanged,
                                onDeleteBodyField: onDeleteBodyField,
                                onPickBodyFile: onPickBodyFile,
                                onDeleteBodyFile: onDeleteBodyFile,
                              ),
                            ),
                          ],
                        ),
                        ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            TextFormField(
                              initialValue: tab.network.proxyUrl,
                              onChanged: (value) => onNetworkChanged(
                                tab.network.copyWith(proxyUrl: value),
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Proxy URL',
                                hintText: 'http://127.0.0.1:8080',
                                helperText:
                                    'Runtime only; never saved or exported.',
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              tab.network.customCaPem == null
                                  ? 'Custom CA: system trust store'
                                  : 'Custom CA loaded for this draft',
                            ),
                            TextButton.icon(
                              onPressed: onPickCustomCa,
                              icon: const Icon(Icons.verified_user_outlined),
                              label: const Text('Choose PEM certificate'),
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

class _BodyEditor extends StatelessWidget {
  const _BodyEditor({
    required this.tab,
    required this.onBodyChanged,
    required this.onAddBodyField,
    required this.onBodyFieldChanged,
    required this.onDeleteBodyField,
    required this.onPickBodyFile,
    required this.onDeleteBodyFile,
  });

  final RequestTab tab;
  final ValueChanged<String> onBodyChanged;
  final VoidCallback onAddBodyField;
  final void Function(String, {String? key, String? value, bool? enabled})
  onBodyFieldChanged;
  final ValueChanged<String> onDeleteBodyField;
  final VoidCallback onPickBodyFile;
  final ValueChanged<String> onDeleteBodyFile;

  @override
  Widget build(BuildContext context) => switch (tab.bodyFormat) {
    RequestBodyFormat.json => JsonBodyEditor(
      value: tab.body,
      onChanged: onBodyChanged,
    ),
    RequestBodyFormat.text => TextBodyEditor(
      value: tab.body,
      onChanged: onBodyChanged,
    ),
    RequestBodyFormat.formUrlEncoded => KeyValueEditor(
      values: tab.bodyFields,
      keyLabel: 'FIELD',
      valueLabel: 'VALUE',
      emptyLabel: 'No form fields yet',
      onAdd: onAddBodyField,
      onChanged: onBodyFieldChanged,
      onDelete: onDeleteBodyField,
    ),
    RequestBodyFormat.multipart => ListView(
      padding: const EdgeInsets.all(12),
      children: [
        KeyValueEditor(
          values: tab.bodyFields,
          keyLabel: 'FIELD',
          valueLabel: 'VALUE',
          emptyLabel: 'No multipart fields yet',
          onAdd: onAddBodyField,
          onChanged: onBodyFieldChanged,
          onDelete: onDeleteBodyField,
        ),
        const SizedBox(height: 12),
        Text('Files', style: Theme.of(context).textTheme.titleSmall),
        for (final file in tab.bodyFiles)
          ListTile(
            dense: true,
            leading: const Icon(Icons.attach_file_outlined),
            title: Text(file.fileName ?? file.path),
            subtitle: Text('${file.fieldName} · ${file.path}'),
            trailing: IconButton(
              tooltip: 'Remove file',
              onPressed: () => onDeleteBodyFile(file.path),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        OutlinedButton.icon(
          onPressed: onPickBodyFile,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Attach file'),
        ),
      ],
    ),
  };
}
