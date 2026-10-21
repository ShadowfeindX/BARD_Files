import 'package:flutter/material.dart';

/// Entry point. Placeholder shell; the UI workstream replaces it.
void main() {
  runApp(const BardApp());
}

/// Root widget of the bard app.
class BardApp extends StatelessWidget {
  /// Creates the root widget.
  const BardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'B.A.R.D. Files',
      home: Scaffold(body: Center(child: Text('B.A.R.D. Files'))),
    );
  }
}
