import 'package:signals_flutter/signals_flutter.dart';

import '../../data/services/npc_notes_service.dart';

/// An NPC the Handler can keep notes on: the pack's id and display name.
class NpcOption {
  /// Creates an option.
  const NpcOption({required this.id, required this.name});

  /// The NPC's id in the pack.
  final String id;

  /// The name shown to the Handler.
  final String name;
}

/// Sends [text] as the NPC [npcId] through the existing phone command.
/// Returns the engine's refusal message, or null on success.
typedef SendAsNpc = Future<String?> Function(String npcId, String text);

/// State and commands for the Handler's NPC notes panel.
///
/// The notes live in [NpcNotesStore] on the Handler's machine and are never
/// events. A prepared message is sent through [sendAs], which the app wires
/// to `SendPhoneMessage(from: entity, ...)`; with no [sendAs] the panel
/// edits notes but cannot send.
class NpcNotesViewModel {
  /// Creates the view model for [campaignId] over [_store].
  NpcNotesViewModel(
    this._store, {
    required this.campaignId,
    required this.npcs,
    this.sendAs,
  });

  final NpcNotesService _store;

  /// The campaign the notes belong to.
  final String campaignId;

  /// The NPCs offered, in display order.
  final List<NpcOption> npcs;

  /// Sends a prepared message as an NPC, or null when sending is not wired.
  final SendAsNpc? sendAs;

  /// The NPC being edited, or null.
  final Signal<String?> selected = signal(null);

  /// The notes of [selected], or null before one is chosen.
  final Signal<NpcNotes?> notes = signal(null);

  /// The last problem (a refusal or a bad entry), or null.
  final Signal<String?> error = signal(null);

  /// Writes and reads run one after another, so a save can never overtake
  /// the load of another NPC.
  Future<void> _queue = Future.value();

  Future<void> _enqueue(Future<void> Function() job) {
    final done = _queue.then((_) => job());
    _queue = done.catchError((Object _) {});
    return done;
  }

  /// Opens the notes for [npcId].
  Future<void> select(String npcId) {
    selected.value = npcId;
    error.value = null;
    notes.value = null;
    return _enqueue(() async {
      try {
        final loaded = await _store.notes(campaignId, npcId);
        if (selected.value == npcId) notes.value = loaded;
      } on Object {
        if (selected.value == npcId) error.value = 'Could not read the notes.';
      }
    });
  }

  /// Saves the free-form text.
  Future<void> saveText(String text) =>
      _apply((id) => _store.setText(campaignId, id, text));

  /// Pins a detail. Returns whether it was kept.
  Future<bool> pin(String detail) =>
      _apply((id) => _store.pin(campaignId, id, detail));

  /// Removes the pinned detail at [index].
  Future<bool> unpin(int index) =>
      _apply((id) => _store.unpin(campaignId, id, index));

  /// Adds a prepared message. Returns whether it was kept.
  Future<bool> addPrepared(String text, {String label = ''}) => _apply(
    (id) => _store.addPrepared(campaignId, id, text: text, label: label),
  );

  /// Deletes a prepared message.
  Future<bool> removePrepared(String messageId) =>
      _apply((id) => _store.removePrepared(campaignId, id, messageId));

  final Set<String> _sending = {};

  /// Sends the prepared message [messageId] as the selected NPC. A message
  /// already on its way is not sent twice.
  Future<void> send(String messageId) async {
    final id = selected.value;
    final send = sendAs;
    final message = notes.value?.prepared
        .where((m) => m.id == messageId)
        .firstOrNull;
    if (id == null || send == null || message == null) return;
    if (!_sending.add('$id/$messageId')) return;
    try {
      final result = await send(id, message.text);
      if (selected.value == id) error.value = result;
    } finally {
      _sending.remove('$id/$messageId');
    }
  }

  Future<bool> _apply(Future<NpcNotes> Function(String npcId) change) async {
    final id = selected.value;
    if (id == null) return false;
    var kept = false;
    await _enqueue(() async {
      String? problem;
      NpcNotes? result;
      try {
        result = await change(id);
      } on ArgumentError catch (e) {
        // RangeError is an ArgumentError too.
        problem = '${e.message ?? 'That entry is not valid.'}';
      } on StateError catch (e) {
        problem = e.message;
      } on Object {
        problem = 'Could not save the notes.';
      }
      // The Handler may have moved to another NPC meanwhile.
      if (selected.value != id) return;
      if (result != null) {
        notes.value = result;
        error.value = null;
        kept = true;
      } else {
        error.value = problem;
      }
    });
    return kept;
  }
}
