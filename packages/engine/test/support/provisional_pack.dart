import 'dart:convert';
import 'dart:io';

/// The provisional pack as it ships, as `loadPack` input: the generated,
/// annotation-free copy that `tool/build_pack.sh` writes to
/// `packages/content_core/assets/generated/example-core/`.
///
/// Reading the generated pack, rather than stripping here, keeps one
/// stripper (`tool/lib/annotation_stripper.dart`). `tool/check_all.sh` and CI
/// build it before the tests; locally, run `bash tool/build_pack.sh` first.
Map<String, String> provisionalPackFiles() {
  final root = Directory('../content_core/assets/generated/example-core');
  if (!root.existsSync()) {
    throw StateError(
      'The generated pack is missing. Run `bash tool/build_pack.sh` from the '
      'repository root first.',
    );
  }
  final files = <String, String>{};
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    final relative = entity.path
        .substring(root.path.length + 1)
        .replaceAll(r'\', '/');
    // Round-trip through the decoder so the loader sees the same JSON text
    // regardless of how the build formatted it.
    files[relative] = jsonEncode(jsonDecode(entity.readAsStringSync()));
  }
  return files;
}
