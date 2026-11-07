import 'dart:async';

import 'package:engine/engine.dart' as engine_lib;
import 'package:engine/engine.dart' show Command, Engine, EpisodeState;
import 'package:protocol/protocol.dart' hide Rejected;
import 'package:protocol/protocol.dart' as wire show Rejected;

import 'entries.dart';
import 'connection_actor.dart';
import 'diagnostic_log.dart';
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

/// A player's side of an episode (04 §Participants): a non-canonical
/// engine fed by the events the GM sends.
///
/// It never applies its own guess to state: a request changes nothing until
/// the GM's events come back. Pending requests are kept and sent again after
/// a reconnect; the GM deduplicates by request id, so a retry never decides
/// twice.
final class EpisodeParticipant {
  /// Creates a participant for [agentId], playing [aliasId].
  EpisodeParticipant({
    required this.episodeId,
    required this.agentId,
    required this.aliasId,
    required this.engine,
    required this.codec,
    this.authProof,
    this.anonymous = false,
    this.engineVersion = engine_lib.engineVersion,
    String? sessionTag,
    this.diagnostics,
    this.liveness,
  }) : _sessionTag =
           sessionTag ??
           DateTime.now().microsecondsSinceEpoch.toRadixString(36),
       _feed = PerspectiveFeed(engine);

  /// The episode to join.
  final String episodeId;

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

  /// Where this participant notes what it did (04 §Diagnostics), or null.
  /// Records facts about the link and the sequence only, never contents.
  final DiagnosticLog? diagnostics;

  /// Ping policy for each link, or null to send no pings. With a policy, a
  /// host that stays silent past its timeout has its link closed, which ends
  /// [linkDone].
  final Liveness? liveness;

  /// Makes request ids unique across restarts of this participant; the host
  /// remembers ids per agent, so a restarted counter would collide.
  final String _sessionTag;

  final PerspectiveFeed _feed;
  final Mailbox _mailbox = Mailbox();
  final Map<String, JsonMap> _pending = {};
  final StreamController<EpisodeState> _states =
      StreamController<EpisodeState>.broadcast();
  final StreamController<RequestRejected> _rejections =
      StreamController<RequestRejected>.broadcast();
  final StreamController<List<EventEntry>> _entries =
      StreamController<List<EventEntry>>.broadcast();
  ConnectionActor? _connection;
  Completer<bool> _linkDone = Completer<bool>()..complete(false);
  int _requestCounter = 0;
  int? _resyncFrom;

  /// The state built from what this alias may see.
  EpisodeState get state => _feed.state;

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

  /// Completes when the current link ends: closed by either side, silent
  /// past the [liveness] timeout, or dropped after a malformed `welcome` or
  /// `refused`. The value is true when the host had welcomed this
  /// participant on that link. A reconnect loop waits on it.
  Future<bool> get linkDone => _linkDone.future;

  /// Emits the new state after each applied batch.
  Stream<EpisodeState> get states => _states.stream;

  /// Requests the GM refused.
  Stream<RequestRejected> get rejections => _rejections.stream;

  /// Emits the entries of each applied batch that were new, in `seq` order,
  /// just before [states] emits: a participant's app builds its log from
  /// them (the host sends events, never text).
  Stream<List<EventEntry>> get entries => _entries.stream;

  /// Connects over [link] and sends `hello` with the last `seq` held.
  Future<void> connect(Link link) => _mailbox.run(() async {
    await _connection?.close();
    _joined = false;
    refusal = null;
    final connection = ConnectionActor(
      link,
      onMalformed: (e) => diagnostics?.record(
        DiagnosticCategory.error,
        'protocol.error',
        {'type': e.runtimeType.toString()},
      ),
    );
    _connection = connection;
    final done = Completer<bool>();
    _linkDone = done;
    diagnostics?.record(DiagnosticCategory.network, 'link.connecting', {
      'lastSeq': _feed.lastSeq,
      'pending': _pending.length,
    });
    // Both handlers go through the mailbox, so the end of a link is seen
    // after every envelope it delivered, and an envelope from a link that a
    // later connect replaced is ignored.
    connection.envelopes.listen(
      (envelope) => unawaited(
        _mailbox
            .run(() async {
              if (identical(_connection, connection)) {
                await _onEnvelope(envelope);
              }
            })
            .catchError(_onHandlerError),
      ),
      onDone: () => unawaited(
        _mailbox.run(() {
          final current = identical(_connection, connection);
          final wasJoined = current && _joined;
          if (current) _joined = false;
          diagnostics?.record(DiagnosticCategory.network, 'link.closed', {
            'wasJoined': wasJoined,
            'lastSeq': _feed.lastSeq,
          });
          if (!done.isCompleted) done.complete(wasJoined);
        }),
      ),
    );
    final policy = liveness;
    if (policy != null) {
      connection.keepAlive(
        policy,
        envelopeFor: _envelope,
        onDead: () => diagnostics?.record(
          DiagnosticCategory.network,
          'link.timeout',
          {'lastSeq': _feed.lastSeq},
        ),
      );
    }
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
  ///
  /// Throws [ArgumentError] when the request would not fit in one frame
  /// ([maxFrameLength]); nothing is queued then.
  Future<String> request(Command command) => _mailbox.run(() async {
    final id = '$agentId-$_sessionTag-${++_requestCounter}';
    final json = codec.encodeCommand(command);
    // Checked here, not at send time, so a request that can never be sent is
    // not queued and retried on every welcome.
    const JsonEnvelopeCodec().encode(
      Envelope.of(
        Request(requestId: id, command: json),
        engineVersion: EngineVersion.parse(engineVersion),
        episodeId: episodeId,
        from: aliasId,
      ),
    );
    _pending[id] = json;
    if (_joined) await _sendRequest(id);
    return id;
  });

  /// Closes the link.
  Future<void> close() => _mailbox.run(() async {
    await _connection?.close();
    await _states.close();
    await _rejections.close();
    await _entries.close();
  });

  Future<void> _onEnvelope(Envelope envelope) async {
    try {
      switch (envelope.message) {
        case Welcome():
          _joined = true;
          diagnostics?.record(DiagnosticCategory.network, 'hello.welcomed', {
            'lastSeq': _feed.lastSeq,
            'resending': _pending.length,
          });
          for (final id in _pending.keys.toList()) {
            await _sendRequest(id);
          }
        case Events(:final events):
          _applyFrame(events);
          if (_resyncFrom != null) await _requestResync();
        case final Refused refused:
          final reason = refused.reason;
          refusal = refused;
          diagnostics?.record(DiagnosticCategory.error, 'hello.refused', {
            'reason': reason.name,
          });
          // Nothing more can happen on a refused link.
          await _connection?.close();
        case wire.Rejected(:final requestId, :final code, :final message):
          _pending.remove(requestId);
          diagnostics?.record(DiagnosticCategory.error, 'request.rejected', {
            'requestId': requestId,
            'reason': code,
          });
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
    } on ProtocolFormatException catch (e) {
      diagnostics?.record(DiagnosticCategory.error, 'protocol.error', {
        'type': e.runtimeType.toString(),
        'lastSeq': _feed.lastSeq,
      });
      final type = envelope.messageType;
      if (type == MessageType.welcome || type == MessageType.refused) {
        // The handshake failed: a resync cannot help before a welcome, and a
        // refusal we cannot read must not look like a join. Drop the link so
        // the reconnect loop tries again after its backoff.
        diagnostics?.record(DiagnosticCategory.error, 'hello.malformed', {
          'type': envelope.type,
        });
        _joined = false;
        await _connection?.close();
        return;
      }
      // A malformed host frame changes nothing; resync recovers any loss.
      await _requestResync(force: true);
    }
  }

  /// Records a handler failure that is not a [ProtocolFormatException]
  /// (for example, an event the local engine cannot apply), so it never
  /// becomes an unhandled async error.
  void _onHandlerError(Object error) => diagnostics?.record(
    DiagnosticCategory.error,
    'participant.error',
    {'type': error.runtimeType.toString(), 'lastSeq': _feed.lastSeq},
  );

  void _applyFrame(List<JsonMap> events) {
    final entries = [for (final e in events) EventEntry.fromJson(e, codec)];
    final before = _feed.lastSeq;
    final result = _feed.apply(entries);
    switch (result) {
      case FeedResult.applied:
        _entries.add([
          for (final e in entries)
            if (e.seq > before) e,
        ]);
        _resyncFrom = null;
        for (final entry in entries) {
          final id = entry.requestId;
          if (id != null) _pending.remove(id);
        }
        _states.add(_feed.state);
      case FeedResult.duplicate:
        break;
      case FeedResult.gap:
        diagnostics?.record(DiagnosticCategory.network, 'gap.detected', {
          'lastSeq': _feed.lastSeq,
          'firstReceivedSeq': entries.isEmpty ? null : entries.first.seq,
        });
        _resyncFrom = _feed.lastSeq;
    }
  }

  Future<void> _requestResync({bool force = false}) async {
    final from = _resyncFrom ?? _feed.lastSeq;
    _resyncFrom = null;
    if (!force && _feed.lastSeq != from) return;
    diagnostics?.record(DiagnosticCategory.network, 'resync.requested', {
      'lastSeq': _feed.lastSeq,
      'forced': force,
    });
    await _send(Resync(_feed.lastSeq));
  }

  Future<void> _sendRequest(String id) =>
      _send(Request(requestId: id, command: _pending[id]!));

  Envelope _envelope(Message message) => Envelope.of(
    message,
    engineVersion: EngineVersion.parse(engineVersion),
    episodeId: episodeId,
    from: aliasId,
  );

  Future<void> _send(Message message) async {
    final connection = _connection;
    if (connection == null) return;
    try {
      await connection.send(_envelope(message));
    } on StateError {
      diagnostics?.record(DiagnosticCategory.network, 'link.lost', {
        'wasJoined': _joined,
        'lastSeq': _feed.lastSeq,
      });
      _joined = false;
    }
  }
}
