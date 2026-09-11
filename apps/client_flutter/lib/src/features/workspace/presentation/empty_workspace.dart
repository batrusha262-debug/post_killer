import 'package:flutter/material.dart';

class EmptyWorkspace extends StatelessWidget {
  const EmptyWorkspace({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 360,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: .48),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.rocket_launch_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ready when you are',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Open a saved request or create a new tab to start exploring an API.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
