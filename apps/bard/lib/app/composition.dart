import '../data/services/fake_operation_service.dart';
import '../data/services/operation_service.dart';

/// The one place services are built and injected (07 §Layering).
class Composition {
  /// Creates a composition over [operation].
  const Composition({required this.operation});

  /// Composition backed by the in-memory fake, until the session host lands.
  factory Composition.fake() => Composition(operation: FakeOperationService());

  /// The running operation.
  final OperationService operation;
}
