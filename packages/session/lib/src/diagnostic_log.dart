// ignore_for_file: prefer_initializing_formals
// (private named parameters cannot be initializing formals)
import 'dart:convert';
import 'dart:math';

import 'clock.dart';

/// What part of a session an entry describes. Report bundles split the log
/// by category (network trace, recent errors).
enum DiagnosticCategory {
  /// A host or participant opening, resuming or closing.
  lifecycle,

  /// Connect, disconnect, resync and gap events. Seqs only, never contents.
  network,

  /// A request decided, or a batch confirmed or committed.
  request,

  /// The store failed.
  store,

  /// A malformed frame, a refusal, a rejection or an exception.
  error,
}

/// One line of the diagnostic log.
final class DiagnosticEntry {
  /// Creates an entry. Use [DiagnosticLog.record], which redacts [fields].
  const DiagnosticEntry({
    required this.index,
    required this.time,
    required this.category,
    required this.kind,
    this.fields = const {},
  });

  /// Position in the log, from 1.
  final int index;

  /// When it was recorded.
  final DateTime time;

  /// The part of the session it describes.
  final DiagnosticCategory category;

  /// A short dotted name such as `hello.joined`.
  final String kind;

  /// Redacted values: null, bool, num, String, or a list of those.
  final Map<String, Object?> fields;

  /// The JSON object written to the log file and the report bundle.
  Map<String, Object?> toJson() => {
    'i': index,
    't': time.toUtc().toIso8601String(),
    'category': category.name,
    'kind': kind,
    if (fields.isNotEmpty) 'fields': fields,
  };

  /// This entry as one line of a `.jsonl` file.
  String toJsonLine() => jsonEncode(toJson());
}

/// Receives every entry as it is recorded, for example to append it to a
/// file so the log survives a crash.
abstract interface class DiagnosticSink {
  /// Called once per entry, in order. Must not throw.
  void write(DiagnosticEntry entry);
}

/// Removes what a diagnostic log must never hold (04 §Diagnostics): message
/// text, notes, secrets, and real identifiers.
///
/// The rules are by field name, so a call point cannot leak by accident:
///
/// * [hiddenKeys] (text, notes, codes, tokens) become `[redacted]`.
/// * [idKeys] (agents, aliases, requests) become a stable pseudonym such as
///   `agent-3fa9c1d2`. The same value gives the same pseudonym inside one
///   log, so a report can still be followed, but it cannot be read back.
/// * Any other string is cut to [maxStringLength] characters.
final class Redactor {
  /// Creates a redactor. [salt] makes pseudonyms differ between logs; leave
  /// it out for a random one, pass one in tests.
  Redactor({String? salt}) : _salt = salt ?? _randomSalt();

  final String _salt;

  /// Field names whose value is never kept.
  static const Set<String> hiddenKeys = {
    'text',
    'message',
    'body',
    'note',
    'notes',
    'name',
    'proof',
    'authProof',
    'token',
    'code',
    'joinCode',
    'password',
    'address',
  };

  /// Field names holding an identifier, kept as a pseudonym.
  static const Set<String> idKeys = {
    'agentId',
    'aliasId',
    'requestId',
    'entityId',
    'from',
  };

  /// Longest free string kept.
  static const int maxStringLength = 80;

  /// The replacement for a hidden value.
  static const String hidden = '[redacted]';

  /// A stable, unreadable stand-in for [value].
  String pseudonym(String prefix, String value) {
    // 32-bit FNV-1a: enough to tell identifiers apart, nothing more.
    var h = 0x811c9dc5;
    for (final unit in '$_salt|$value'.codeUnits) {
      h = ((h ^ unit) * 0x01000193) & 0xffffffff;
    }
    return '$prefix-${h.toRadixString(16).padLeft(8, '0')}';
  }

  /// [fields] with every value made safe to keep.
  Map<String, Object?> redactMap(Map<String, Object?> fields) => {
    for (final e in fields.entries) e.key: redact(e.key, e.value),
  };

  /// [value] as it may be kept under [key].
  Object? redact(String key, Object? value) {
    if (hiddenKeys.contains(key)) return value == null ? null : hidden;
    if (value == null || value is bool || value is num) return value;
    if (value is String) {
      if (idKeys.contains(key)) {
        return pseudonym(key.replaceAll(RegExp('Id\$'), ''), value);
      }
      return value.length <= maxStringLength
          ? value
          : '${value.substring(0, maxStringLength)}…';
    }
    if (value is Iterable) {
      return [for (final v in value) redact(key, v)];
    }
    // Anything else (an object, a map) could hold contents.
    return '[unsupported:${value.runtimeType}]';
  }

  static String _randomSalt() {
    final random = Random.secure();
    return List.generate(
      8,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

/// The session layer's diagnostic log (04 §Diagnostics): what the actors did,
/// in order, kept apart from the game log.
///
/// It records facts about the machinery (a link opened, a gap at seq 12, a
/// batch committed), never what players or the Handler wrote. Every entry's
/// fields pass through the [redactor] first. The log keeps everything for the
/// life of the process; a [DiagnosticSink] writes it to disk as it grows.
final class DiagnosticLog {
  /// Creates a log. [sinks] hear every entry as it is recorded.
  DiagnosticLog({
    Clock clock = const SystemClock(),
    Redactor? redactor,
    List<DiagnosticSink> sinks = const [],
  }) : _clock = clock,
       redactor = redactor ?? Redactor(),
       _sinks = List.of(sinks);

  final Clock _clock;
  final List<DiagnosticSink> _sinks;
  final List<DiagnosticEntry> _entries = [];

  /// Applied to every entry's fields, and to settings in a report bundle.
  final Redactor redactor;

  /// Every entry so far, in order.
  List<DiagnosticEntry> get entries => List.unmodifiable(_entries);

  /// Adds [sink]; it hears entries recorded from now on.
  void addSink(DiagnosticSink sink) => _sinks.add(sink);

  /// Records one entry. [fields] are redacted before they are kept.
  void record(
    DiagnosticCategory category,
    String kind, [
    Map<String, Object?> fields = const {},
  ]) {
    final entry = DiagnosticEntry(
      index: _entries.length + 1,
      time: _clock.now(),
      category: category,
      kind: kind,
      fields: redactor.redactMap(fields),
    );
    _entries.add(entry);
    for (final sink in _sinks) {
      try {
        sink.write(entry);
      } on Object {
        // A broken sink must never break play or hide the error being logged.
      }
    }
  }

  /// The entries of the given [categories], in order.
  List<DiagnosticEntry> where(Set<DiagnosticCategory> categories) => [
    for (final e in _entries)
      if (categories.contains(e.category)) e,
  ];
}
