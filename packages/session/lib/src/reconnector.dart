// ignore_for_file: prefer_initializing_formals
// (private fields set from public parameters)
import 'dart:async';

import 'diagnostic_log.dart';
import 'episode_participant.dart';
import 'transport.dart';

/// How long a [Reconnector] waits before each new attempt: [initial], then
/// doubling up to [max]. The first attempt after a link the host had
/// accepted waits [initial] again.
final class Backoff {
  /// Creates the policy.
  const Backoff({
    this.initial = const Duration(milliseconds: 500),
    this.max = const Duration(seconds: 30),
  });

  /// The first wait.
  final Duration initial;

  /// The longest wait.
  final Duration max;

  /// The wait after [failures] attempts in a row that did not reach a
  /// welcome: [initial] for 0, doubling for each one after.
  Duration delayFor(int failures) {
    var delay = initial;
    for (var i = 0; i < failures && delay < max; i++) {
      delay *= 2;
    }
    return delay > max ? max : delay;
  }
}

/// Why a [Reconnector] stopped trying.
enum ReconnectStop {
  /// [Reconnector.stop] was called.
  stopped,

  /// The host sent a readable `refused` (see [EpisodeParticipant.refusal]).
  refused,

  /// The transport threw [ConnectRefused] (for example, a wrong join code).
  connectRefused,

  /// The transport could not read [Reconnector.address] ([FormatException]).
  badAddress,
}

/// Keeps one [EpisodeParticipant] connected to [address] (04 §Reconnect).
///
/// Connects, waits for the link to end, then connects again after a
/// [Backoff] wait. Each new link sends `hello` with the participant's last
/// `seq`, so the host replays what was missed and pending requests are
/// re-sent; the host deduplicates them by request id. It stops on [stop], on
/// a readable refusal, on [ConnectRefused] and on a [FormatException] for the
/// address.
///
/// A link the host welcomed resets the backoff, even if it drops at once; a
/// host that welcomes and then drops every link is retried every
/// [Backoff.initial]. Accepted for the LAN demo: the diagnostic log shows it.
final class Reconnector {
  /// Creates the loop; call [run] to start it.
  Reconnector({
    required this.participant,
    required this.transport,
    required this.address,
    this.backoff = const Backoff(),
    this.diagnostics,
    Future<void> Function(Duration delay)? wait,
  }) : _wait = wait;

  /// The participant kept connected.
  final EpisodeParticipant participant;

  /// The transport links are opened with.
  final Transport transport;

  /// The host's address.
  final Address address;

  /// The wait between attempts.
  final Backoff backoff;

  /// Where attempts and waits are noted, or null.
  final DiagnosticLog? diagnostics;

  final Future<void> Function(Duration delay)? _wait;
  final Completer<void> _stop = Completer<void>();
  Timer? _timer;
  Completer<void>? _sleep;

  /// Why the loop ended, once [run] has returned.
  ReconnectStop? stoppedBy;

  /// Runs until [stop], a readable refusal, [ConnectRefused] or a bad
  /// address, and returns the reason.
  Future<ReconnectStop> run() async {
    var failures = 0;
    while (!_stop.isCompleted) {
      final Link? link;
      try {
        link = await _connectOrStop();
      } on ConnectRefused catch (e) {
        diagnostics?.record(DiagnosticCategory.error, 'link.connectRefused', {
          'reason': e.reason,
        });
        return stoppedBy = ReconnectStop.connectRefused;
      } on FormatException {
        diagnostics?.record(DiagnosticCategory.error, 'link.badAddress');
        return stoppedBy = ReconnectStop.badAddress;
      } on Object catch (e) {
        diagnostics?.record(DiagnosticCategory.network, 'link.connectFailed', {
          'type': e.runtimeType.toString(),
          'failures': failures,
        });
        await _pause(failures++);
        continue;
      }
      if (link == null) break;
      await participant.connect(link);
      final joined = await Future.any([
        participant.linkDone,
        _stop.future.then((_) => false),
      ]);
      if (_stop.isCompleted) break;
      if (participant.refusal != null) {
        return stoppedBy = ReconnectStop.refused;
      }
      if (joined) failures = 0;
      await _pause(failures++);
    }
    return stoppedBy = ReconnectStop.stopped;
  }

  /// Connects, or returns null if [stop] comes first. A link that opens
  /// after [stop] is closed.
  Future<Link?> _connectOrStop() async {
    final connecting = transport.connect(address);
    final first = await Future.any<Object?>([connecting, _stop.future]);
    if (first is Link) return first;
    unawaited(connecting.then((link) => link.close(), onError: (Object _) {}));
    return null;
  }

  /// Waits the backoff for [failures], ending early on [stop].
  Future<void> _pause(int failures) async {
    if (_stop.isCompleted) return;
    final delay = backoff.delayFor(failures);
    diagnostics?.record(DiagnosticCategory.network, 'link.retryIn', {
      'ms': delay.inMilliseconds,
      'failures': failures,
    });
    final wait = _wait;
    if (wait != null) {
      await Future.any([wait(delay), _stop.future]);
      return;
    }
    // A timer, not Future.delayed, so stop() can cancel it at once.
    final sleep = _sleep = Completer<void>();
    _timer = Timer(delay, sleep.complete);
    await sleep.future;
  }

  /// Ends the loop. The participant's current link is left as it is; close
  /// the participant to drop it.
  void stop() {
    if (_stop.isCompleted) return;
    _stop.complete();
    _timer?.cancel();
    final sleep = _sleep;
    if (sleep != null && !sleep.isCompleted) sleep.complete();
  }
}
