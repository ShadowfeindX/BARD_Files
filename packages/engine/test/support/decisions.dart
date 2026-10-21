import 'package:engine/engine.dart';

/// The events of an accepted [decision]; throws on a rejection.
List<Event> accepted(Decision decision) => switch (decision) {
  Accepted(:final events) => events,
  Rejected(:final reason) => throw StateError('Unexpected rejection: $reason'),
};

/// The code of a rejected [decision]; throws on an accept.
RejectionCode rejection(Decision decision) => switch (decision) {
  Rejected(:final reason) => reason.code,
  Accepted(:final events) => throw StateError('Unexpected accept: $events'),
};
