import 'package:flutter/material.dart';

/// Entry point. Placeholder shell; the UI workstream replaces it.
void main() {
  runApp(const CompanionApp());
}

/// Root widget of the companion app.
class CompanionApp extends StatelessWidget {
  /// Creates the root widget.
  const CompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'B.A.R.D. Companion',
      home: Scaffold(body: Center(child: Text('B.A.R.D. Companion'))),
    );
  }
}
