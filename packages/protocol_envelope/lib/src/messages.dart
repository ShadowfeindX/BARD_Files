import 'engine_version.dart';
import 'json.dart';
import 'refusal_reason.dart';

/// The `from` value of the GM (any other sender is an alias id).
const String gmSender = 'gm';

/// The message types of the protocol (03 §Messages), with their wire names.
enum MessageType {
  /// Client to GM: who I am.
  hello('hello'),

  /// GM to client: accepted.
  welcome('welcome'),

  /// GM to client: refused, with a machine-readable reason.
  refused('refused'),

  /// Client to GM: a command for the GM engine to decide.
  request('request'),

  /// GM to client: a request was rejected.
  rejected('rejected'),

  /// GM to clients: events with consecutive `seq`.
  events('events'),

  /// Client to GM: "I have up to seq N".
  resync('resync'),

  /// GM to client: archived text from earlier engine majors (P12).
  textlog('textlog'),

  /// Both ways: online/away/typing.
  presence('presence'),

  /// Both ways: liveness probe.
  ping('ping'),

  /// Both ways: liveness reply. Proposed: an optional `nonce`, as on [Ping].
  pong('pong');

  const MessageType(this.wire);

  /// The string used in the envelope's `type`.
  final String wire;

  /// Maps a wire name to a type, or null when this version does not know it.
  static MessageType? fromWire(String wire) {
    for (final type in values) {
      if (type.wire == wire) return type;
    }
    return null;
  }
}

/// A protocol message body. Engine commands, events and state travel inside
/// as opaque [JsonMap]s; this package never interprets them.
sealed class Message {
  const Message();

  /// The envelope `type` for this message.
  MessageType get type;

  /// The JSON body for the envelope's `body` field.
  JsonMap toBody();

  /// Decodes a [body] of the given [type].
  static Message fromBody(MessageType type, JsonMap body) => switch (type) {
    MessageType.hello => Hello.fromBody(body),
    MessageType.welcome => Welcome.fromBody(body),
    MessageType.refused => Refused.fromBody(body),
    MessageType.request => Request.fromBody(body),
    MessageType.rejected => Rejected.fromBody(body),
    MessageType.events => Events.fromBody(body),
    MessageType.resync => Resync.fromBody(body),
    MessageType.textlog => TextLog.fromBody(body),
    MessageType.presence => Presence.fromBody(body),
    MessageType.ping => Ping.fromBody(body),
    MessageType.pong => Pong.fromBody(body),
  };
}

/// Whether an agent is a signed-in account or an anonymous guest.
///
/// Values follow 06 §Account model (`kind: full | anonymous`).
///
/// Advisory only: a client states its own kind, so the host never grants or
/// refuses anything because of this field. It decides from the verified
/// identity (the `authProof`, or the auth token's `sign_in_provider` on the
/// backend), as RTDB rules already do for anonymous members.
enum AgentKind {
  /// A full (signed-in, non-anonymous) account.
  full,

  /// An anonymous guest (one alias, no hosting).
  anonymous,
}

/// Client to GM: identity, and the last `seq` the client holds.
final class Hello extends Message {
  /// Creates a hello. [lastSeq] is 0 when the client holds nothing.
  const Hello({
    required this.agentId,
    this.aliasId,
    this.kind = AgentKind.full,
    this.authProof,
    this.lastSeq = 0,
  });

  /// Decodes a hello body.
  factory Hello.fromBody(JsonMap body) {
    final kind = optString(body, 'kind') ?? AgentKind.full.name;
    return Hello(
      agentId: reqString(body, 'agentId'),
      aliasId: optString(body, 'aliasId'),
      kind:
          AgentKind.values.asNameMap()[kind] ??
          (throw ProtocolFormatException('unknown agent kind "$kind"')),
      authProof: optString(body, 'authProof'),
      lastSeq: body['lastSeq'] == null ? 0 : reqIntMin(body, 'lastSeq', 0),
    );
  }

  /// The agent (account profile) id.
  final String agentId;

  /// The alias (character) the agent joins as; null for a GM or a spectator.
  final String? aliasId;

  /// Proposed field: full account or anonymous guest. Advisory; see
  /// [AgentKind].
  final AgentKind kind;

  /// Auth proof, if any. Opaque here; the session and backend define it.
  final String? authProof;

  /// The last `seq` the client has applied.
  final int lastSeq;

  @override
  MessageType get type => MessageType.hello;

  @override
  JsonMap toBody() => {
    'agentId': agentId,
    if (aliasId != null) 'aliasId': aliasId,
    'kind': kind.name,
    if (authProof != null) 'authProof': authProof,
    'lastSeq': lastSeq,
  };
}

/// The pinned pack an operation uses: `(id, version, contentHash)`.
final class PackPin {
  /// Creates a pack reference.
  const PackPin({
    required this.id,
    required this.version,
    required this.contentHash,
  });

  /// Decodes a pack reference.
  factory PackPin.fromJson(JsonMap json) => PackPin(
    id: reqString(json, 'id'),
    version: reqString(json, 'version'),
    contentHash: reqString(json, 'contentHash'),
  );

  /// Pack id.
  final String id;

  /// Pack semver.
  final String version;

  /// Hash of the pack contents.
  final String contentHash;

  /// Encodes this reference.
  JsonMap toJson() => {
    'id': id,
    'version': version,
    'contentHash': contentHash,
  };
}

/// A perspective-filtered state at a `seq`. [state] is opaque engine JSON.
final class Snapshot {
  /// Creates a snapshot.
  const Snapshot({required this.seq, required this.state});

  /// Decodes a snapshot.
  factory Snapshot.fromJson(JsonMap json) =>
      Snapshot(seq: reqIntMin(json, 'seq', 0), state: reqMap(json, 'state'));

  /// The last `seq` folded into [state].
  final int seq;

  /// The serialized engine state, already filtered for the recipient.
  final JsonMap state;

  /// Encodes this snapshot.
  JsonMap toJson() => {'seq': seq, 'state': state};
}

/// GM to client: accepted.
///
/// Carries a [snapshot], or [events] from the client's `lastSeq + 1`, or a
/// snapshot followed by events from `snapshot.seq + 1`. Proposed: the body
/// layout (03 names the contents but not the field names).
final class Welcome extends Message {
  /// Creates a welcome.
  const Welcome({
    required this.settings,
    this.pack,
    this.snapshot,
    this.events = const [],
  });

  /// Decodes a welcome body.
  factory Welcome.fromBody(JsonMap body) => Welcome(
    settings: reqMap(body, 'settings'),
    pack: optMap(body, 'pack') == null
        ? null
        : PackPin.fromJson(reqMap(body, 'pack')),
    snapshot: optMap(body, 'snapshot') == null
        ? null
        : Snapshot.fromJson(reqMap(body, 'snapshot')),
    events: body['events'] == null ? const [] : reqMapList(body, 'events'),
  );

  /// Operation settings visible to the client (opaque).
  final JsonMap settings;

  /// The operation's pinned pack.
  final PackPin? pack;

  /// A filtered snapshot, when the client cannot catch up from events.
  final Snapshot? snapshot;

  /// Filtered events (opaque), in `seq` order.
  final List<JsonMap> events;

  @override
  MessageType get type => MessageType.welcome;

  @override
  JsonMap toBody() => {
    'settings': settings,
    if (pack != null) 'pack': pack!.toJson(),
    if (snapshot != null) 'snapshot': snapshot!.toJson(),
    'events': events,
  };
}

/// GM to client: the `hello` was refused.
final class Refused extends Message {
  /// Creates a refusal.
  const Refused({
    required this.reason,
    this.message,
    this.hostProtocolMajor,
    this.operationEngineMajor,
    this.requiredEngineVersion,
    this.unrecognizedCode,
  });

  /// Decodes a refusal body.
  factory Refused.fromBody(JsonMap body) {
    final code = reqString(body, 'reason');
    final reason = RefusalReason.fromWire(code);
    final required = optString(body, 'requiredEngine');
    return Refused(
      reason: reason,
      message: optString(body, 'message'),
      hostProtocolMajor: optInt(body, 'protocolMajor'),
      operationEngineMajor: optInt(body, 'engineMajor'),
      requiredEngineVersion: required == null
          ? null
          : EngineVersion.parse(required),
      unrecognizedCode: reason == RefusalReason.unknown ? code : null,
    );
  }

  /// Machine-readable reason.
  final RefusalReason reason;

  /// Optional human-readable detail (not for logic).
  final String? message;

  /// Proposed: the GM's protocol major, on [RefusalReason.protocolMismatch].
  final int? hostProtocolMajor;

  /// Proposed: the operation's engine major, on
  /// [RefusalReason.engineMajorMismatch].
  final int? operationEngineMajor;

  /// Proposed: the minimum engine version, on [RefusalReason.updateRequired].
  final EngineVersion? requiredEngineVersion;

  /// The raw reason string when [reason] is [RefusalReason.unknown].
  final String? unrecognizedCode;

  @override
  MessageType get type => MessageType.refused;

  @override
  JsonMap toBody() => {
    'reason': unrecognizedCode ?? reason.wire,
    if (message != null) 'message': message,
    if (hostProtocolMajor != null) 'protocolMajor': hostProtocolMajor,
    if (operationEngineMajor != null) 'engineMajor': operationEngineMajor,
    if (requiredEngineVersion != null)
      'requiredEngine': requiredEngineVersion.toString(),
  };
}

/// Client to GM: a command for the GM engine to decide.
final class Request extends Message {
  /// Creates a request. [requestId] must be unique per client command and is
  /// reused on every retry, so the GM can deduplicate.
  const Request({required this.requestId, required this.command});

  /// Decodes a request body.
  factory Request.fromBody(JsonMap body) => Request(
    requestId: reqString(body, 'requestId'),
    command: reqMap(body, 'command'),
  );

  /// Client-generated id for idempotency.
  final String requestId;

  /// The engine command (opaque; encoded by `protocol`).
  final JsonMap command;

  @override
  MessageType get type => MessageType.request;

  @override
  JsonMap toBody() => {'requestId': requestId, 'command': command};
}

/// GM to client: a request was rejected.
final class Rejected extends Message {
  /// Creates a rejection of [requestId].
  const Rejected({required this.requestId, required this.code, this.message});

  /// Decodes a rejection body.
  factory Rejected.fromBody(JsonMap body) => Rejected(
    requestId: reqString(body, 'requestId'),
    code: reqString(body, 'code'),
    message: optString(body, 'message'),
  );

  /// The rejected request.
  final String requestId;

  /// Machine-readable reason, from the engine's rejection or the session's
  /// authorization (Proposed: the code vocabulary lives with those layers).
  final String code;

  /// Optional human-readable detail.
  final String? message;

  @override
  MessageType get type => MessageType.rejected;

  @override
  JsonMap toBody() => {
    'requestId': requestId,
    'code': code,
    if (message != null) 'message': message,
  };
}

/// GM to clients: events with consecutive `seq`, already filtered for the
/// recipient. The envelope's `seq` is the first event's `seq` (Proposed: 03
/// does not say which event the envelope `seq` names).
final class Events extends Message {
  /// Creates an events message; [events] must not be empty.
  Events(this.events) {
    if (events.isEmpty) throw ArgumentError.value(events, 'events', 'empty');
  }

  /// Decodes an events body.
  factory Events.fromBody(JsonMap body) {
    final events = reqMapList(body, 'events');
    if (events.isEmpty) {
      throw const ProtocolFormatException('"events" must not be empty');
    }
    return Events(events);
  }

  /// The events (opaque engine JSON), in `seq` order.
  final List<JsonMap> events;

  /// The `seq` of the last event, given the envelope's [firstSeq].
  int lastSeq(int firstSeq) => firstSeq + events.length - 1;

  @override
  MessageType get type => MessageType.events;

  @override
  JsonMap toBody() => {'events': events};
}

/// Client to GM: "I have up to seq N" after a gap or reconnect.
final class Resync extends Message {
  /// Creates a resync request.
  const Resync(this.lastSeq);

  /// Decodes a resync body.
  factory Resync.fromBody(JsonMap body) =>
      Resync(reqIntMin(body, 'lastSeq', 0));

  /// The last `seq` the client has applied.
  final int lastSeq;

  @override
  MessageType get type => MessageType.resync;

  @override
  JsonMap toBody() => {'lastSeq': lastSeq};
}

/// One narrated line, already reduced to the variant the recipient saw.
final class TextLine {
  /// Creates a line.
  const TextLine({required this.seq, required this.text});

  /// Decodes a line.
  factory TextLine.fromJson(JsonMap json) =>
      TextLine(seq: reqIntMin(json, 'seq', 1), text: reqString(json, 'text'));

  /// The `seq` of the event this line narrates.
  final int seq;

  /// The text this recipient saw.
  final String text;

  /// Encodes this line.
  JsonMap toJson() => {'seq': seq, 'text': text};
}

/// GM to client: archived text from an earlier engine major (P12).
///
/// Proposed: the body layout; 03 gives only the purpose. The line shape
/// matches the RTDB `textlog` node (`{seq, text}`).
final class TextLog extends Message {
  /// Creates a text log message.
  const TextLog({
    required this.archiveOperationId,
    required this.engineMajor,
    required this.lines,
  });

  /// Decodes a text log body.
  factory TextLog.fromBody(JsonMap body) => TextLog(
    archiveOperationId: reqString(body, 'archive'),
    engineMajor: reqInt(body, 'engineMajor'),
    lines: [
      for (final line in reqMapList(body, 'lines')) TextLine.fromJson(line),
    ],
  );

  /// The archived operation these lines come from.
  final String archiveOperationId;

  /// The engine major that wrote the events.
  final int engineMajor;

  /// The lines, in `seq` order.
  final List<TextLine> lines;

  @override
  MessageType get type => MessageType.textlog;

  @override
  JsonMap toBody() => {
    'archive': archiveOperationId,
    'engineMajor': engineMajor,
    'lines': [for (final line in lines) line.toJson()],
  };
}

/// A participant's presence. Never part of the event log.
enum PresenceStatus {
  /// Connected and active.
  online,

  /// Connected but idle.
  away,

  /// Composing a message.
  typing,
}

/// Both ways: online/away/typing.
final class Presence extends Message {
  /// Creates a presence update.
  const Presence(this.status);

  /// Decodes a presence body.
  factory Presence.fromBody(JsonMap body) {
    final name = reqString(body, 'status');
    return Presence(
      PresenceStatus.values.asNameMap()[name] ??
          (throw ProtocolFormatException('unknown presence status "$name"')),
    );
  }

  /// The sender's status.
  final PresenceStatus status;

  @override
  MessageType get type => MessageType.presence;

  @override
  JsonMap toBody() => {'status': status.name};
}

/// Both ways: liveness probe. Proposed: an optional [nonce] the pong echoes.
final class Ping extends Message {
  /// Creates a ping.
  const Ping({this.nonce});

  /// Decodes a ping body.
  factory Ping.fromBody(JsonMap body) => Ping(nonce: optString(body, 'nonce'));

  /// Echoed by the matching [Pong].
  final String? nonce;

  @override
  MessageType get type => MessageType.ping;

  @override
  JsonMap toBody() => {if (nonce != null) 'nonce': nonce};
}

/// Both ways: liveness reply.
final class Pong extends Message {
  /// Creates a pong.
  const Pong({this.nonce});

  /// Decodes a pong body.
  factory Pong.fromBody(JsonMap body) => Pong(nonce: optString(body, 'nonce'));

  /// The nonce of the ping being answered.
  final String? nonce;

  @override
  MessageType get type => MessageType.pong;

  @override
  JsonMap toBody() => {if (nonce != null) 'nonce': nonce};
}
