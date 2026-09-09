import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'json_syntax.dart';
import 'json_editing.dart';

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
  late final JsonSyntaxController _controller;
  String? _validationError;
  late final FocusNode _focus;
  final _scroll = ScrollController();
  List<JsonCompletion> _completions = [];
  int _highlighted = 0;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode(onKeyEvent: _handleKey);
    _controller = JsonSyntaxController(text: widget.value);
    _controller.addListener(_refreshCompletions);
    _focus.addListener(_refreshCompletions);
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
    _controller.removeListener(_refreshCompletions);
    _focus.removeListener(_refreshCompletions);
    _focus.dispose();
    _scroll.dispose();
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

  void _refreshCompletions() {
    if (!mounted) return;
    setState(() {
      _completions = _focus.hasFocus ? jsonCompletions(_controller.value) : [];
      _highlighted = 0;
    });
  }

  void _complete(JsonCompletion completion) {
    _controller.value = completion.apply(_controller.value);
    _onChanged(_controller.text);
    setState(() => _completions = []);
    _focus.requestFocus();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_controller.value.composing.isCollapsed) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      _controller.value = indentJson(
        _controller.value,
        outdent: HardwareKeyboard.instance.isShiftPressed,
      );
      _onChanged(_controller.text);
      return KeyEventResult.handled;
    }
    if (_completions.isEmpty) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() => _completions = []);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(
        () => _highlighted =
            (_highlighted +
                (event.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1)) %
            _completions.length,
      );
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      _complete(_completions[_highlighted]);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
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
          const SizedBox(height: 8),
          Expanded(
            child: Focus(
              onKeyEvent: _handleKey,
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    TextField(
                      key: const Key('json-body-editor'),
                      controller: _controller,
                      focusNode: _focus,
                      scrollController: _scroll,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      keyboardType: TextInputType.multiline,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        height: 1.45,
                      ),
                      inputFormatters: const [JsonPairFormatter()],
                      decoration: const InputDecoration(
                        hintText: '{\n  "name": "Ada"\n}',
                        hintStyle: TextStyle(color: Colors.grey),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: _onChanged,
                    ),
                    if (_completions.isNotEmpty)
                      JsonCompletionMenu(
                        value: _controller.value,
                        scrollOffset: _scroll.hasClients ? _scroll.offset : 0,
                        bounds: constraints.biggest,
                        completions: _completions,
                        highlighted: _highlighted,
                        onSelected: _complete,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
