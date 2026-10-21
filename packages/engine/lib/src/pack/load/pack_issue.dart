/// How serious a pack problem is.
enum IssueSeverity {
  /// The pack cannot be used.
  error,

  /// The pack loads; something is pending, deprecated or worth a look.
  warning,
}

/// One problem found while loading a pack, with where it is.
final class PackIssue {
  /// Creates an issue.
  const PackIssue(
    this.severity,
    this.file,
    this.path,
    this.message, {
    this.pendingD = false,
  });

  /// Error or warning.
  final IssueSeverity severity;

  /// Pack-relative file, such as `skills.json`.
  final String file;

  /// JSON path inside the file, such as `skills[3].attribute`; empty for the
  /// whole file.
  final String path;

  /// What is wrong, in plain words for a pack author.
  final String message;

  /// Whether this warning marks a value that is pending D.
  final bool pendingD;

  /// Whether this is an error.
  bool get isError => severity == IssueSeverity.error;

  @override
  bool operator ==(Object other) =>
      other is PackIssue &&
      other.severity == severity &&
      other.file == file &&
      other.path == path &&
      other.message == message &&
      other.pendingD == pendingD;

  @override
  int get hashCode => Object.hash(severity, file, path, message, pendingD);

  /// One line, as the command-line validator prints it.
  @override
  String toString() {
    final where = path.isEmpty ? file : '$file: $path';
    return '${severity.name}: $where: $message';
  }
}

/// Collects issues while a pack loads.
final class IssueLog {
  final List<PackIssue> _issues = [];

  /// Every issue so far, in the order found.
  List<PackIssue> get issues => List.unmodifiable(_issues);

  /// Whether any error was found.
  bool get hasErrors => _issues.any((i) => i.isError);

  /// Records an error.
  void error(String file, String path, String message) =>
      _issues.add(PackIssue(IssueSeverity.error, file, path, message));

  /// Records a warning.
  void warning(String file, String path, String message) =>
      _issues.add(PackIssue(IssueSeverity.warning, file, path, message));

  /// Records a warning that the value at [path] is pending D.
  void pendingD(String file, String path) => _issues.add(
    PackIssue(
      IssueSeverity.warning,
      file,
      path,
      'Pending D: no value yet, so the feature that needs it is off.',
      pendingD: true,
    ),
  );
}
