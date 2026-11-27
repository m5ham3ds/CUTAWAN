import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/theme/cutawan_theme.dart';

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('keyboard focus outlines retain 3:1 contrast in light and dark themes',
      () {
    final themes = [
      CutawanTheme.light(),
      CutawanTheme.dark(),
    ];
    const focused = {WidgetState.focused};

    for (final theme in themes) {
      final scheme = theme.colorScheme;
      final iconOutline = theme.iconButtonTheme.style?.side?.resolve(focused);
      final filledOutline =
          theme.filledButtonTheme.style?.side?.resolve(focused);
      final filledBackground = theme.filledButtonTheme.style?.backgroundColor
          ?.resolve(const <WidgetState>{}) ?? scheme.onSurface;
      final outlinedOutline =
          theme.outlinedButtonTheme.style?.side?.resolve(focused);
      final textOutline =
          theme.textButtonTheme.style?.side?.resolve(focused);
      final inputBorder =
          theme.inputDecorationTheme.focusedBorder as OutlineInputBorder;
      final inputSurface =
          theme.inputDecorationTheme.fillColor ?? scheme.surface;

      expect(iconOutline, isNotNull);
      expect(filledOutline, isNotNull);
      expect(outlinedOutline, isNotNull);
      expect(textOutline, isNotNull);

      expect(iconOutline!.width, greaterThanOrEqualTo(2));
      expect(filledOutline!.width, greaterThanOrEqualTo(2));
      expect(outlinedOutline!.width, greaterThanOrEqualTo(2));
      expect(textOutline!.width, greaterThanOrEqualTo(2));

      expect(
        _contrastRatio(iconOutline.color, scheme.surface),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrastRatio(filledOutline.color, filledBackground),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrastRatio(outlinedOutline.color, scheme.surface),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrastRatio(textOutline.color, scheme.surface),
        greaterThanOrEqualTo(3),
      );
      expect(inputBorder.borderSide.width, greaterThanOrEqualTo(1.5));
      expect(
        _contrastRatio(inputBorder.borderSide.color, inputSurface),
        greaterThanOrEqualTo(3),
      );

      // ListTile, SwitchListTile and chips share Flutter's keyboard focus overlay.
      expect(theme.focusColor, isNotNull);
    }
  });
}
