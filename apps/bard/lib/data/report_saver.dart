import 'dart:io';

import 'package:backend/backend.dart';
import 'package:engine/engine.dart' as engine_lib;
import 'package:flutter/services.dart' show FlutterVersion;
import 'package:protocol/protocol.dart' show JsonMap, protocolMajor;
import 'package:session/session.dart';

/// The app's build version, written to report bundles.
const String appVersion = '0.0.0';

/// Saves report bundles for the running episode (04 §Diagnostics) into the
/// machine's reports folder, for the tester to send by hand.
class ReportSaver {
  /// Creates a saver.
  ///
  /// [settings] gives the settings in force at the time of saving. [notes]
  /// exports the Handler's NPC notes; with none given, a report can never
  /// include notes (a joined player has none).
  ReportSaver({
    required this.episodeId,
    required this.store,
    required this.log,
    required this.folder,
    required this.pack,
    required this.settings,
    this.storeHealth,
    this.notes,
  });

  /// The episode the reports are about.
  final String episodeId;

  /// Where the episode's log and snapshot are read from.
  final EventStore store;

  /// The session's diagnostic log.
  final DiagnosticLog log;

  /// The folder bundles are written into.
  final String folder;

  /// The pack in play, for the pack pin.
  final engine_lib.PackRef pack;

  /// The settings in force (snapshot interval, auto-confirm, transport).
  final Future<Map<String, Object?>> Function() settings;

  /// The store's health, when the store is on disk.
  final Future<JsonMap?> Function()? storeHealth;

  /// The NPC notes export, on the Handler's machine.
  final Future<JsonMap?> Function()? notes;

  /// Whether a report may include the Handler's NPC notes.
  bool get canIncludeNotes => notes != null;

  /// Builds a bundle and writes it. Returns the bundle's folder path.
  /// [includeNotes] adds the NPC notes (the Handler's tick).
  Future<String> save({bool includeNotes = false}) async {
    final bundle = await ReportBundleBuilder.build(
      episodeId: episodeId,
      store: store,
      environment: environment(pack),
      settings: await settings(),
      log: log,
      includeNotes: includeNotes && canIncludeNotes,
      notes: notes,
      storeHealth: storeHealth,
    );
    log.record(DiagnosticCategory.lifecycle, 'report.saved', {
      'includeNotes': includeNotes && canIncludeNotes,
      'files': bundle.files.length,
    });
    final written = await writeReportBundle(bundle, Directory(folder));
    return written.path;
  }

  /// Where and on what this app runs (report item 1).
  static EnvironmentInfo environment(engine_lib.PackRef pack) =>
      EnvironmentInfo(
        appVersion: appVersion,
        engineVersion: engine_lib.engineVersion,
        protocolMajor: protocolMajor,
        os: Platform.operatingSystem,
        osVersion: Platform.operatingSystemVersion,
        flutterVersion: FlutterVersion.version ?? 'unknown',
        dartVersion: Platform.version.split(' ').first,
        packId: pack.id,
        packVersion: pack.version,
        packHash: pack.contentHash,
      );
}
