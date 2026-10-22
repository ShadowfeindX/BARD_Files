import 'package:bard/data/models.dart';
import 'package:engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // SessionOperationService maps BroadcastOp to CompareOp by name.
  test('BroadcastOp names match the engine CompareOp names', () {
    expect(
      [for (final op in BroadcastOp.values) op.name],
      [for (final op in CompareOp.values) op.name],
    );
  });
}
