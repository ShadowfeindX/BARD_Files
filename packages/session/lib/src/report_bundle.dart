import 'dart:convert';

import 'package:protocol/protocol.dart';

import 'clock.dart';
import 'diagnostic_log.dart';
import 'event_store.dart';

/// Where and on what a session ran (report item 1).
final class EnvironmentInfo {
  /// Creates the description.
  const EnvironmentInfo({
    required this.appVersion,
    required this.engineVersion,
    required this.protocolMajor,
    required this.os,
    required this.osVersion,
    required this.flutterVersion,
    required this.dartVersion,
    this.packId,
    this.packVersion,
    this.packHash,
  });

  /// The app build.
  final String appVersion;

  /// The engine build.
  final String engineVersion;

  /// The wire protocol major.
  final int protocolMajor;

  /// Operating system name, such as `windows` or `linux`.
  final String os;

  /// Operating system version string.
  final String osVersion;

  /// Flutter version the app was built with.
  final String flutterVersion;

  /// Dart version the app was built with.
  final String dartVersion;

  /// The pack in play: id, version and content hash (the pack pin).
  final String? packId;

  /// See [packId].
  final String? packVersion;

  /// See [packId].
  final String? packHash;

  /// The JSON written to `environment.json`.
  JsonMap toJson() => {
    'appVersion': appVersion,
    'engineVersion': engineVersion,
    'protocolMajor': protocolMajor,
    'os': os,
    'osVersion': osVersion,
    'flutterVersion': flutterVersion,
    'dartVersion': dartVersion,
    'pack': {'id': packId, 'version': packVersion, 'contentHash': packHash},
  };
}

/// A saved report (04 §Diagnostics): a set of files, each its own kind of
/// log, that lets us reproduce a problem from the tester's session.
///
/// The files are kept apart on purpose (R, 2026-11-06): the game log, the
/// diagnostic log, the network trace and the recent errors are never merged.
/// The bundle is plain data; `backend` writes it into a folder the tester
/// sends by hand.
final class ReportBundle {
  /// Creates a bundle from named file contents.
  const ReportBundle({
    required this.episodeId,
    required this.createdAt,
    required this.files,
  });

  /// The episode the report is about.
  final String episodeId;

  /// When the report was saved.
  final DateTime createdAt;

  /// File name to file text. Names are fixed (see [ReportBundleBuilder]).
  final Map<String, String> files;

  /// A folder name for this bundle that is safe on Windows and Linux.
  String get folderName {
    final stamp = createdAt
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[-:]'), '')
        .split('.')
        .first;
    final id = episodeId.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    return 'bard-report-$id-$stamp';
  }
}

/// Assembles a [ReportBundle] from a finished or running session.
///
/// Files, in order of the report list R approved:
///
/// * `environment.json` (item 1)
/// * `settings.json` (item 2)
/// * `diagnostic-log.jsonl` (item 3): the whole diagnostic log
/// * `network-trace.jsonl` (item 4): network entries only
/// * `recent-errors.jsonl` (item 6): the last [recentErrorLimit] errors
/// * `store-health.json`: when a [storeHealth] provider is given
/// * `game-log.jsonl`, `text-log.jsonl`, `snapshot.json`: from the store
/// * `notes.json`: only when the Handler ticked "include notes"
/// * `manifest.json`: what is in the bundle and why
abstract final class ReportBundleBuilder {
  /// The version of this layout, written to the manifest.
  static const int formatVersion = 1;

  /// Builds the bundle for [episodeId].
  ///
  /// [settings] are the values in force (snapshot interval, auto-confirm,
  /// transport); they pass through the log's redactor, which hides only
  /// [Redactor.hiddenKeys]: pass a host address under `address`. [storeHealth] and
  /// [notes] are providers so that nothing is read unless it is wanted:
  /// [notes] (Handler-written text) is called only when [includeNotes] is
  /// true, and is otherwise never touched.
  static Future<ReportBundle> build({
    required String episodeId,
    required EventStore store,
    required EnvironmentInfo environment,
    required Map<String, Object?> settings,
    required DiagnosticLog log,
    Clock clock = const SystemClock(),
    int recentErrorLimit = 50,
    bool includeNotes = false,
    Future<JsonMap?> Function()? notes,
    Future<JsonMap?> Function()? storeHealth,
  }) async {
    final now = clock.now();
    final files = <String, String>{};

    files['environment.json'] = _pretty(environment.toJson());
    files['settings.json'] = _pretty(log.redactor.redactMap(settings));
    files['diagnostic-log.jsonl'] = _lines(log.entries.map((e) => e.toJson()));
    files['network-trace.jsonl'] = _lines(
      log.where({DiagnosticCategory.network}).map((e) => e.toJson()),
    );
    final errors = log.where({
      DiagnosticCategory.error,
      DiagnosticCategory.store,
    });
    files['recent-errors.jsonl'] = _lines(
      errors
          .skip(
            errors.length > recentErrorLimit
                ? errors.length - recentErrorLimit
                : 0,
          )
          .map((e) => e.toJson()),
    );

    final health = storeHealth == null ? null : await storeHealth();
    if (health != null) files['store-health.json'] = _pretty(health);

    final events = await store.read(episodeId).toList();
    files['game-log.jsonl'] = _lines(
      events.map(
        (e) => {
          'seq': e.seq,
          'time': e.time.toUtc().toIso8601String(),
          'engineVersion': e.engineVersion,
          'event': e.event,
          if (e.agentId != null) 'agentId': e.agentId,
          if (e.requestId != null) 'requestId': e.requestId,
        },
      ),
    );
    final text = await store.readText(episodeId).toList();
    files['text-log.jsonl'] = _lines(
      text.map(
        (l) => {
          'seq': l.seq,
          'time': l.time.toUtc().toIso8601String(),
          'variants': l.variants,
        },
      ),
    );
    final head = await store.headSnapshot(episodeId);
    final draws = await store.rngDrawCount(episodeId);
    if (head != null) {
      files['snapshot.json'] = _pretty({
        'seq': head.seq,
        'rngDrawCount': head.rngDrawCount,
        'nextEntityNumber': head.nextEntityNumber,
        'savedRngDrawCount': draws,
        'state': head.state,
      });
    }

    var notesIncluded = false;
    if (includeNotes && notes != null) {
      final body = await notes();
      if (body != null) {
        files['notes.json'] = _pretty(body);
        notesIncluded = true;
      }
    }

    files['manifest.json'] = _pretty({
      'formatVersion': formatVersion,
      'episodeId': episodeId,
      'createdAt': now.toUtc().toIso8601String(),
      'files': [...files.keys, 'manifest.json']..sort(),
      'gameLog': {'events': events.length, 'lastSeq': head?.seq ?? 0},
      'diagnosticEntries': log.entries.length,
      'notesRequested': includeNotes,
      'notesIncluded': notesIncluded,
    });

    return ReportBundle(episodeId: episodeId, createdAt: now, files: files);
  }

  static String _pretty(Object? json) =>
      '${const JsonEncoder.withIndent('  ').convert(json)}\n';

  static String _lines(Iterable<Object?> items) {
    final out = StringBuffer();
    for (final item in items) {
      out.writeln(jsonEncode(item));
    }
    return out.toString();
  }
}
