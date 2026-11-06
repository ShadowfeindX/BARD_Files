import 'package:test/test.dart';
import 'package:theme_core/theme_core.dart';

void main() {
  group('ThemeColor', () {
    test('parses and writes upper-case hex in the stored format', () {
      expect(ThemeColor.tryParse('#aabbcc')!.toHex(), '#AABBCC');
      expect(ThemeColor.tryParse('#aabbcc')!.hasAlpha, isFalse);
      expect(ThemeColor.tryParse('#aabbcc80')!.toHex(), '#AABBCC80');
      expect(ThemeColor.tryParse('#aabbcc80')!.alpha, 0x80);
    });

    test('rejects everything that is not #RRGGBB or #RRGGBBAA', () {
      for (final bad in [
        '',
        '#abc',
        'aabbcc',
        '#aabbc',
        '#aabbccd',
        '#gggggg',
        ' #aabbcc',
        'rgb(1,2,3)',
      ]) {
        expect(ThemeColor.tryParse(bad), isNull, reason: bad);
      }
    });

    test('contrast reproduces the palette-card figures', () {
      const white = ThemeColor.rgb(0xFFFFFF);
      const black = ThemeColor.rgb(0x000000);
      double r(String hex, ThemeColor other) =>
          ThemeColor.tryParse(hex)!.contrastWith(other);
      expect(r('#04650D', white), closeTo(7.31, 0.01));
      expect(r('#DCBFA6', black), closeTo(12.05, 0.01));
      expect(r('#0072B2', white), closeTo(5.19, 0.01));
    });

    test('alpha composites over a surface', () {
      const surface = ThemeColor.rgb(0x000000);
      final half = ThemeColor.tryParse('#FFFFFF80')!.compositeOver(surface);
      expect(half.hasAlpha, isFalse);
      expect(half.rgb, 0x808080);
    });
  });
}
