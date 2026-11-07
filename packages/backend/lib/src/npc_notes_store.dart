import 'dart:convert';

import 'package:sembast/sembast.dart';

/// The longest prepared message, in UTF-16 code units.
///
/// Mirrors the engine's `maxPhoneTextUnits` (a phone message is 1 to 2,000
/// units). `backend` cannot import the engine, so the number is repeated
/// here and a prepared message is held to it when it is saved, which means
/// "send" never fails on length.
const int maxPreparedMessageUnits = 2000;

/// The row layout this build writes. A row with a higher number was written
/// by a newer build and is never overwritten.
const int npcNotesLayoutVersion = 1;

/// One message the Handler wrote ahead of time for an NPC.
///
/// The Handler console sends it as that NPC through the existing
/// `SendPhoneMessage(from: entity, ...)` command, so it adds no rule. This
/// type only holds the text.
final class PreparedMessage {
  /// Creates a prepared message.
  const PreparedMessage({
    required this.id,
    required this.label,
    required this.text,
  });

  /// Reads one from [json]; throws [FormatException] on a wrong shape.
  factory PreparedMessage.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final label = json['label'];
    final text = json['text'];
    if (id is! String || label is! String || text is! String) {
      throw const FormatException('prepared message: id, label and text');
    }
    if (text.isEmpty || text.length > maxPreparedMessageUnits) {
      throw const FormatException('prepared message: text length');
    }
    return PreparedMessage(id: id, label: label, text: text);
  }

  /// Identifies the message inside its NPC's notes. Unique per NPC, never
  /// reused after a delete.
  final String id;

  /// A short name the Handler sees on the send button. May be empty.
  final String label;

  /// The phone text, 1 to [maxPreparedMessageUnits] UTF-16 units.
  final String text;

  /// The JSON form kept in the store and in an exported report file.
  Map<String, Object?> toJson() => {'id': id, 'label': label, 'text': text};

  @override
  bool operator ==(Object other) =>
      other is PreparedMessage &&
      other.id == id &&
      other.label == label &&
      other.text == text;

  @override
  int get hashCode => Object.hash(id, label, text);
}

/// Everything the Handler keeps on one NPC within one campaign.
final class NpcNotes {
  /// Creates the notes.
  const NpcNotes({
    required this.campaignId,
    required this.npcId,
    this.text = '',
    this.pinned = const [],
    this.prepared = const [],
    this.nextPreparedNumber = 1,
  });

  /// Reads notes from [json]; throws [FormatException] on a wrong shape.
  factory NpcNotes.fromJson(Map<String, Object?> json) {
    final campaignId = json['campaignId'];
    final npcId = json['npcId'];
    final text = json['text'];
    final pinned = json['pinned'];
    final prepared = json['prepared'];
    final next = json['nextPreparedNumber'];
    if (campaignId is! String ||
        npcId is! String ||
        text is! String ||
        pinned is! List ||
        prepared is! List ||
        next is! int) {
      throw const FormatException('npc notes: wrong shape');
    }
    return NpcNotes(
      campaignId: campaignId,
      npcId: npcId,
      text: text,
      pinned: [for (final p in pinned) p as String],
      prepared: [
        for (final m in prepared)
          PreparedMessage.fromJson((m as Map).cast<String, Object?>()),
      ],
      nextPreparedNumber: next,
    );
  }

  /// The campaign the notes belong to.
  final String campaignId;

  /// The NPC's id in the pack (the pack's own data is never edited).
  final String npcId;

  /// Free-form notes.
  final String text;

  /// Important details the Handler pinned, in the order pinned.
  final List<String> pinned;

  /// Messages ready to send as this NPC, in the order written.
  final List<PreparedMessage> prepared;

  /// Source of the next prepared-message id; only ever grows.
  final int nextPreparedNumber;

  /// Whether nothing is written.
  bool get isEmpty => text.isEmpty && pinned.isEmpty && prepared.isEmpty;

  /// The JSON form kept in the store and in an exported report file.
  Map<String, Object?> toJson() => {
    'version': npcNotesLayoutVersion,
    'campaignId': campaignId,
    'npcId': npcId,
    'text': text,
    'pinned': pinned,
    'prepared': [for (final m in prepared) m.toJson()],
    'nextPreparedNumber': nextPreparedNumber,
  };

  /// A copy with the given fields replaced.
  NpcNotes copyWith({
    String? text,
    List<String>? pinned,
    List<PreparedMessage>? prepared,
    int? nextPreparedNumber,
  }) => NpcNotes(
    campaignId: campaignId,
    npcId: npcId,
    text: text ?? this.text,
    pinned: pinned ?? this.pinned,
    prepared: prepared ?? this.prepared,
    nextPreparedNumber: nextPreparedNumber ?? this.nextPreparedNumber,
  );
}

/// The Handler's notes on NPCs, kept in a small sembast database of their
/// own on the Handler's machine, like [HostSettingsStore].
///
/// Notes belong to an NPC within a campaign, so they carry across episodes
/// and missions and survive an episode's clean-up. They are not events: they
/// never enter the game log, never reach the wire or a player's projection,
/// and the pack's NPC data is never touched. A report bundle includes them
/// only when the Handler ticks "include notes": the composer then calls
/// [exportCampaign] and writes the result as one extra file.
///
/// Every change reads and writes inside one transaction, so two quick edits
/// cannot lose each other.
final class NpcNotesStore {
  /// Creates a store over an already opened [database].
  NpcNotesStore(this._db);

  static final _notes = stringMapStoreFactory.store('npcNotes');

  final Database _db;

  /// The notes for [npcId] in [campaignId]; empty notes when none are saved.
  Future<NpcNotes> notes(String campaignId, String npcId) async {
    final row = await _notes.record(_key(campaignId, npcId)).get(_db);
    return _read(row, campaignId, npcId);
  }

  /// Every NPC id in [campaignId] that has something written, sorted.
  /// Unreadable rows are skipped.
  Future<List<String>> npcIdsWithNotes(String campaignId) async {
    final rows = await _notes.find(
      _db,
      finder: Finder(filter: Filter.equals('campaignId', campaignId)),
    );
    return [
      for (final r in rows)
        if (_tryParse(r.value) case final n? when !n.isEmpty) n.npcId,
    ]..sort();
  }

  /// Replaces the free-form text.
  Future<NpcNotes> setText(String campaignId, String npcId, String text) =>
      _edit(campaignId, npcId, (n) => n.copyWith(text: text));

  /// Pins [detail] at the end of the pinned list. Throws [ArgumentError]
  /// when it is empty.
  Future<NpcNotes> pin(String campaignId, String npcId, String detail) async {
    if (detail.trim().isEmpty) {
      throw ArgumentError.value(detail, 'detail', 'must not be empty');
    }
    return await _edit(
      campaignId,
      npcId,
      (n) => n.copyWith(pinned: [...n.pinned, detail]),
    );
  }

  /// Removes the pinned detail at [index]. Throws [RangeError] when there
  /// is none.
  Future<NpcNotes> unpin(String campaignId, String npcId, int index) =>
      _edit(campaignId, npcId, (n) {
        RangeError.checkValidIndex(index, n.pinned, 'index');
        return n.copyWith(pinned: [...n.pinned]..removeAt(index));
      });

  /// Adds a prepared message and returns the notes with it (the new message
  /// is the last of [NpcNotes.prepared]). Throws [ArgumentError] when
  /// [text] is empty or over [maxPreparedMessageUnits].
  Future<NpcNotes> addPrepared(
    String campaignId,
    String npcId, {
    required String text,
    String label = '',
  }) async {
    _checkText(text);
    return await _edit(
      campaignId,
      npcId,
      (n) => n.copyWith(
        prepared: [
          ...n.prepared,
          PreparedMessage(
            id: 'm${n.nextPreparedNumber}',
            label: label,
            text: text,
          ),
        ],
        nextPreparedNumber: n.nextPreparedNumber + 1,
      ),
    );
  }

  /// Changes the label and text of prepared message [messageId]. Throws
  /// [ArgumentError] on bad text and [StateError] when it does not exist.
  Future<NpcNotes> updatePrepared(
    String campaignId,
    String npcId,
    String messageId, {
    required String text,
    String label = '',
  }) async {
    _checkText(text);
    return await _edit(campaignId, npcId, (n) {
      _requireMessage(n, messageId);
      return n.copyWith(
        prepared: [
          for (final m in n.prepared)
            m.id == messageId
                ? PreparedMessage(id: m.id, label: label, text: text)
                : m,
        ],
      );
    });
  }

  /// Deletes prepared message [messageId]. Throws [StateError] when it does
  /// not exist.
  Future<NpcNotes> removePrepared(
    String campaignId,
    String npcId,
    String messageId,
  ) => _edit(campaignId, npcId, (n) {
    _requireMessage(n, messageId);
    return n.copyWith(
      prepared: [
        for (final m in n.prepared)
          if (m.id != messageId) m,
      ],
    );
  });

  /// Deletes all notes on one NPC.
  Future<void> deleteNpc(String campaignId, String npcId) =>
      _notes.record(_key(campaignId, npcId)).delete(_db);

  /// Deletes all notes in [campaignId].
  Future<void> deleteCampaign(String campaignId) => _notes.delete(
    _db,
    finder: Finder(filter: Filter.equals('campaignId', campaignId)),
  );

  /// All notes in [campaignId] as one JSON-ready map, for the "include
  /// notes" option of a report bundle. Sorted by NPC id so the file is
  /// stable.
  Future<Map<String, Object?>> exportCampaign(String campaignId) async {
    final rows = await _notes.find(
      _db,
      finder: Finder(
        filter: Filter.equals('campaignId', campaignId),
        sortOrders: [SortOrder('npcId')],
      ),
    );
    return {
      'campaignId': campaignId,
      'npcs': [
        for (final r in rows)
          if (_tryParse(r.value) case final n? when !n.isEmpty) n.toJson(),
      ],
    };
  }

  /// [exportCampaign] encoded as JSON text.
  Future<String> exportCampaignJson(String campaignId) async =>
      const JsonEncoder.withIndent('  ')
          .convert(await exportCampaign(campaignId));

  Future<NpcNotes> _edit(
    String campaignId,
    String npcId,
    NpcNotes Function(NpcNotes) change,
  ) => _db.transaction((txn) async {
    final record = _notes.record(_key(campaignId, npcId));
    final row = await record.get(txn);
    final version = row?['version'];
    if (version is int && version > npcNotesLayoutVersion) {
      throw StateError(
        'notes for $npcId were written by a newer build (layout $version)',
      );
    }
    final updated = change(_read(row, campaignId, npcId));
    await record.put(txn, updated.toJson());
    return updated;
  });

  /// Reads a stored row; a row this build cannot read counts as no notes
  /// rather than crashing the console. [_edit] refuses to overwrite a row
  /// from a newer build.
  NpcNotes _read(Map<String, Object?>? row, String campaignId, String npcId) {
    return (row == null ? null : _tryParse(row)) ??
        NpcNotes(campaignId: campaignId, npcId: npcId);
  }

  /// The notes in [row], or null when it cannot be read.
  NpcNotes? _tryParse(Map<String, Object?> row) {
    try {
      return NpcNotes.fromJson(row.cast<String, Object?>());
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  void _checkText(String text) {
    if (text.isEmpty || text.length > maxPreparedMessageUnits) {
      throw ArgumentError.value(
        text.length,
        'text',
        'a prepared message is 1 to $maxPreparedMessageUnits UTF-16 units',
      );
    }
  }

  void _requireMessage(NpcNotes notes, String messageId) {
    if (!notes.prepared.any((m) => m.id == messageId)) {
      throw StateError('no prepared message $messageId');
    }
  }

  /// An unambiguous key for any campaign and NPC id.
  static String _key(String campaignId, String npcId) =>
      jsonEncode([campaignId, npcId]);
}
