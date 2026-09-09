import 'package:flutter/material.dart';

import '../domain/workspace_models.dart';

class ResponseView extends StatelessWidget {
  const ResponseView({super.key, required this.execution});
  final RequestExecutionView? execution;

  @override
  Widget build(BuildContext context) {
    final result = execution;
    if (result?.error case final error?) {
      return Center(child: Text(error, key: const Key('response-error')));
    }
    if (result?.status case final status?) {
      final headers = result!.headers
          .map((header) => '${header.name}: ${header.value}')
          .join('\n');
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          'HTTP $status · ${result.durationMillis} ms\n\n'
          'Headers\n${headers.isEmpty ? '(none)' : headers}\n\n'
          'Body\n${result.body}',
          key: const Key('response-content'),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.data_object, size: 36),
          SizedBox(height: 8),
          Text('Response will appear here'),
          SizedBox(height: 4),
          Text('Send a request to inspect status, headers and body'),
        ],
      ),
    );
  }
}
