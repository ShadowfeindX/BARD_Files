import 'package:flutter/services.dart';

import '../data/pack_assets.dart';
import '../data/services/operation_service.dart';
import '../data/services/session_operation_service.dart';

/// The one place services are built and injected (07 §Layering).
class Composition {
  /// Creates a composition over [operation].
  const Composition({required this.operation});

  /// Composition backed by a real host over the shipped pack, in "in person,
  /// one device" mode.
  ///
  /// [seedDemoAgents] adds two demo agents; a new operation leaves it false.
  static Future<Composition> inProcess(
    AssetBundle bundle, {
    bool seedDemoAgents = true,
  }) async => Composition(
    operation: await SessionOperationService.open(
      await loadPackFiles(bundle),
      seedDemoAgents: seedDemoAgents,
    ),
  );

  /// The running operation.
  final OperationService operation;
}
