import 'package:flutter/material.dart';

const headerPresets = {
  'Accept': 'application/json',
  'Content-Type': 'application/json',
  'Authorization': 'Bearer ',
  'User-Agent': 'Post-Killer',
  'Cache-Control': 'no-cache',
  'Accept-Language': 'ru-RU, en;q=0.9',
};

class HeaderPresets extends StatelessWidget {
  const HeaderPresets({super.key, required this.onSelected});
  final void Function(String name, String value) onSelected;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final preset in headerPresets.entries)
          ActionChip(
            label: Text(preset.key),
            avatar: const Icon(Icons.add, size: 16),
            onPressed: () => onSelected(preset.key, preset.value),
          ),
      ],
    ),
  );
}
