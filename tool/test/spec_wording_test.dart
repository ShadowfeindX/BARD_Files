import 'dart:io';

import 'package:bard_tool/spec_wording.dart';
import 'package:test/test.dart';

List<String> check(String text) => checkSpecWording('x.md', text);

void main() {
  group('spec wording', () {
    test('plain design text passes', () {
      expect(
        check(
          'The host refuses a frame longer than `maxFrameLength`.\n'
          'The Handler decides the DC (Proposed, open: [T4](09.md#t4)).\n'
          'Engine developers (R, D) read the warnings [V-20].\n'
          'Computed for this spec (Python, 2026-11-04).',
        ),
        isEmpty,
      );
    });

    test('attributions and dated decisions are reported', () {
      expect(check('R ruled on 2026-11-05 (T12) that tokens follow A.'), [
        'x.md:1: decision attribution: "R ruled"',
        'x.md:1: dated decision: "ruled on 2026-11-05"',
      ]);
      expect(check('Labels agreed by D, 2026-11-05, T13.'), hasLength(2));
      expect(check('Players never see co-recipients (R, 2026-10-21).'), [
        'x.md:1: dated decision: "R, 2026-10-21"',
      ]);
      expect(check('Shared outside the app (D).'), hasLength(1));
      expect(check("This follows R's ruling."), hasLength(1));
    });

    test('status labels, history and review narrative are reported', () {
      expect(check('### Envelope (Fixed)'), hasLength(1));
      expect(check('**Ruled.** The box clears.'), hasLength(1));
      expect(
        check('The earlier proposal of an opt-out is gone.'),
        hasLength(1),
      );
      expect(check('From the gate review of the engine core:'), hasLength(1));
    });

    test('fenced code blocks are skipped', () {
      expect(check('```\nR ruled on 2026-11-05\n```\nPlain text.'), isEmpty);
    });

    test('an unclosed fence is reported', () {
      expect(check('```\nR ruled on 2026-11-05'), [
        'x.md:2: unclosed code fence',
      ]);
    });

    test('only chapters 00 to 08, the developer guide and ui-kit are read', () {
      final root = Directory.systemTemp.createTempSync('spec_wording');
      addTearDown(() => root.deleteSync(recursive: true));
      for (final path in [
        'docs/architecture/00-overview.md',
        'docs/architecture/08-testing.md',
        'docs/architecture/09-open-decisions.md',
        'docs/architecture/10-waiting-on-d.md',
        'docs/architecture/11-supplemental-features.md',
        'docs/architecture/decision-record.md',
        'docs/architecture/README.md',
        'docs/developer-guide/setup.md',
        'docs/ui-kit.md',
      ]) {
        File('${root.path}/$path').createSync(recursive: true);
      }
      expect(specWordingFiles(root.path), [
        'docs/architecture/00-overview.md',
        'docs/architecture/08-testing.md',
        'docs/developer-guide/setup.md',
        'docs/ui-kit.md',
      ]);
    });

    test('a missing docs folder is an error', () {
      final root = Directory.systemTemp.createTempSync('spec_wording');
      addTearDown(() => root.deleteSync(recursive: true));
      expect(() => specWordingFiles(root.path), throwsStateError);
    });

    test('the line number of each finding is reported', () {
      expect(check('Fine.\nApproved by R.'), [
        'x.md:2: decision attribution: "Approved by R"',
      ]);
    });
  });
}
