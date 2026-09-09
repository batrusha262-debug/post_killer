import 'package:flutter/material.dart';

import '../domain/workspace_models.dart';

Color methodColor(BuildContext context, HttpMethod method) => switch (method) {
  HttpMethod.get => Colors.green.shade700,
  HttpMethod.post => Colors.orange.shade800,
  HttpMethod.put => Colors.blue.shade700,
  HttpMethod.patch => Colors.purple.shade600,
  HttpMethod.delete => Theme.of(context).colorScheme.error,
};
