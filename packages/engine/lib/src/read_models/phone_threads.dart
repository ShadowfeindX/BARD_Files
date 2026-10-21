/// Phone conversations as a read model over the event log (04 §In-game
/// phone: "just a view over these events").
library;

import '../actor.dart';
import '../events/events.dart';
import '../phone.dart';

/// One message in a conversation, in log order.
final class PhoneEntry {
  /// Creates an entry.
  const PhoneEntry({required this.from, required this.text});

  /// The sender.
  final PhoneParty from;

  /// The message.
  final String text;

  @override
  bool operator ==(Object other) =>
      other is PhoneEntry && other.from == from && other.text == text;

  @override
  int get hashCode => Object.hash(PhoneEntry, from, text);

  @override
  String toString() => 'PhoneEntry($from: $text)';
}

/// The messages between two parties.
final class PhoneConversation {
  /// Creates a conversation.
  PhoneConversation({
    required this.a,
    required this.b,
    required List<PhoneEntry> messages,
  }) : messages = List.unmodifiable(messages);

  /// One party. In a player's view this is always the player's alias.
  final PhoneParty a;

  /// The other party (the counterpart, in a player's view).
  final PhoneParty b;

  /// The messages, oldest first.
  final List<PhoneEntry> messages;
}

/// Groups the phone messages in [log] into conversations, in the order each
/// conversation began.
///
/// With [viewer] null the result is the Handler's view: every conversation,
/// with its parties in the order they first spoke. With a [viewer] alias it is
/// that player's view: only conversations they are part of, with `a` set to
/// the viewer. [log] must already be the events the viewer may see (the
/// session's per-perspective filter); this groups by party, it does not
/// check visibility. A conversation between the same two parties is one thread
/// whichever way a message went.
List<PhoneConversation> phoneConversations(
  Iterable<Event> log, {
  AliasId? viewer,
}) {
  final order = <(PhoneParty, PhoneParty)>[];
  final byPair = <(PhoneParty, PhoneParty), List<PhoneEntry>>{};
  for (final event in log) {
    if (event is! PhoneMessageSent) continue;
    final me = viewer == null ? null : PhoneAlias(viewer);
    if (me != null && event.from != me && event.to != me) continue;
    final other = event.from == me ? event.to : event.from;
    final key = me == null
        ? _existingPair(order, event.from, event.to) ?? (event.from, event.to)
        : (me, other);
    final entries = byPair.putIfAbsent(key, () {
      order.add(key);
      return [];
    });
    entries.add(PhoneEntry(from: event.from, text: event.text));
  }
  return [
    for (final (a, b) in order)
      PhoneConversation(a: a, b: b, messages: byPair[(a, b)]!),
  ];
}

/// The pair already in [order] for [x] and [y], whichever way round.
(PhoneParty, PhoneParty)? _existingPair(
  List<(PhoneParty, PhoneParty)> order,
  PhoneParty x,
  PhoneParty y,
) {
  for (final pair in order) {
    if ((pair.$1 == x && pair.$2 == y) || (pair.$1 == y && pair.$2 == x)) {
      return pair;
    }
  }
  return null;
}
