import 'dart:async';

import 'package:engine/engine.dart' as engine_lib;
import 'package:engine/engine.dart' show Command, Engine, OperationState;
import 'package:protocol/protocol.dart' hide Rejected;
import 'package:protocol/protocol.dart' as wire show Rejected;

import 'entries.dart';
import 'connection_actor.dart';
import 'mailbox.dart';
import 'transport.dart';

/// A request the GM refused, as the participant hears it.
final class RequestRejected {
  /// Creates the notice.
  const RequestRejected(this.requestId, this.code, this.message);

  /// The refused request.
  final String requestId;

  /// Machine-readable code.
  final String code;

  /// Readable explanation, or null.
  final String? message;
}

/// A player's side of an operation (04 §Participants): a non-canonical
/// engine fed by the events the GM sends.
///
/// It never applies its own guess to state: a request changes nothing until
/// the GM's events come back. Pending requests are kept and sent again after
/// a reconnect; the GM deduplicates by request id, so a retry never decides
/// twice.
final class OperationParticipant {
  /// Creates a participant for [agentId], playing [aliasId].
  OperationParticipant({
    required this.operationId,
    required this.agentId,
    required this.aliasId,
    required this.engine,
    required this.codec,
    this.authProof,
    this.anonymous = false,
    this.engineVersion = engine_lib.engineVersion,
    String? sessionTag,
  }) : _sessionTag =
           sessionTag ??
           DateTime.now().microsecondsSinceEpoch.toRadixString(36),
       _feed = PerspectiveFeed(engine);

  /// The operation to join.
  final String operationId;

  /// The agent (account profile).
  final String agentId;

  /// The alias this agent plays.
  final String aliasId;

  /// The local, non-canonical engine.
  final Engine engine;

  /// The engine codec.
  final EngineCodec codec;

  /// Proof of identity for the host's verifier, if any.
  final String? authProof;

  /// Whether this agent is an anonymous guest (advisory: the host decides).
  final bool anonymous;

  /// This client's engine version, sent in every envelope.
  final String engineVersion;

  /// Makes request ids unique across restarts of this participant; the host
  /// remembers ids per agent, so a restarted counter would collide.
  final String _sessionTag;

  final PerspectiveFeed _feed;
  final Mailbox _mailbox = Mailbox();
  final Map<String, JsonMap> _pending = {};
  final StreamController<OperationState> _states =
      StreamController<OperationState>.broadcast();
  final StreamController<RequestRejected> _rejections =
      StreamController<RequestRejected>.broadcast();
  ConnectionActor? _connection;
  int _requestCounter = 0;
  int? _resyncFrom;

  /// The state built from what this alias may see.
  OperationState get state => _feed.state;

  /// The last `seq` applied (readable or not).
  int get lastSeq => _feed.lastSeq;

  /// Sequence numbers received but not readable (redacted or hidden).
  List<int> get opaqueSeqs => _feed.opaqueSeqs;

  /// Requests sent and not yet answered by a refusal or by the events they
  /// caused. For a "sent" spinner only.
  Set<String> get pendingRequests => Set.unmodifiable(_pending.keys);

  /// The host's reason for refusing the `hello`, if it did.
  Refused? refusal;

  /// Whether the host has accepted this participant on the current link.
  bool get joined => _joined;
  bool _joined = false;

  /// Emits the new state after each applied batch.
  Stream<OperationState> get states => _states.stream;

  /// Requests the GM refused.
  Stream<RequestRejected> get rejections => _rejections.stream;

  /// Connects over [link] and sends `hello` with the last `seq` held.
  Future<void> connect(Link link) => _mailbox.run(() async {
    await _connection?.close();
    _joined = false;
    refusal = null;
    final connection = ConnectionActor(link);
    _connection = connection;
    connection.envelopes.listen(
      (envelope) => _mailbox.run(() => _onEnvelope(envelope)),
    );
    await _send(
      Hello(
        agentId: agentId,
        aliasId: aliasId,
        kind: anonymous ? AgentKind.anonymous : AgentKind.full,
        authProof: authProof,
        lastSeq: _feed.lastSeq,
      ),
    );
  });

  /// Sends [command] as a request and returns its id.
  Future<String> request(Command command) => _mailbox.run(() async {
    final id = '$agentId-$_sessionTag-${++_requestCounter}';
    _pending[id] = codec.encodeCommand(command);
    if (_joined) await _sendRequest(id);
    return id;
  });

  /// Closes the link.
  Future<void> close() => _mailbox.run(() async {
    await _connection?.close();
    await _states.close();
    await _rejections.close();
  });

  Future<void> _onEnvelope(Envelope envelope) async {
    try {
      switch (envelope.message) {
        case Welcome():
          _joined = true;
          for (final id in _pending.keys.toList()) {
            await _sendRequest(id);
          }
        case Events(:final events):
          _applyFrame(events);
          if (_resyncFrom != null) await _requestResync();
        case Refused():
          refusal = envelope.message as Refused;
        case wire.Rejected(:final requestId, :final code, :final message):
          _pending.remove(requestId);
          _rejections.add(RequestRejected(requestId, code, message));
        case Ping(:final nonce):
          await _send(Pong(nonce: nonce));
        case Hello() ||
            Request() ||
            Resync() ||
            TextLog() ||
            Presence() ||
            Pong():
          break;
      }
    } on ProtocolFormatException {
      // A malformed host frame changes nothing; resync recovers any loss.
      await _requestResync(force: true);
    }
  }

  void _applyFrame(List<JsonMap> events) {
    final entries = [for (final e in events) EventEntry.fromJson(e, codec)];
    final result = _feed.apply(entries);
    switch (result) {
      case FeedResult.applied:
        _resyncFrom = null;
        for (final entry in entries) {
          final id = entry.requestId;
          if (id != null) _pending.remove(id);
        }
        _states.add(_feed.state);
      case FeedResult.duplicate:
        break;
      case FeedResult.gap:
        _resyncFrom = _feed.lastSeq;
    }
  }

  Future<void> _requestResync({bool force = false}) async {
    final from = _resyncFrom ?? _feed.lastSeq;
    _resyncFrom = null;
    if (!force && _feed.lastSeq != from) return;
    await _send(Resync(_feed.lastSeq));
  }

  Future<void> _sendRequest(String id) =>
      _send(Request(requestId: id, command: _pending[id]!));

  Future<void> _send(Message message) async {
    final connection = _connection;
    if (connection == null) return;
    try {
      await connection.send(
        Envelope.of(
          message,
          engineVersion: EngineVersion.parse(engineVersion),
          operationId: operationId,
          from: aliasId,
        ),
      );
    } on StateError {
      _joined = false;
    }
  }
}
