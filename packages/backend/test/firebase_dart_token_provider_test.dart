import 'package:backend/firebase_dart_auth.dart';
import 'package:firebase_dart/auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUser implements User {
  final List<bool> calls = [];

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async {
    calls.add(forceRefresh);
    return 'tok${calls.length}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('signed out gives null', () async {
    final provider = FirebaseDartIdTokenProvider(() => null);
    expect(await provider.getIdToken(), isNull);
  });

  test('asks the current user each time and forwards forceRefresh', () async {
    final user = _FakeUser();
    User? current;
    final provider = FirebaseDartIdTokenProvider(() => current);
    current = user;
    expect(await provider.getIdToken(), 'tok1');
    expect(await provider.getIdToken(forceRefresh: true), 'tok2');
    expect(user.calls, [false, true]);
    current = null;
    expect(await provider.getIdToken(), isNull);
  });
}
