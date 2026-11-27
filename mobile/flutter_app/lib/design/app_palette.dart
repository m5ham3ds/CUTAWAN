import 'package:flutter/material.dart';

/// Theme-derived neutral colour roles ported from RAVEN23's handheld UI.
@immutable
class AppPalette {
  const AppPalette._({
    required this.dark,
    required this.page,
    required this.surface,
    required this.raisedSurface,
    required this.foreground,
    required this.secondaryText,
    required this.mutedText,
    required this.hairline,
    required this.focusFill,
    required this.onFocus,
    required this.onFocusMuted,
    required this.idleFill,
    required this.idleFillStrong,
    required this.idleFillFaint,
    required this.dim,
  });

  factory AppPalette.fromTheme(ThemeData theme) {
    final dark = theme.colorScheme.brightness == Brightness.dark;
    final page = theme.scaffoldBackgroundColor;
    final ink = dark ? const Color(0xFFF7F7F7) : const Color(0xFF141516);
    Color lift(double alpha) =>
        Color.alphaBlend(ink.withValues(alpha: alpha), page);
    return AppPalette._(
      dark: dark,
      page: page,
      surface: lift(dark ? 0.045 : 0.035),
      raisedSurface: lift(dark ? 0.085 : 0.07),
      foreground: ink,
      secondaryText:
          dark ? const Color(0xFFD6D7D7) : const Color(0xFF2F3134),
      mutedText: dark ? const Color(0xFFA7A8A8) : const Color(0xFF5C5F63),
      hairline: ink.withValues(alpha: 0.12),
      focusFill: ink.withValues(alpha: 0.95),
      onFocus: dark ? Colors.black : Colors.white,
      onFocusMuted: dark ? Colors.black54 : Colors.white70,
      idleFill: ink.withValues(alpha: 0.14),
      idleFillStrong: ink.withValues(alpha: 0.25),
      idleFillFaint: ink.withValues(alpha: 0.08),
      dim: page.withValues(alpha: 0.55),
    );
  }

  static final Expando<AppPalette> _cache =
      Expando<AppPalette>('CutawanAppPalette');

  static AppPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return _cache[theme] ??= AppPalette.fromTheme(theme);
  }

  final bool dark;
  final Color page;
  final Color surface;
  final Color raisedSurface;
  final Color foreground;
  final Color secondaryText;
  final Color mutedText;
  final Color hairline;
  final Color focusFill;
  final Color onFocus;
  final Color onFocusMuted;
  final Color idleFill;
  final Color idleFillStrong;
  final Color idleFillFaint;
  final Color dim;

  Color scrim(double alpha) => page.withValues(alpha: alpha);

  static const logoPlate = Color(0xFFF2F2F3);
}
