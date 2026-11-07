import 'dart:io';

import 'package:bard_tool/ui_layering.dart';
import 'package:test/test.dart';

const view = 'apps/bard/lib/ui/table/table_panel.dart';

List<String> check(String text) => checkUiLayering(view, text);

/// The repository root, whether the tests run from `tool/` or the root.
String repoRoot() {
  final here = Directory.current.path;
  return Directory('$here/tool').existsSync()
      ? here
      : Directory.current.parent.path;
}

void main() {
  group('ui layering', () {
    test('a view importing a service is reported', () {
      expect(
        check(
          "import 'package:flutter/material.dart';\n"
          "import '../../data/models.dart';\n"
          "import '../../data/services/episode_service.dart';\n",
        ),
        ['$view:3: ../../data/services/episode_service.dart'],
      );
    });

    test('exports, parts and package URIs count too', () {
      expect(
        check(
          'export "package:bard/data/services/npc_notes_service.dart";\n'
          "part '../../data/services/x.dart';\n",
        ),
        hasLength(2),
      );
    });

    test('the composition root is out of reach too', () {
      expect(check("import '../../app/composition.dart';\n"), hasLength(1));
      expect(check("import 'package:bard/app/routes.dart';\n"), hasLength(1));
    });

    test('conditional, split and dotted imports are read', () {
      expect(
        check(
          "import 'package:flutter/material.dart'\n"
          "    if (dart.library.io) '../../data/services/a.dart';\n",
        ),
        ['$view:2: ../../data/services/a.dart'],
      );
      expect(check("import\n  '../../data/services/b.dart';\n"), [
        '$view:2: ../../data/services/b.dart',
      ]);
      expect(check("import '../../data/./services/c.dart';\n"), hasLength(1));
      expect(
        check("import '../shared/../../data/services/d.dart';\n"),
        hasLength(1),
      );
    });

    test('a view model may call a service', () {
      expect(
        checkUiLayering(
          'apps/bard/lib/ui/console/console_view_model.dart',
          "import '../../data/services/episode_service.dart';\n",
        ),
        isEmpty,
      );
    });

    test('models, other packages and comments pass', () {
      expect(
        check(
          "import '../../data/models.dart';\n"
          "import 'package:backend/data/services/x.dart';\n"
          "// import '../../data/services/old.dart';\n"
          "/* import '../../data/services/older.dart'; */\n",
        ),
        isEmpty,
      );
    });

    test('the repository passes', () {
      final root = repoRoot();
      final files = uiLayeringFiles(root);
      expect(files, isNotEmpty);
      expect([
        for (final path in files)
          ...checkUiLayering(path, File('$root/$path').readAsStringSync()),
      ], isEmpty);
    });

    test('a missing folder fails clearly', () {
      expect(() => uiLayeringFiles('/nonexistent'), throwsStateError);
    });
  });
}
