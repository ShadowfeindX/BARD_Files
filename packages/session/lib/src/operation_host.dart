// ignore_for_file: prefer_initializing_formals
// (private named parameters cannot be initializing formals)
import 'dart:async';

import 'package:engine/engine.dart' as engine_lib;
import 'package:engine/engine.dart' hide engineVersion;
import 'package:protocol/protocol.dart' hide Rejected;
import 'package:protocol/protocol.dart' as wire show PackPin, Rejected;

import 'authorizer.dart';
import 'clock.dart';
import 'connection_actor.dart';
import 'entries.dart';
import 'event_store.dart';
import 'identity.dart';
import 'mailbox.dart';
import 'perspective.dart';
import 'transport.dart';

/// What happened to a command given to the host.
sealed class SubmitResult {
  const SubmitResult();
}

/// The command was decided and its events committed (and broadcast).
final class Committed extends SubmitResult {
  /// Creates the result.
  const Committed(this.seqs);

  /// The `seq` of each committed event (consequences held for review are not
  /// included).
  final List<int> seqs;
}

/// The command was decided; its consequence events wait for the GM's review
/// (F2). Rolls in the same decision, if any, are already committed.
final class Held extends SubmitResult {
  /// Creates the result.
  const Held(this.committedSeqs);

  /// Events committed now.
  final List<int> committedSeqs;
}

/// The command was refused, by the session or the engine.
final class Refusal extends SubmitResult {
  /// Creates the result.
  const Refusal(this.code, this.message);

  /// Machine-readable code ([SessionRejection] or a `RejectionCode` name).
  final String code;

  /// Readable explanation.
  final String message;
}

/// A consequence batch awaiting the GM (F2 review gate).
final class PendingBatch {
  PendingBatch._(this.events, this._origin);

  /// The held events, in order.
  final List<Event> events;

  final _Origin? _origin;
}

/// Hands out `e<N>` entity ids and exposes the counter so it can be stored.
final class _CountingIds implements IdSource {
  _CountingIds(this.nextNumber);

  int nextNumber;

  @override
  EntityId next() => EntityId('e${nextNumber++}');
}

class _Origin {
  const _Origin(this.agentId, this.requestId);

  final String agentId;
  final String requestId;
}

/// A live, read-only view of one perspective on the host's operation.
final class PerspectiveView {
  PerspectiveView._(this.perspective, this._feed);

  /// Whose view this is.
  final Perspective perspective;

  final PerspectiveFeed _feed;
  final StreamController<OperationState> _changes =
      StreamController<OperationState>.broadcast();

  /// The state this perspective may see.
  OperationState get state => _feed.state;

  /// The last `seq` this view has applied.
  int get lastSeq => _feed.lastSeq;

  /// Emits the new state after each applied batch.
  Stream<OperationState> get states => _changes.stream;
}

class _Committed {
  _Committed(this.seq, this.event, this.origin);

  final int seq;
  final Event event;
  final _Origin? origin;
}

class _Connection {
  _Connection(this.actor);

  final ConnectionActor actor;
  Principal? identity;
  Perspective? perspective;
}

/// The canonical engine of one operation, on the GM's device (04 §The
/// operation loop).
///
/// Every input, from a connected player or from the GM's own UI, goes
/// through one mailbox, so the order of decisions is the order of the log.
/// The loop is: authorize, dedupe, decide, hold consequences for review,
/// assign `seq`, store, filter, broadcast. An event is stored before it is
/// broadcast.
final class OperationHost {
  OperationHost._({
    required this.operationId,
    required this.gm,
    required this.engine,
    required this.codec,
    required this.store,
    required this.clock,
    required this.authorizer,
    required this.verifier,
    required this.admission,
    required this.narrator,
    required this.onProtocolError,
    required Rng rng,
    required _CountingIds ids,
    required OperationState state,
    required List<_Committed> log,
    required Map<String, Refusal?> answered,
    required EngineVersion requiredEngine,
  }) : _rng = rng,
       _ids = ids,
       _state = state,
       _log = log,
       _answered = answered,
       _requiredEngine = requiredEngine;

  /// Opens the operation [operationId] from [store]: an empty store is a new
  /// operation (give the host `StartOperation` to begin it), a stored log is
  /// replayed to the same state.
  ///
  /// Throws an [ArgumentError] when [gm] is anonymous: anonymous accounts
  /// cannot host (06 §Account model). [rngFactory] receives the draw count to
  /// resume at: the larger of the state's count and the last count the host
  /// persisted, so draws made by a rejected command are never reused.
  static Future<OperationHost> open({
    required String operationId,
    required Principal gm,
    required Engine engine,
    required EngineCodec codec,
    required EventStore store,
    required Rng Function(int drawCount) rngFactory,
    Clock clock = const SystemClock(),
    Authorizer authorizer = const DefaultAuthorizer(),
    required IdentityVerifier verifier,
    Admission? admission,
    void Function(Object error)? onProtocolError,
  }) async {
    if (!gm.isGm || gm.isAnonymous) {
      throw ArgumentError.value(
        gm,
        'gm',
        'Only a signed-in account can host an operation.',
      );
    }
    final stored = await store.read(operationId).toList();
    final log = <_Committed>[];
    final answered = <String, Refusal?>{};
    var state = const OperationState.initial();
    var required = const EngineVersion(0, 0, 0);
    for (final item in stored) {
      final event = codec.decodeEvent(item.event);
      state = engine.evolve(state, event);
      final origin = item.agentId == null || item.requestId == null
          ? null
          : _Origin(item.agentId!, item.requestId!);
      log.add(_Committed(item.seq, event, origin));
      if (origin != null) {
        answered[_dedupeKey(origin.agentId, origin.requestId)] = null;
      }
      final written = EngineVersion.parse(item.engineVersion);
      if (required < written) required = written;
    }
    final head = await store.headSnapshot(operationId);
    final persisted = await store.rngDrawCount(operationId);
    final draws = persisted > state.rng.drawCount
        ? persisted
        : state.rng.drawCount;
    return OperationHost._(
      operationId: operationId,
      gm: gm,
      engine: engine,
      codec: codec,
      store: store,
      clock: clock,
      authorizer: authorizer,
      verifier: verifier,
      admission: admission ?? RosterAdmission(),
      narrator: Narrator(engine.pack),
      onProtocolError: onProtocolError,
      rng: rngFactory(draws),
      ids: _CountingIds(
        [
          _nextIdNumber(state),
          head?.nextEntityNumber ?? 1,
        ].reduce((a, b) => a > b ? a : b),
      ),
      answered: answered,
      state: state,
      log: log,
      requiredEngine: required,
    );
  }

  /// The operation's id.
  final String operationId;

  /// The GM's identity.
  final Principal gm;

  /// The canonical engine.
  final Engine engine;

  /// The engine codec.
  final EngineCodec codec;

  /// Where the log is kept.
  final EventStore store;

  /// Time source.
  final Clock clock;

  /// Who may send what.
  final Authorizer authorizer;

  /// Verifies `hello` identities.
  final IdentityVerifier verifier;

  /// Who may join.
  final Admission admission;

  /// The engine's narrator, for the text log (P12).
  final Narrator narrator;

  /// Hears about frames dropped as malformed.
  final void Function(Object error)? onProtocolError;

  final Rng _rng;
  final _CountingIds _ids;
  final Mailbox _mailbox = Mailbox();
  final List<_Committed> _log;
  final List<_Connection> _connections = [];
  final List<PerspectiveView> _views = [];
  final List<PendingBatch> _pending = [];
  final Map<String, Refusal?> _answered;
  final StreamController<OperationState> _stateChanges =
      StreamController<OperationState>.broadcast();
  final StreamController<List<PendingBatch>> _pendingChanges =
      StreamController<List<PendingBatch>>.broadcast();
  final List<StreamSubscription<Link>> _listeners = [];
  OperationState _state;
  EngineVersion _requiredEngine;
  int _persistedDraws = 0;
  bool _closed = false;

  /// The GM's full state.
  OperationState get state => _state;

  /// The last committed `seq`.
  int get lastSeq => _log.isEmpty ? 0 : _log.last.seq;

  /// Emits the GM state after each committed batch.
  Stream<OperationState> get states => _stateChanges.stream;

  /// Batches waiting for the GM (visible to the GM only).
  List<PendingBatch> get pending => List.unmodifiable(_pending);

  /// Emits the pending list whenever it changes.
  Stream<List<PendingBatch>> get pendingChanges => _pendingChanges.stream;

  /// Starts accepting links from [transport].
  void listen(Transport transport) {
    _listeners.add(transport.incoming().listen(_accept));
  }

  /// Gives the GM's own command to the loop.
  Future<SubmitResult> submit(Command command) => _mailbox.run(() {
    _checkOpen();
    return _process(gm, command, null);
  });

  void _checkOpen() {
    if (_closed) throw StateError('The host is closed.');
  }

  /// Opens a live view of [perspective], filled from the log so far.
  Future<PerspectiveView> openView(Perspective perspective) => _mailbox.run(() {
    final view = PerspectiveView._(perspective, PerspectiveFeed(engine));
    final entries = _entriesFor(perspective, 1, null);
    if (entries.isNotEmpty) view._feed.apply(entries);
    _views.add(view);
    return view;
  });

  /// Confirms the oldest pending batch: stamps `seq`, stores, narrates and
  /// broadcasts it. [edit] may replace each event first (the GM editing a
  /// consequence value; recording `overriddenFrom` is the engine event's
  /// job).
  Future<List<int>> confirmPending({Event Function(Event event)? edit}) =>
      _mailbox.run(() async {
        _checkOpen();
        if (_pending.isEmpty) throw StateError('Nothing is pending.');
        final batch = _pending.first;
        final events = edit == null
            ? batch.events
            : [for (final e in batch.events) _checkedEdit(e, edit(e))];
        final seqs = await _commit(events, batch._origin);
        _pending.removeAt(0);
        _pendingChanges.add(pending);
        return seqs;
      });

  /// A review edit must stay the same kind of consequence about the same
  /// entity (gate condition on row 7): the tray adjusts a value, it cannot
  /// swap a consequence for a roll or for something else.
  ///
  /// The edit is rebuilt with the engine's own `withAmount` / `withCondition`
  /// and must equal it, so the bounds those apply (`maxEnteredValue`), the
  /// recorded original, the check link, actor and visibility cannot be set
  /// by hand.
  Event _checkedEdit(Event original, Event edited) {
    if (edited == original) return edited;
    final Event? expected = switch ((original, edited)) {
      (final DamageApplied o, final DamageApplied e) => o.withAmount(e.amount),
      (final SanityLost o, final SanityLost e) => o.withAmount(e.amount),
      (final ConditionApplied o, final ConditionApplied e) => o.withCondition(
        e.condition,
      ),
      _ => null,
    };
    if (expected == null || expected != edited) {
      throw ArgumentError(
        'A review edit must return the same consequence type for the same '
        'entity, check, actor and visibility, and record the value it '
        'replaced.',
      );
    }
    return edited;
  }

  /// Closes every link and view. The store is left as it is.
  Future<void> close() => _mailbox.run(() async {
    _closed = true;
    for (final l in _listeners) {
      await l.cancel();
    }
    for (final c in _connections.toList()) {
      await c.actor.close();
    }
    for (final v in _views) {
      await v._changes.close();
    }
    await _stateChanges.close();
    await _pendingChanges.close();
  });

  // ---- connections ------------------------------------------------------

  void _accept(Link link) {
    if (_closed) {
      unawaited(link.close());
      return;
    }
    final connection = _Connection(
      ConnectionActor(link, onMalformed: onProtocolError),
    );
    _connections.add(connection);
    connection.actor.envelopes.listen(
      (envelope) => unawaited(
        _mailbox
            .run(() => _onEnvelope(connection, envelope))
            .catchError((Object e) => onProtocolError?.call(e)),
      ),
      onDone: () => _connections.remove(connection),
    );
  }

  Future<void> _onEnvelope(_Connection c, Envelope envelope) async {
    if (_closed) return;
    try {
      final known = envelope.messageType;
      // Version rules run on the header, before the body is read, so a frame
      // from another protocol major still gets a `refused`.
      if (known == MessageType.hello) {
        await _onHello(c, envelope);
        return;
      }
      if (known == null) return;
      switch (envelope.message) {
        case Request(:final requestId, :final command):
          await _onRequest(c, requestId, command);
        case Resync(:final lastSeq):
          if (c.perspective == null) return;
          await _sendEntries(c, lastSeq + 1, welcome: false);
        case Ping(:final nonce):
          await _send(c, Pong(nonce: nonce));
        case Presence() || Pong():
          break;
        case Hello() ||
            Welcome() ||
            Refused() ||
            wire.Rejected() ||
            Events() ||
            TextLog():
          // Host-to-client messages: a client never sends these.
          break;
      }
    } on ProtocolFormatException catch (e) {
      onProtocolError?.call(e);
    }
  }

  Future<void> _onHello(_Connection c, Envelope envelope) async {
    final refusal = negotiateHello(
      clientProtocol: envelope.protocol,
      clientEngine: envelope.engineVersion,
      hostProtocol: protocolMajor,
      operationEngineMajor: _operationEngineMajor,
      requiredEngine: _log.isEmpty ? null : _requiredEngine,
    );
    if (refusal != null) {
      await _send(c, refusal);
      return;
    }
    final hello = envelope.message as Hello;
    final identity = await verifier.verify(hello);
    if (identity == null) {
      await _send(
        c,
        const Refused(
          reason: RefusalReason.notInvited,
          message: 'The identity could not be verified.',
        ),
      );
      return;
    }
    // The verifier's word on who the GM is must match this operation's GM.
    if (identity.isGm != (identity.agentId == gm.agentId) ||
        (identity.isGm && identity.isAnonymous) ||
        (!identity.isGm && identity.aliasId == null)) {
      await _send(
        c,
        const Refused(
          reason: RefusalReason.notInvited,
          message: 'The identity does not fit this operation.',
        ),
      );
      return;
    }
    final denied = admission.check(identity);
    if (denied != null) {
      await _send(c, Refused(reason: denied));
      return;
    }
    c.identity = identity;
    final alias = identity.aliasId;
    c.perspective = identity.isGm
        ? const GmPerspective()
        : PlayerPerspective(AliasId(alias!));
    await _sendEntries(c, hello.lastSeq + 1, welcome: true);
  }

  int get _operationEngineMajor {
    final meta = _state.meta;
    return EngineVersion.parse(meta?.engineVersion ?? engine_lib.engineVersion)
        .major;
  }

  Future<void> _onRequest(
    _Connection c,
    String requestId,
    JsonMap commandJson,
  ) async {
    final who = c.identity;
    if (who == null) {
      await _send(
        c,
        wire.Rejected(
          requestId: requestId,
          code: SessionRejection.notAdmitted,
          message: 'Send a hello first.',
        ),
      );
      return;
    }
    final key = _dedupeKey(who.agentId, requestId);
    if (_answered.containsKey(key)) {
      // At-least-once delivery: a retry never decides twice. A refused
      // request gets the same refusal again.
      final earlier = _answered[key];
      if (earlier != null) await _reject(c, requestId, earlier);
      return;
    }
    final Command command;
    try {
      command = codec.decodeCommand(commandJson);
    } on ProtocolFormatException catch (e) {
      final refusal = Refusal(SessionRejection.malformed, e.message);
      _answered[key] = refusal;
      await _reject(c, requestId, refusal);
      return;
    }
    final result = await _process(
      who,
      command,
      _Origin(who.agentId, requestId),
    );
    _answered[key] = result is Refusal ? result : null;
    if (result is Refusal) await _reject(c, requestId, result);
  }

  Future<void> _reject(_Connection c, String requestId, Refusal r) => _send(
    c,
    wire.Rejected(requestId: requestId, code: r.code, message: r.message),
  );

  // ---- the loop ---------------------------------------------------------

  Future<SubmitResult> _process(
    Principal who,
    Command command,
    _Origin? origin,
  ) async {
    final denial = authorizer.deny(who, command, _state);
    if (denial != null) {
      return Refusal(SessionRejection.unauthorized, denial);
    }
    final decision = engine.decide(_state, command, _rng, _ids);
    // Draws a rejected or held command used are consumed whether or not any
    // event records them; persist the real count so a reopen cannot hand the
    // same dice out again.
    if (_rng.drawCount != _persistedDraws) {
      _persistedDraws = _rng.drawCount;
      await store.saveRngDrawCount(operationId, _persistedDraws);
    }
    switch (decision) {
      case Rejected(:final reason):
        return Refusal(reason.code.name, reason.message);
      case Accepted(:final events):
        final held = <Event>[];
        final now = <Event>[];
        final autoConfirm =
            _state.meta?.settings.autoConfirmConsequences ?? false;
        for (final event in events) {
          // Only the engine marks consequences, so a roll can never be held.
          (event is Consequence && !autoConfirm ? held : now).add(event);
        }
        final seqs = await _commit(now, origin);
        if (held.isEmpty) return Committed(seqs);
        _pending.add(PendingBatch._(List.unmodifiable(held), origin));
        _pendingChanges.add(pending);
        return Held(seqs);
    }
  }

  /// The log line for [event], one variant per audience (04 §Interfaces):
  /// `gm`, `public`, `redacted` and `alias:<id>`.
  TextLogLine _narrate(
    int seq,
    Event event,
    OperationState after,
    DateTime time,
  ) {
    final n = narrator.narrate(after, event);
    final variants = <String, String>{'gm': n.gm};
    final player = n.player;
    final visibility = event.visibility;
    if (player != null) {
      if (visibility is Public) variants['public'] = player;
      if (visibility is AliasesOnly) {
        for (final alias in visibility.aliases) {
          variants['alias:${alias.value}'] = player;
        }
      }
    }
    if (n.redacted != null) variants['redacted'] = n.redacted!;
    return TextLogLine(seq: seq, time: time, variants: variants);
  }

  Future<List<int>> _commit(List<Event> events, _Origin? origin) async {
    if (events.isEmpty) return const [];
    final time = clock.now();
    var next = _state;
    var seq = lastSeq;
    final stored = <StoredEvent>[];
    final text = <TextLogLine>[];
    final committed = <_Committed>[];
    for (final event in events) {
      seq++;
      next = engine.evolve(next, event);
      stored.add(
        StoredEvent(
          seq: seq,
          time: time,
          engineVersion: engine_lib.engineVersion,
          event: codec.encodeEvent(event),
          agentId: origin?.agentId,
          requestId: origin?.requestId,
        ),
      );
      text.add(_narrate(seq, event, next, time));
      committed.add(_Committed(seq, event, origin));
    }
    // Stored before broadcast: if this throws, nothing was sent and the
    // in-memory state is untouched.
    await store.append(
      operationId,
      stored,
      text,
      HeadSnapshot(
        seq: seq,
        state: codec.encodeState(next),
        rngDrawCount: _rng.drawCount,
        nextEntityNumber: _ids.nextNumber,
      ),
    );
    _persistedDraws = _rng.drawCount;
    _state = next;
    _log.addAll(committed);
    final written = EngineVersion.parse(engine_lib.engineVersion);
    if (_requiredEngine < written) _requiredEngine = written;
    final first = committed.first.seq;
    // The batch is committed; a link that fails now must not undo it or stop
    // the others, and recovers by resync.
    for (final c in _connections.toList()) {
      if (c.perspective == null) continue;
      try {
        await _sendEntries(c, first, welcome: false, upTo: seq);
      } on Object catch (e) {
        onProtocolError?.call(e);
        _connections.remove(c);
      }
    }
    for (final v in _views) {
      v._feed.apply(_entriesFor(v.perspective, first, null, upTo: seq));
      v._changes.add(v.state);
    }
    _stateChanges.add(_state);
    return [for (final c in committed) c.seq];
  }

  // ---- sending ----------------------------------------------------------

  List<EventEntry> _entriesFor(
    Perspective perspective,
    int fromSeq,
    String? agentId, {
    int? upTo,
  }) {
    final entries = <EventEntry>[];
    for (final item in _log) {
      if (item.seq < fromSeq || (upTo != null && item.seq > upTo)) continue;
      final req = agentId != null && item.origin?.agentId == agentId
          ? item.origin!.requestId
          : null;
      entries.add(switch (deliveryFor(item.event.visibility, perspective)) {
        Delivery.full => FullEntry(
          item.seq,
          projectFor(item.event, perspective),
          requestId: req,
        ),
        Delivery.redacted => RedactedEntry(item.seq, requestId: req),
        Delivery.hidden => HiddenEntry(item.seq, requestId: req),
      });
    }
    return entries;
  }

  /// Sends the entries from [fromSeq] on, in frames of at most [_frameSize].
  Future<void> _sendEntries(
    _Connection c,
    int fromSeq, {
    required bool welcome,
    int? upTo,
  }) async {
    final entries = _entriesFor(
      c.perspective!,
      fromSeq,
      c.identity?.agentId,
      upTo: upTo,
    );
    if (welcome) {
      await _send(
        c,
        Welcome(
          settings: _settingsJson(),
          pack: wire.PackPin(
            id: engine.pack.ref.id,
            version: engine.pack.ref.version,
            contentHash: engine.pack.ref.contentHash,
          ),
        ),
      );
    }
    for (var i = 0; i < entries.length; i += _frameSize) {
      final chunk = entries.sublist(
        i,
        i + _frameSize > entries.length ? entries.length : i + _frameSize,
      );
      await _send(
        c,
        Events([for (final e in chunk) e.toJson(codec)]),
        seq: chunk.first.seq,
      );
    }
  }

  static const _frameSize = 200;

  /// Length-prefixed, so agent ids containing `/` cannot collide.
  static String _dedupeKey(String agentId, String requestId) =>
      '${agentId.length}:$agentId/$requestId';

  JsonMap _settingsJson() {
    final s = _state.meta?.settings ?? const OperationSettings();
    return {
      'autoResolveChecks': s.autoResolveChecks,
      'autoConfirmConsequences': s.autoConfirmConsequences,
      'autoApplyEngineUpdates': s.autoApplyEngineUpdates,
      'autoApplyPackUpdates': s.autoApplyPackUpdates,
    };
  }

  Future<void> _send(_Connection c, Message message, {int? seq}) async {
    try {
      await c.actor.send(
        Envelope.of(
          message,
          engineVersion: EngineVersion.parse(engine_lib.engineVersion),
          operationId: operationId,
          from: gmSender,
          seq: seq,
        ),
      );
    } on StateError {
      // The link closed while we were sending; the connection is dropped.
      _connections.remove(c);
    }
  }

  /// The first entity number a new [SequentialIdSource] may hand out: one
  /// past the largest `e<N>` id in [state], so ids never repeat after a
  /// reopen (04 §Coarse actors; ids drawn by commands that recorded nothing
  /// may be reused, because nothing refers to them).
  static int _nextIdNumber(OperationState state) {
    var highest = 0;
    final pattern = RegExp(r'^e(\d+)$');
    for (final id in state.stores.entities) {
      final n = int.tryParse(pattern.firstMatch(id.value)?.group(1) ?? '');
      if (n != null && n > highest) highest = n;
    }
    return highest + 1;
  }
}
