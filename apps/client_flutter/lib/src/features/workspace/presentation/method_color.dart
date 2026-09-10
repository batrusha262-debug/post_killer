import 'package:flutter/material.dart';

import '../domain/workspace_models.dart';

Color methodColor(BuildContext context, HttpMethod method) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (method) {
    HttpMethod.get => dark ? Colors.green.shade300 : Colors.green.shade800,
    HttpMethod.post => dark ? Colors.orange.shade300 : Colors.orange.shade900,
    HttpMethod.put => dark ? Colors.blue.shade300 : Colors.blue.shade800,
    HttpMethod.patch => dark ? Colors.purple.shade200 : Colors.purple.shade700,
    HttpMethod.delete => Theme.of(context).colorScheme.error,
  };
}
