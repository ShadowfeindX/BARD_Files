/// Supplies Firebase Auth ID tokens to the Firestore REST client.
///
/// The client calls [getIdToken] for every request and never keeps the token
/// string (FS2). The desktop implementation wraps `firebase_dart`'s
/// `getIdToken`; tests use a fake.
abstract interface class IdTokenProvider {
  /// Returns a valid ID token. With [forceRefresh] the provider must obtain a
  /// new token instead of returning its cached one (the client uses it after a
  /// 401; callers use it after a role change).
  ///
  /// Returns `null` when nobody is signed in; the request is then sent
  /// without an `Authorization` header and Security Rules decide.
  Future<String?> getIdToken({bool forceRefresh = false});
}
