import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

import 'app/composition.dart';
import 'app/routes.dart';

/// Entry point. Runs on the in-memory fake until the session host is wired in.
void main() {
  runApp(BardApp(composition: Composition.fake()));
}

/// Root widget of the bard app.
class BardApp extends StatefulWidget {
  /// Creates the app over [composition].
  const BardApp({super.key, required this.composition});

  /// Injected services.
  final Composition composition;

  @override
  State<BardApp> createState() => _BardAppState();
}

class _BardAppState extends State<BardApp> {
  late final _router = buildRouter(widget.composition);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'B.A.R.D. Files',
      theme: BardTheme.light(),
      darkTheme: BardTheme.dark(),
      routerConfig: _router,
    );
  }
}
