import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class JsonBodyEditor extends StatefulWidget {
  const JsonBodyEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<JsonBodyEditor> createState() => JsonBodyEditorState();
}

class JsonBodyEditorState extends State<JsonBodyEditor> {
  late final _JsonSyntaxController _controller;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _controller = _JsonSyntaxController(text: widget.value);
    _validate(widget.value);
  }

  @override
  void didUpdateWidget(covariant JsonBodyEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
      _validate(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _validate(value);
    widget.onChanged(value);
  }

  void _validate(String value) {
    String? error;
    if (value.trim().isNotEmpty) {
      try {
        jsonDecode(value);
      } on FormatException catch (exception) {
        error = exception.message.toString();
      }
    }
    if (mounted) setState(() => _validationError = error);
  }

  void _format() {
    try {
      final formatted = const JsonEncoder.withIndent('  ')
          .convert(jsonDecode(_controller.text));
      _controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      _onChanged(formatted);
    } on FormatException {
      _validate(_controller.text);
    }
  }

  void _insertSuggestion(String suggestion) {
    final selection = _controller.selection;
    final start = selection.start < 0
        ? _controller.text.length
        : selection.start;
    final end = selection.end < 0 ? start : selection.end;
    final text = _controller.text.replaceRange(start, end, suggestion);
    final cursor = start + suggestion.length;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );
    _onChanged(text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('JSON', style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              TextButton.icon(
                key: const Key('format-json-button'),
                onPressed:
                    _validationError == null &&
                        _controller.text.trim().isNotEmpty
                    ? _format
                    : null,
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: const Text('Format'),
              ),
            ],
          ),
          if (_validationError case final error?)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Invalid JSON: $error',
                key: const Key('json-validation-error'),
                style: TextStyle(color: colors.error),
              ),
            ),
          Wrap(
            key: const Key('json-autocomplete'),
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final suggestion in const [
                '{}',
                '[]',
                'true',
                'false',
                'null',
                '"key": ',
                '"{{variable}}"',
              ])
                ActionChip(
                  label: Text(suggestion),
                  onPressed: () => _insertSuggestion(suggestion),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              key: const Key('json-body-editor'),
              controller: _controller,
              expands: true,
              maxLines: null,
              minLines: null,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontFamily: 'monospace', height: 1.45),
              inputFormatters: const [_JsonPairFormatter()],
              decoration: const InputDecoration(
                hintText: '{\n  "name": "Ada"\n}',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              onChanged: _onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _JsonPairFormatter extends TextInputFormatter {
  const _JsonPairFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length != oldValue.text.length + 1 ||
        newValue.selection.start < 1) {
      return newValue;
    }
    final insertedAt = newValue.selection.start - 1;
    final opener = newValue.text[insertedAt];
    final closer = switch (opener) {
      '{' => '}',
      '[' => ']',
      _ => null,
    };
    if (closer == null) return newValue;
    return TextEditingValue(
      text: newValue.text.replaceRange(insertedAt + 1, insertedAt + 1, closer),
      selection: TextSelection.collapsed(offset: insertedAt + 1),
    );
  }
}

class _JsonSyntaxController extends TextEditingController {
  _JsonSyntaxController({super.text});

  static final _tokenPattern = RegExp(
    r'"(?:\\.|[^"\\])*"|\b(?:true|false|null)\b|-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b',
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final colors = Theme.of(context).colorScheme;
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final match in _tokenPattern.allMatches(text)) {
      if (match.start > cursor) {
        children.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      final color = token.startsWith('"')
          ? colors.primary
          : token == 'true' || token == 'false' || token == 'null'
          ? colors.tertiary
          : colors.secondary;
      children.add(
        TextSpan(
          text: token,
          style: TextStyle(color: color),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: style, children: children);
  }
}

bool isValidJson(String value) {
  if (value.trim().isEmpty) return true;
  try {
    jsonDecode(value);
    return true;
  } on FormatException {
    return false;
  }
}
