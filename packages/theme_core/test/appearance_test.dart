import 'dart:convert';

import 'package:test/test.dart';
import 'package:theme_core/theme_core.dart';

import 'support.dart';

void main() {
  final resolver = ThemeResolver(
    builtIns: loadBuiltIns(),
    custom: [decodeOk(derivedJson(id: 'mine'))],
  );
  AppliedAppearance apply(AppearanceSetting s, ThemeBrightness b) =>
      applyAppearance(s, resolver, osBrightness: b);

  test('first launch is System, normal', () {
    const s = AppearanceSetting.initial();
    expect(s.themeId, systemThemeId);
    expect(s.variant, ThemeVariant.normal);
    expect(s.documentMode, isFalse);
  });

  test('System follows OS brightness and a change switches the theme', () {
    const s = AppearanceSetting.initial();
    expect(apply(s, ThemeBrightness.dark).theme.themeId, 'night-desk');
    expect(apply(s, ThemeBrightness.light).theme.themeId, 'manila');
    expect(apply(s, ThemeBrightness.light).usedSystem, isTrue);
  });

  test('the variant still applies under System', () {
    const s = AppearanceSetting(
      themeId: systemThemeId,
      variant: ThemeVariant.redGreenSafe,
    );
    final a = apply(s, ThemeBrightness.dark);
    expect(a.theme.variant, ThemeVariant.redGreenSafe);
    expect(a.variantUnavailable, isFalse);
  });

  test('a missing theme renders System and keeps the stored setting', () {
    const s = AppearanceSetting(
      themeId: 'deleted',
      variant: ThemeVariant.normal,
    );
    final a = apply(s, ThemeBrightness.light);
    expect(a.themeMissing, isTrue);
    expect(a.theme.themeId, 'manila');
    expect(s.themeId, 'deleted');
  });

  test('a missing variant gives normal, and the stored one comes back', () {
    final j = builtInJson('manila');
    j['id'] = 'plain';
    j['name'] = 'plain';
    (j['variants'] as Map<String, dynamic>).removeWhere(
      (k, _) => k != 'normal',
    );
    final r = ThemeResolver(
      builtIns: loadBuiltIns(),
      custom: [decodeOk(const _Enc().text(j))],
    );
    const stored = AppearanceSetting(
      themeId: 'plain',
      variant: ThemeVariant.redGreenSafe,
    );
    final a = applyAppearance(stored, r, osBrightness: ThemeBrightness.dark);
    expect(a.variantUnavailable, isTrue);
    expect(a.theme.variant, ThemeVariant.normal);
    final back = applyAppearance(
      const AppearanceSetting(
        themeId: 'phosphor',
        variant: ThemeVariant.redGreenSafe,
      ),
      r,
      osBrightness: ThemeBrightness.dark,
    );
    expect(back.variantUnavailable, isFalse);
    expect(back.theme.variant, ThemeVariant.redGreenSafe);
  });

  test('settings round-trip through JSON; bad fields fall back', () {
    final s = AppearanceSetting(
      themeId: 'mine',
      variant: ThemeVariant.blueYellowSafe,
      documentMode: true,
      updatedAt: DateTime.utc(2026, 11, 5, 8),
    );
    final back = AppearanceSetting.fromJson(s.toJson());
    expect(back.themeId, 'mine');
    expect(back.variant, ThemeVariant.blueYellowSafe);
    expect(back.documentMode, isTrue);
    expect(back.updatedAt, s.updatedAt);
    final bad = AppearanceSetting.fromJson({'themeId': 5, 'variant': 'x'});
    expect(bad.themeId, systemThemeId);
    expect(bad.variant, ThemeVariant.normal);
  });

  test('variant label keys exist for the wording to fill in later', () {
    expect(ThemeVariant.highContrast.labelKey, 'themeVariant.highContrast');
  });
}

class _Enc {
  const _Enc();
  String text(Map<String, dynamic> j) => jsonEncode(j);
}
