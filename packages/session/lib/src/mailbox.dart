import 'dart:async';

/// A private queue that runs one task at a time, in the order submitted
/// (04 §Coarse actors).
///
/// Actors are not isolates: this gives the ordering the event log needs
/// without locks. A task that throws fails only its own caller; later tasks
/// still run.
final class Mailbox {
  Future<void> _tail = Future<void>.value();

  /// Runs [task] after every earlier task has finished.
  Future<T> run<T>(FutureOr<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}
