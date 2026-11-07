import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:theme_core/theme_core.dart';
import 'package:ui_kit/ui_kit.dart';

import 'app/composition.dart';
import 'app/routes.dart';
import 'data/appearance_repository.dart';

/// Entry point. Opens an in-process episode over the shipped pack.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appearance = InMemoryAppearanceRepository();
  runApp(
    BardApp(
      composition: await Composition.inProcess(rootBundle),
      appearance: await ThemeController.load(
        rootBundle,
        initial: await appearance.load(),
        brightness: _platformBrightness(),
        onChanged: appearance.save,
      ),
    ),
  );
}

ThemeBrightness _platformBrightness() =>
    WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.light
    ? ThemeBrightness.light
    : ThemeBrightness.dark;

/// Root widget of the bard app.
class BardApp extends StatefulWidget {
  /// Creates the app over [composition].
  const BardApp({
    super.key,
    required this.composition,
    required this.appearance,
  });

  /// Injected services.
  final Composition composition;

  /// The player's theme and variant. It outlives a new episode.
  final ThemeController appearance;

  @override
  State<BardApp> createState() => _BardAppState();
}

class _BardAppState extends State<BardApp> with WidgetsBindingObserver {
  late Composition _composition = widget.composition;
  late GoRouter _router = _build();

  GoRouter _build() => buildRouter(
    _composition,
    appearance: widget.appearance,
    onNewEpisode: _startNewEpisode,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// System follows the OS brightness live (07 §Theme selector).
  @override
  void didChangePlatformBrightness() =>
      widget.appearance.osBrightness.value = _platformBrightness();

  /// One active host at a time: the old one is closed, a fresh empty
  /// episode replaces it, and the router restarts at `/`.
  final GlobalKey<ScaffoldMessengerState> _messenger =
      GlobalKey<ScaffoldMessengerState>();
  bool _opening = false;

  Future<void> _startNewEpisode() async {
    if (_opening) return;
    _opening = true;
    final Composition next;
    try {
      next = await Composition.inProcess(rootBundle, seedDemoAgents: false);
    } catch (e) {
      // Keep the current episode running and say why nothing changed.
      _opening = false;
      if (mounted) {
        _messenger.currentState?.showSnackBar(
          SnackBar(content: Text('Could not start a new episode: $e')),
        );
      }
      return;
    }
    _opening = false;
    final old = _composition;
    setState(() {
      _composition = next;
      _router = _build();
    });
    await old.episode.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) => MaterialApp.router(
        scaffoldMessengerKey: _messenger,
        title: 'B.A.R.D. Files',
        theme: widget.appearance.themeData.value,
        routerConfig: _router,
      ),
    );
  }
}
