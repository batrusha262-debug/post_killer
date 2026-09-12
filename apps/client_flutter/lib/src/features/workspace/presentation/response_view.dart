import 'dart:convert';

import 'package:file_selector/file_selector.dart';
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
  final _search = TextEditingController();
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
    _search.clear();
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
    _search.dispose();
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
    final responseBytes =
        response.bodyBytes ?? utf8.encode(response.body ?? '');
    final contentType = _contentType(response.headers);
    final isBinary = _isBinary(responseBytes, contentType);
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
                Text('${responseBytes.length} bytes'),
                Text(isBinary ? 'Binary' : (_isJson ? 'JSON' : 'Text')),
              ],
            ),
          ),
          TabBar(
            tabs: [
              Tab(
                text: isBinary ? 'Preview' : (_isJson ? 'Pretty JSON' : 'Body'),
              ),
              Tab(text: isBinary ? 'Download' : 'Raw'),
              Tab(text: 'Headers (${response.headers.length})'),
            ],
          ),
          Expanded(
            child: ColoredBox(
              color: colors.surface,
              child: TabBarView(
                children: [
                  isBinary
                      ? _binaryBody(context, responseBytes, contentType)
                      : _body(context, pretty: true),
                  isBinary
                      ? _binaryBody(context, responseBytes, contentType)
                      : _body(context, pretty: false),
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
    final matchCount = _matchCount(text, _search.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('response-search'),
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    hintText: 'Find in response',
                    suffixText: _search.text.isEmpty
                        ? null
                        : '$matchCount ${matchCount == 1 ? 'match' : 'matches'}',
                  ),
                ),
              ),
              TextButton.icon(
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
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: pretty && _isJson && _search.text.isEmpty
                ? SelectableText.rich(
                    _pretty.buildTextSpan(
                      context: context,
                      style: style,
                      withComposing: false,
                    ),
                    key: const Key('response-content'),
                  )
                : _search.text.isEmpty
                ? SelectableText(
                    text.isEmpty ? '(empty body)' : text,
                    style: style,
                    key: Key(pretty ? 'response-content' : 'response-raw'),
                  )
                : SelectableText.rich(
                    _highlightMatches(
                      text.isEmpty ? '(empty body)' : text,
                      style,
                    ),
                    key: Key(pretty ? 'response-content' : 'response-raw'),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _binaryBody(
    BuildContext context,
    List<int> bytes,
    String? contentType,
  ) {
    final isImage = contentType?.startsWith('image/') == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const Key('response-download'),
            onPressed: () => _downloadResponse(context, bytes, contentType),
            icon: const Icon(Icons.download_outlined, size: 16),
            label: const Text('Save response'),
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: isImage
                  ? InteractiveViewer(
                      child: Image.memory(
                        Uint8List.fromList(bytes),
                        errorBuilder: (_, _, _) =>
                            _binaryDescription(contentType, bytes.length),
                      ),
                    )
                  : _binaryDescription(contentType, bytes.length),
            ),
          ),
        ),
      ],
    );
  }

  Widget _binaryDescription(String? contentType, int size) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.insert_drive_file_outlined, size: 40),
      const SizedBox(height: 10),
      Text(contentType ?? 'Binary response'),
      const SizedBox(height: 4),
      Text('$size bytes — save the response to inspect it locally.'),
    ],
  );

  Future<void> _downloadResponse(
    BuildContext context,
    List<int> bytes,
    String? contentType,
  ) async {
    try {
      final location = await getSaveLocation(
        suggestedName: 'response.${_extensionFor(contentType)}',
        confirmButtonText: 'Save response',
      );
      if (location == null) return;
      await XFile.fromData(
        Uint8List.fromList(bytes),
        mimeType: contentType,
        name: 'response.${_extensionFor(contentType)}',
      ).saveTo(location.path);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Response saved')));
      }
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save response')),
        );
      }
    }
  }

  String? _contentType(List<RequestResponseHeader> headers) {
    for (final header in headers) {
      if (header.name.toLowerCase() == 'content-type') {
        return header.value.split(';').first.trim().toLowerCase();
      }
    }
    return null;
  }

  bool _isBinary(List<int> bytes, String? contentType) {
    if (bytes.isEmpty) return false;
    if (contentType != null) {
      return !(contentType.startsWith('text/') ||
          contentType.contains('json') ||
          contentType.contains('xml') ||
          contentType.contains('javascript') ||
          contentType.contains('x-www-form-urlencoded'));
    }
    try {
      utf8.decode(bytes);
      return false;
    } on FormatException {
      return true;
    }
  }

  String _extensionFor(String? contentType) => switch (contentType) {
    'application/json' => 'json',
    'application/pdf' => 'pdf',
    'image/png' => 'png',
    'image/jpeg' => 'jpg',
    'image/gif' => 'gif',
    'text/plain' => 'txt',
    _ => 'bin',
  };

  int _matchCount(String text, String query) {
    if (query.isEmpty) return 0;
    final haystack = text.toLowerCase();
    final needle = query.toLowerCase();
    var start = 0;
    var count = 0;
    while (true) {
      final match = haystack.indexOf(needle, start);
      if (match < 0) return count;
      count += 1;
      start = match + needle.length;
    }
  }

  TextSpan _highlightMatches(String text, TextStyle style) {
    if (_search.text.isEmpty) return TextSpan(text: text, style: style);
    final haystack = text.toLowerCase();
    final needle = _search.text.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final match = haystack.indexOf(needle, start);
      if (match < 0) {
        spans.add(TextSpan(text: text.substring(start), style: style));
        break;
      }
      if (match > start) {
        spans.add(TextSpan(text: text.substring(start, match), style: style));
      }
      spans.add(
        TextSpan(
          text: text.substring(match, match + needle.length),
          style: style.copyWith(
            backgroundColor: Colors.amber.withValues(alpha: .55),
          ),
        ),
      );
      start = match + needle.length;
    }
    return TextSpan(children: spans);
  }
}
