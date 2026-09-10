import 'package:flutter/material.dart';

class TextBodyEditor extends StatelessWidget {
  const TextBodyEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: TextFormField(
      key: const Key('text-body-editor'),
      initialValue: value,
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
      decoration: const InputDecoration(
        hintText: 'Any text, XML, GraphQL, or another raw payload',
        border: OutlineInputBorder(),
      ),
      onChanged: onChanged,
    ),
  );
}
