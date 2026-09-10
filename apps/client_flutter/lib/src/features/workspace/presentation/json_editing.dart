import 'dart:math' as math;

import 'package:flutter/material.dart';

TextEditingValue indentJson(TextEditingValue value, {bool outdent = false}) {
  final selection = value.selection;
  if (!selection.isValid) return value;
  if (selection.isCollapsed && !outdent) {
    return value.copyWith(
      text: value.text.replaceRange(selection.start, selection.end, '  '),
      selection: TextSelection.collapsed(offset: selection.start + 2),
      composing: TextRange.empty,
    );
  }
  final start = value.text.substring(0, selection.start).lastIndexOf('\n') + 1;
  var lineStart = start;
  final edits = <({int offset, int remove})>[];
  do {
    final remaining = value.text.substring(lineStart);
    final remove = outdent
        ? (remaining.startsWith('  ')
              ? 2
              : remaining.startsWith(' ')
              ? 1
              : 0)
        : 0;
    edits.add((offset: lineStart, remove: remove));
    final next = value.text.indexOf('\n', lineStart);
    if (next < 0 || next + 1 >= selection.end) break;
    lineStart = next + 1;
  } while (lineStart < value.text.length);
  var text = value.text;
  for (final edit in edits.reversed) {
    text = text.replaceRange(
      edit.offset,
      edit.offset + edit.remove,
      outdent ? '' : '  ',
    );
  }
  int moved(int offset) {
    var delta = 0;
    for (final edit in edits) {
      if (edit.offset > offset) break;
      delta += outdent ? -math.min(edit.remove, offset - edit.offset) : 2;
    }
    return offset + delta;
  }

  return value.copyWith(
    text: text,
    selection: TextSelection(
      baseOffset: moved(selection.baseOffset),
      extentOffset: moved(selection.extentOffset),
    ),
    composing: TextRange.empty,
  );
}

class JsonCompletion {
  const JsonCompletion(this.label, this.start, this.end, this.replacement);
  final String label;
  final int start;
  final int end;
  final String replacement;
  TextEditingValue apply(TextEditingValue value) => TextEditingValue(
    text: value.text.replaceRange(start, end, replacement),
    selection: TextSelection.collapsed(offset: start + replacement.length),
  );
}

List<JsonCompletion> jsonCompletions(TextEditingValue value) {
  if (!value.selection.isValid ||
      !value.selection.isCollapsed ||
      !value.composing.isCollapsed) {
    return [];
  }
  final end = value.selection.start;
  final before = value.text.substring(0, end);
  var inString = false;
  var escaped = false;
  var quote = -1;
  for (var i = 0; i < before.length; i++) {
    if (escaped) {
      escaped = false;
      continue;
    }
    if (before[i] == '\\' && inString) {
      escaped = true;
      continue;
    }
    if (before[i] == '"') {
      inString = !inString;
      quote = i;
    }
  }
  if (inString) {
    final context = before.substring(0, quote).trimRight();
    if (!context.endsWith('{') && !context.endsWith(',')) return [];
    final prefix = before.substring(quote + 1);
    if (prefix.isEmpty || !RegExp(r'^\w+$').hasMatch(prefix)) return [];
    final keys = {
      'id',
      'name',
      'email',
      'enabled',
      'description',
      'items',
      'value',
      'type',
    };
    for (final match in RegExp(r'"([\w]+)"\s*:').allMatches(value.text)) {
      keys.add(match[1]!);
    }
    final suffix = value.text.substring(end);
    final close = suffix.startsWith('"') ? 1 : 0;
    final hasColon = suffix.substring(close).trimLeft().startsWith(':');
    return [
      for (final key in keys)
        if (key.startsWith(prefix) && key != prefix)
          JsonCompletion(
            key,
            quote + 1,
            end + close,
            '$key"${hasColon ? '' : ': '}',
          ),
    ];
  }
  final match = RegExp(r'[A-Za-z]+$').firstMatch(before);
  if (match == null) {
    final context = before.trimRight();
    if (!RegExp(r'[:\[,]$').hasMatch(context)) return [];
    return const [
          JsonCompletion('string', 0, 0, '""'),
          JsonCompletion('object', 0, 0, '{}'),
          JsonCompletion('array', 0, 0, '[]'),
          JsonCompletion('true', 0, 0, 'true'),
          JsonCompletion('false', 0, 0, 'false'),
          JsonCompletion('null', 0, 0, 'null'),
        ]
        .map(
          (completion) => JsonCompletion(
            completion.label,
            end,
            end,
            completion.replacement,
          ),
        )
        .toList();
  }
  final context = before.substring(0, match.start).trimRight();
  if (context.isNotEmpty && !RegExp(r'[:\[,]$').hasMatch(context)) return [];
  return [
    for (final literal in ['true', 'false', 'null'])
      if (literal.startsWith(match[0]!) && literal != match[0])
        JsonCompletion(literal, match.start, end, literal),
  ];
}

class JsonCompletionMenu extends StatelessWidget {
  const JsonCompletionMenu({
    super.key,
    required this.value,
    required this.scrollOffset,
    required this.bounds,
    required this.completions,
    required this.highlighted,
    required this.onSelected,
  });
  final TextEditingValue value;
  final double scrollOffset;
  final Size bounds;
  final List<JsonCompletion> completions;
  final int highlighted;
  final ValueChanged<JsonCompletion> onSelected;
  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style
        .copyWith(fontFamily: 'monospace', fontSize: 14, height: 1.45);
    final painter = TextPainter(
      text: TextSpan(text: value.text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: math.max(1, bounds.width - 24));
    final menuHeight = math.min(
      math.min(144.0, completions.length * 48.0),
      bounds.height,
    );
    final caret = painter.getOffsetForCaret(
      TextPosition(offset: value.selection.start),
      Rect.zero,
    );
    painter.dispose();
    return Positioned(
      left: (caret.dx + 12).clamp(0, math.max(0, bounds.width - 220)),
      top: (caret.dy + 38 - scrollOffset).clamp(
        0,
        math.max(0, bounds.height - menuHeight),
      ),
      child: SizedBox(
        width: math.min(220, bounds.width),
        height: menuHeight,
        child: Material(
          key: const Key('json-autocomplete'),
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              for (var i = 0; i < completions.length; i++)
                ListTile(
                  dense: true,
                  selected: i == highlighted,
                  title: Text(completions[i].label),
                  trailing: i == highlighted ? const Text('↵') : null,
                  onTap: () => onSelected(completions[i]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
