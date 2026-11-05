/// One Firestore document: its path, decoded fields and timestamps.
class FirestoreDocument {
  /// Creates a document.
  const FirestoreDocument({
    required this.path,
    required this.data,
    this.createTime,
    this.updateTime,
    this.updateToken,
  });

  /// Path relative to the database root, for example `campaigns/abc`.
  final String path;

  /// The decoded fields.
  final Map<String, Object?> data;

  /// When the document was created, when the server sent it.
  final DateTime? createTime;

  /// When the document last changed, when the server sent it.
  final DateTime? updateTime;

  /// The server's update time exactly as sent (nanosecond precision). Pass it
  /// as `ifUpdateToken` for an optimistic write; [updateTime] has lost the
  /// nanoseconds and would not match.
  final String? updateToken;

  /// The last path segment.
  String get id => path.substring(path.lastIndexOf('/') + 1);

  @override
  String toString() => 'FirestoreDocument($path)';
}
