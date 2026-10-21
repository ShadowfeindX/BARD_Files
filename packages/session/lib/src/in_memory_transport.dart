// ignore_for_file: prefer_initializing_formals
// (private fields set from public parameters)
import 'dart:async';

import 'transport.dart';

/// Decides what actually reaches the other end of an in-memory link.
///
/// [toHost] is true for frames travelling client to host. Return no frames to
/// drop, two copies to duplicate, or hold frames back and release them later
/// to reorder. Tests only.
typedef FrameFilter = List<String> Function(bool toHost, String frame);

/// An in-process "network" joining hosts and clients (04 §Play modes, first
/// transport). Also the base of the transport contract tests.
final class InMemoryNetwork {
  final Map<Address, StreamController<Link>> _hosts = {};

  /// When set, every frame passes through it before delivery.
  FrameFilter? filter;

  /// The transport a host listens on at [address].
  Transport host(Address address) {
    final controller = StreamController<Link>(sync: false);
    if (_hosts.containsKey(address)) {
      throw StateError('Something already listens at ${address.value}.');
    }
    _hosts[address] = controller;
    return _HostTransport(controller.stream);
  }

  /// A transport that clients connect from.
  Transport client() => _ClientTransport(this);

  Future<Link> _connect(Address address) async {
    final hostSide = _hosts[address];
    if (hostSide == null) {
      throw StateError('Nothing listens at ${address.value}.');
    }
    final toHost = StreamController<String>();
    final toClient = StreamController<String>();
    final client = _MemoryLink(
      incoming: toClient.stream,
      outgoing: toHost,
      deliver: (frame) => _route(true, frame, toHost),
      onClose: () => unawaited(toClient.close()),
    );
    final host = _MemoryLink(
      incoming: toHost.stream,
      outgoing: toClient,
      deliver: (frame) => _route(false, frame, toClient),
      onClose: () => unawaited(toHost.close()),
    );
    hostSide.add(host);
    return client;
  }

  void _route(bool toHost, String frame, StreamController<String> sink) {
    if (sink.isClosed) return;
    final frames = filter == null ? [frame] : filter!(toHost, frame);
    frames.forEach(sink.add);
  }
}

final class _HostTransport implements Transport {
  _HostTransport(this._incoming);

  final Stream<Link> _incoming;

  @override
  Stream<Link> incoming() => _incoming;

  @override
  Future<Link> connect(Address address) =>
      throw UnsupportedError('A host transport only accepts links.');
}

final class _ClientTransport implements Transport {
  _ClientTransport(this._network);

  final InMemoryNetwork _network;

  @override
  Stream<Link> incoming() => const Stream.empty();

  @override
  Future<Link> connect(Address address) => _network._connect(address);
}

final class _MemoryLink implements Link {
  _MemoryLink({
    required Stream<String> incoming,
    required StreamController<String> outgoing,
    required void Function(String frame) deliver,
    required void Function() onClose,
  }) : frames = incoming,
       _outgoing = outgoing,
       _deliver = deliver,
       _onClose = onClose;

  @override
  final Stream<String> frames;

  final StreamController<String> _outgoing;
  final void Function(String frame) _deliver;
  final void Function() _onClose;

  @override
  Future<void> send(String frame) async {
    if (_outgoing.isClosed) throw StateError('The link is closed.');
    _deliver(frame);
  }

  @override
  Future<void> close() async {
    // Not awaited: a controller's close future completes only once a listener
    // has seen the done event, and the other end may never listen.
    unawaited(_outgoing.close());
    _onClose();
  }
}
