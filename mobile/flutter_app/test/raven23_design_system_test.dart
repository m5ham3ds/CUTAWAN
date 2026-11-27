import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/design/app_palette.dart';
import 'package:cutawan_mobile/theme/cutawan_theme.dart';

void main() {
  test('RAVEN23 palette roles resolve in dark and light modes', () {
    final dark = AppPalette.fromTheme(CutawanTheme.dark());
    expect(dark.page, const Color(0xFF111315));
    expect(dark.foreground, const Color(0xFFF7F7F7));
    expect(dark.secondaryText, const Color(0xFFD6D7D7));
    expect(dark.mutedText, const Color(0xFFA7A8A8));

    final light = AppPalette.fromTheme(CutawanTheme.light());
    expect(light.page, const Color(0xFFFCFCFD));
    expect(light.foreground, const Color(0xFF141516));
    expect(light.secondaryText, const Color(0xFF2F3134));
    expect(light.mutedText, const Color(0xFF5C5F63));
    expect(light.onFocus, Colors.white);
  });

  test('buttons, chips and cards use neutral ink instead of the accent', () {
    for (final theme in [CutawanTheme.dark(), CutawanTheme.light()]) {
      final ink = theme.colorScheme.onSurface;
      final page = theme.colorScheme.surface;
      expect(theme.filledButtonTheme.style?.backgroundColor?.resolve({}), ink);
      expect(theme.filledButtonTheme.style?.foregroundColor?.resolve({}), page);
      expect(theme.outlinedButtonTheme.style?.foregroundColor?.resolve({}), ink);
      expect(theme.textButtonTheme.style?.foregroundColor?.resolve({}), ink);
      expect(theme.chipTheme.selectedColor, ink);
      expect(theme.navigationBarTheme.indicatorColor, Colors.transparent);
      expect(theme.cardTheme.elevation, 0);
    }
  });
}
