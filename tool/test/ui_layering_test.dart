import 'dart:io';

import 'package:bard_tool/ui_layering.dart';
import 'package:test/test.dart';

void main() {
  group('ui layering', () {
    test('a view importing a service is reported', () {
      expect(
        checkUiLayering(
          'apps/bard/lib/ui/table/table_panel.dart',
          "import 'package:flutter/material.dart';\n"
              "import '../../data/models.dart';\n"
              "import '../../data/services/episode_service.dart';\n",
        ),
        [
          'apps/bard/lib/ui/table/table_panel.dart:3: '
              '../../data/services/episode_service.dart',
        ],
      );
    });

    test('exports and package URIs count too', () {
      expect(
        checkUiLayering(
          'apps/bard/lib/ui/home/home_screen.dart',
          'export "package:bard/data/services/npc_notes_service.dart";\n',
        ),
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

    test('models and other folders pass', () {
      expect(
        checkUiLayering(
          'apps/bard/lib/ui/console/npc_notes_panel.dart',
          "import '../../data/models.dart';\n"
              "// import '../../data/services/old.dart';\n",
        ),
        isEmpty,
      );
    });

    test('the repository passes', () {
      final root = Directory.current.parent.path;
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
