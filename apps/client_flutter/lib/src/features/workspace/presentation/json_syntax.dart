import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class JsonPairFormatter extends TextInputFormatter {
  const JsonPairFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed ||
        !newValue.selection.isCollapsed ||
        newValue.text.length != oldValue.text.length + 1 ||
        newValue.selection.start < 1) {
      return newValue;
    }
    final insertedAt = newValue.selection.start - 1;
    var inString = false;
    var escaped = false;
    for (final code in newValue.text.substring(0, insertedAt).runes) {
      if (escaped) {
        escaped = false;
        continue;
      }
      if (code == 92 && inString) {
        escaped = true;
        continue;
      }
      if (code == 34) inString = !inString;
    }
    if (inString) return newValue;
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

class JsonSyntaxController extends TextEditingController {
  JsonSyntaxController({super.text});

  static final _tokenPattern = RegExp(
    r'"(?:\\.|[^"\\])*"|\b(?:true|false|null)\b|-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b',
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (withComposing && !value.composing.isCollapsed) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
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
