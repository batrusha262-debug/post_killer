import 'package:flutter/material.dart';

class EmptyWorkspace extends StatelessWidget {
  const EmptyWorkspace({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Open a saved request or create a new tab'));
}
