import 'engine_version.dart';
import 'messages.dart';
import 'refusal_reason.dart';

/// Applies the version rules to a `hello` (03 §Version negotiation, 1 to 3).
///
/// Returns the [Refused] to send, or null when the client may join. The rules
/// run in order and the first failure wins:
///
/// 1. [clientProtocol] must equal [hostProtocol].
/// 2. [clientEngine]'s major must equal [operationEngineMajor].
/// 3. [clientEngine] must be at least [requiredEngine], the highest `e` on any
///    event so far (null for an operation with no events yet).
///
/// Rule 4 (the pack) is not a refusal: clients fetch the pinned pack.
Refused? negotiateHello({
  required int clientProtocol,
  required EngineVersion clientEngine,
  required int hostProtocol,
  required int operationEngineMajor,
  EngineVersion? requiredEngine,
}) {
  if (clientProtocol != hostProtocol) {
    return Refused(
      reason: RefusalReason.protocolMismatch,
      hostProtocolMajor: hostProtocol,
    );
  }
  if (clientEngine.major != operationEngineMajor) {
    return Refused(
      reason: RefusalReason.engineMajorMismatch,
      operationEngineMajor: operationEngineMajor,
    );
  }
  if (requiredEngine != null && clientEngine < requiredEngine) {
    return Refused(
      reason: RefusalReason.updateRequired,
      requiredEngineVersion: requiredEngine,
    );
  }
  return null;
}
