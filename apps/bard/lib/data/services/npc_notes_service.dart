import 'package:backend/backend.dart';

export 'package:backend/backend.dart'
    show NpcNotes, PreparedMessage, maxPreparedMessageUnits;

/// The Handler's NPC notes for the UI: a thin face over [NpcNotesStore], so
/// view models do not reach the `backend` package directly (07 §Layering).
///
/// Notes are Handler-only data on this machine; nothing here touches the
/// episode, the wire or the pack.
class NpcNotesService {
  /// Creates the service over [_store].
  NpcNotesService(this._store);

  final NpcNotesStore _store;

  /// The notes for [npcId] in [campaignId].
  Future<NpcNotes> notes(String campaignId, String npcId) =>
      _store.notes(campaignId, npcId);

  /// Replaces the free text.
  Future<NpcNotes> setText(String campaignId, String npcId, String text) =>
      _store.setText(campaignId, npcId, text);

  /// Pins a detail.
  Future<NpcNotes> pin(String campaignId, String npcId, String detail) =>
      _store.pin(campaignId, npcId, detail);

  /// Removes the pinned detail at [index].
  Future<NpcNotes> unpin(String campaignId, String npcId, int index) =>
      _store.unpin(campaignId, npcId, index);

  /// Adds a prepared message.
  Future<NpcNotes> addPrepared(
    String campaignId,
    String npcId, {
    required String text,
    String label = '',
  }) => _store.addPrepared(campaignId, npcId, text: text, label: label);

  /// Deletes a prepared message.
  Future<NpcNotes> removePrepared(
    String campaignId,
    String npcId,
    String messageId,
  ) => _store.removePrepared(campaignId, npcId, messageId);
}
