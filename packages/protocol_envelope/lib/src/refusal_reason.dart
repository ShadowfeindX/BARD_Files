/// Why a GM refused a `hello` (machine readable; the UI words it).
enum RefusalReason {
  /// The client's protocol major differs from the GM's.
  protocolMismatch('protocolMismatch'),

  /// The client's engine major differs from the operation's.
  engineMajorMismatch('engineMajorMismatch'),

  /// Same engine major, but older than the version the log requires.
  updateRequired('updateRequired'),

  /// The agent is not invited to this operation.
  notInvited('notInvited'),

  /// The alias is locked to another campaign or operation.
  aliasLocked('aliasLocked'),

  /// The agent is banned from this operation.
  banned('banned'),

  /// Proposed (06 §Account model, anonymous one-alias rule, Session): an anonymous agent
  /// presented a second alias.
  anonymousAliasLimit('anonymousAliasLimit'),

  /// Decode only: a reason added by a newer minor. The negotiation functions
  /// never produce it.
  unknown('unknown');

  const RefusalReason(this.wire);

  /// The string used on the wire.
  final String wire;

  /// Maps a wire string to a reason; unrecognized strings give [unknown].
  static RefusalReason fromWire(String wire) {
    for (final reason in values) {
      if (reason.wire == wire) return reason;
    }
    return unknown;
  }
}
