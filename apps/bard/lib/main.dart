import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import 'app/composition.dart';
import 'app/routes.dart';

/// Entry point. Opens an in-process operation over the shipped pack.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(BardApp(composition: await Composition.inProcess(rootBundle)));
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
  late Composition _composition = widget.composition;
  late GoRouter _router = _build();

  GoRouter _build() =>
      buildRouter(_composition, onNewOperation: _startNewOperation);

  /// One active host at a time: the old one is closed, a fresh empty
  /// operation replaces it, and the router restarts at `/`.
  Future<void> _startNewOperation() async {
    final next = await Composition.inProcess(rootBundle, seedDemoAgents: false);
    final old = _composition;
    setState(() {
      _composition = next;
      _router = _build();
    });
    await old.operation.dispose();
  }

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
