import 'dart:async';

import 'package:backend/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:theme_core/theme_core.dart';
import 'package:ui_kit/ui_kit.dart';

import 'app/composition.dart';
import 'app/routes.dart';
import 'data/appearance_repository.dart';
import 'data/pack_assets.dart';
import 'ui/home/home_screen.dart';
import 'ui/home/lan_dialogs.dart';

/// Entry point. Opens this machine's local data and an in-process episode
/// over the shipped pack.
///
/// When the local data folder cannot be opened, the app still runs: the
/// appearance setting lasts until exit, and hosting, joining and reports are
/// off.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LocalData? local;
  try {
    local = await LocalData.open(LocalDataPaths.forPlatform());
  } on Object catch (e) {
    debugPrint('Local data unavailable: $e');
  }
  final AppearanceRepository appearance = local == null
      ? InMemoryAppearanceRepository()
      : LocalAppearanceRepository(local.settings);
  runApp(
    BardApp(
      composition: await Composition.inProcess(rootBundle, local: local),
      local: local,
      appearance: await ThemeController.load(
        rootBundle,
        initial: await appearance.load(),
        brightness: _platformBrightness(),
        onChanged: (setting) => unawaited(appearance.save(setting)),
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
    this.local,
  });

  /// Injected services.
  final Composition composition;

  /// The player's theme and variant. It outlives a new episode.
  final ThemeController appearance;

  /// This machine's local data; null turns hosting, joining and reports off.
  final LocalData? local;

  @override
  State<BardApp> createState() => _BardAppState();
}

class _BardAppState extends State<BardApp> with WidgetsBindingObserver {
  late Composition _composition = widget.composition;
  late GoRouter _router = _build();

  GoRouter _build() => buildRouter(
    _composition,
    appearance: widget.appearance,
    actions: PlayActions(
      newEpisode: _startNewEpisode,
      host: widget.local == null ? null : _host,
      join: widget.local == null ? null : _join,
      leave: _leave,
    ),
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

  final GlobalKey<ScaffoldMessengerState> _messenger =
      GlobalKey<ScaffoldMessengerState>();
  bool _opening = false;
  Map<String, String>? _packFiles;

  Future<Map<String, String>> _pack() async =>
      _packFiles ??= await loadPackFiles(rootBundle);

  /// One active composition at a time: [open] builds the next one, the old
  /// one is closed, and the router restarts at `/`. If [open] fails, the
  /// current one keeps running and [what] says what did not happen.
  Future<void> _replace(
    String what,
    Future<Composition> Function() open,
  ) async {
    if (_opening) return;
    _opening = true;
    final old = _composition;
    final Composition next;
    try {
      // A host must let go of its port and store before the next one
      // opens them, so the old composition closes first when either side
      // is networked; one-device play swaps without a gap.
      if (old.mode != PlayMode.oneDevice) await old.dispose();
      next = await open();
    } catch (e) {
      _opening = false;
      if (old.mode != PlayMode.oneDevice) {
        // The old one is closed already; fall back to one-device play.
        final fallback = await _oneDevice();
        if (mounted) {
          setState(() {
            _composition = fallback;
            _router = _build();
          });
        }
      }
      if (mounted) {
        _messenger.currentState?.showSnackBar(
          SnackBar(content: Text('Could not $what: $e')),
        );
      }
      return;
    }
    _opening = false;
    setState(() {
      _composition = next;
      _router = _build();
    });
    if (old.mode == PlayMode.oneDevice) await old.dispose();
  }

  Future<Composition> _oneDevice() => Composition.inProcess(
    rootBundle,
    seedDemoAgents: false,
    local: widget.local,
  );

  Future<void> _startNewEpisode() => _replace(
    'start a new episode',
    _composition.mode == PlayMode.host
        ? () async =>
              Composition.host(await _pack(), widget.local!, newEpisode: true)
        : _oneDevice,
  );

  Future<void> _host() => _replace(
    'host',
    () async => Composition.host(await _pack(), widget.local!),
  );

  Future<void> _join(JoinRequest request) => _replace(
    'join',
    () async => Composition.join(
      await _pack(),
      widget.local!,
      info: LanJoinInfo(
        host: request.host,
        port: request.port,
        joinCode: request.joinCode,
      ),
      aliasId: request.aliasId,
    ),
  );

  Future<void> _leave() => _replace('leave', _oneDevice);

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
