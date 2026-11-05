import 'package:firebase_dart/auth.dart';

import 'id_token_provider.dart';

/// [IdTokenProvider] backed by `firebase_dart`'s signed-in user (desktop).
///
/// Calls `User.getIdToken` on every request. `firebase_dart` returns its cached
/// token while it is valid and refreshes an expired one itself [V-45]; with
/// `forceRefresh` it always fetches a new token [V-32].
class FirebaseDartIdTokenProvider implements IdTokenProvider {
  /// Creates a provider that reads the user from [currentUser] at call time,
  /// so sign-in and sign-out are picked up without recreating the client.
  FirebaseDartIdTokenProvider(this.currentUser);

  /// Creates a provider for [auth]'s current user.
  factory FirebaseDartIdTokenProvider.fromAuth(FirebaseAuth auth) =>
      FirebaseDartIdTokenProvider(() => auth.currentUser);

  /// Returns the signed-in user, or `null` when signed out.
  final User? Function() currentUser;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = currentUser();
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }
}
