import 'package:flutter/material.dart';

class HistoryPane extends StatelessWidget {
  const HistoryPane({super.key});

  @override
  Widget build(BuildContext context) => const SectionPlaceholder(
    title: 'History',
    icon: Icons.history,
    message: 'No request history yet',
  );
}

class VariablesPane extends StatelessWidget {
  const VariablesPane({super.key});

  @override
  Widget build(BuildContext context) => const SectionPlaceholder(
    title: 'Variables',
    icon: Icons.tune,
    message: 'No variables yet',
  );
}

class SectionPlaceholder extends StatelessWidget {
  const SectionPlaceholder({
    super.key,
    required this.title,
    required this.icon,
    required this.message,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(icon), const SizedBox(height: 8), Text(message)],
          ),
        ),
      ),
    ],
  );
}
