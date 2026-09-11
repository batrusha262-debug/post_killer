import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/workspace_models.dart';
import 'json_syntax.dart';

class ResponseView extends StatefulWidget {
  const ResponseView({super.key, required this.execution});
  final RequestExecutionView? execution;
  @override
  State<ResponseView> createState() => _ResponseViewState();
}

class _ResponseViewState extends State<ResponseView> {
  final _pretty = JsonSyntaxController();
  bool _isJson = false;
  @override
  void initState() {
    super.initState();
    _updateBody();
  }

  @override
  void didUpdateWidget(covariant ResponseView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.execution != widget.execution) _updateBody();
  }

  void _updateBody() {
    final body = widget.execution?.body ?? '';
    _isJson = false;
    _pretty.text = body;
    // Keep large responses responsive; Raw remains available without parsing.
    if (body.length > 1024 * 1024) return;
    try {
      _pretty.text = const JsonEncoder.withIndent('  ')
          .convert(jsonDecode(body));
      _isJson = true;
    } on FormatException {
      /* Non-JSON responses remain readable as text. */
    }
  }

  @override
  void dispose() {
    _pretty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.execution;
    if (result?.error case final error?) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                size: 32,
              ),
              const SizedBox(height: 12),
              SelectableText(error, key: const Key('response-error')),
            ],
          ),
        ),
      );
    }
    if (result?.status == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.data_object, size: 36),
            SizedBox(height: 8),
            Text('Response will appear here'),
            SizedBox(height: 4),
            Text('Send a request to inspect status, headers and body'),
          ],
        ),
      );
    }
    final response = result!;
    final colors = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: response.status! < 400
                  ? colors.secondaryContainer.withValues(alpha: .55)
                  : colors.errorContainer.withValues(alpha: .55),
            ),
            child: Wrap(
              spacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  backgroundColor: Colors.transparent,
                  side: BorderSide.none,
                  avatar: Icon(
                    response.status! < 400
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    size: 18,
                  ),
                  label: Text('HTTP ${response.status}'),
                ),
                Text('${response.durationMillis} ms'),
                Text('${utf8.encode(response.body ?? '').length} bytes'),
                Text(_isJson ? 'JSON' : 'Text'),
              ],
            ),
          ),
          TabBar(
            tabs: [
              Tab(text: _isJson ? 'Pretty JSON' : 'Body'),
              const Tab(text: 'Raw'),
              Tab(text: 'Headers (${response.headers.length})'),
            ],
          ),
          Expanded(
            child: ColoredBox(
              color: colors.surface,
              child: TabBarView(
                children: [
                  _body(context, pretty: true),
                  _body(context, pretty: false),
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1),
                        1: FlexColumnWidth(2),
                      },
                      children: [
                        for (final header in response.headers)
                          TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: SelectableText(
                                  header.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: SelectableText(header.value),
                              ),
                            ],
                          ),
                        if (response.headers.isEmpty)
                          const TableRow(
                            children: [Text('No headers'), SizedBox()],
                          ),
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

  Widget _body(BuildContext context, {required bool pretty}) {
    final text = pretty ? _pretty.text : widget.execution?.body ?? '';
    const style = TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Response copied')),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy'),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: pretty && _isJson
                ? SelectableText.rich(
                    _pretty.buildTextSpan(
                      context: context,
                      style: style,
                      withComposing: false,
                    ),
                    key: const Key('response-content'),
                  )
                : SelectableText(
                    text.isEmpty ? '(empty body)' : text,
                    style: style,
                    key: Key(pretty ? 'response-content' : 'response-raw'),
                  ),
          ),
        ),
      ],
    );
  }
}
