import 'package:flutter/material.dart';

class CutawanTheme {
  const CutawanTheme._();

  static const Color seed = Color(0xFFC8F169);
  static const Color ink = Color(0xFF0B0D0C);
  static const Color panel = Color(0xFF131715);
  static const Color panelRaised = Color(0xFF1A201C);
  static const Color line = Color(0xFF29312C);
  static const Color acid = Color(0xFFC8F169);
  static const Color cyan = Color(0xFF78D7CF);
  static const Color warning = Color(0xFFF4BD65);
  static const Color danger = Color(0xFFF07878);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    const accent = Color(0xFF9BCB4B);
    final scheme = ColorScheme.fromSeed(seedColor: dark ? acid : accent, brightness: brightness).copyWith(
      primary: dark ? acid : const Color(0xFF42651D),
      onPrimary: dark ? ink : Colors.white,
      secondary: dark ? cyan : const Color(0xFF24766F),
      surface: dark ? ink : const Color(0xFFF4F6F0),
      onSurface: dark ? const Color(0xFFF1F4EF) : const Color(0xFF171B17),
      surfaceContainer: dark ? panel : Colors.white,
      surfaceContainerHigh: dark ? panelRaised : const Color(0xFFE8EEE4),
      surfaceContainerHighest: dark ? const Color(0xFF202822) : const Color(0xFFE0E8DA),
      outline: dark ? line : const Color(0xFFD3DCCF),
      outlineVariant: dark ? const Color(0xFF222B25) : const Color(0xFFE1E7DC),
      error: dark ? danger : const Color(0xFFB43E3E),
    );
    final surface = dark ? panel : Colors.white;
    final border = scheme.outlineVariant;
    final keyboardFocusFill =
        scheme.primary.withValues(alpha: dark ? 0.30 : 0.16);
    final keyboardFocusOverlay = WidgetStateProperty.resolveWith<Color?>(
      (states) {
        if (states.contains(WidgetState.focused)) return keyboardFocusFill;
        if (states.contains(WidgetState.hovered)) {
          return scheme.primary.withValues(alpha: dark ? 0.18 : 0.09);
        }
        return null;
      },
    );
    final keyboardFocusOutline = WidgetStateProperty.resolveWith<BorderSide?>(
      (states) => states.contains(WidgetState.focused)
          ? BorderSide(color: scheme.onSurface, width: 2.2)
          : null,
    );
    final keyboardFocusFilledOutline =
        WidgetStateProperty.resolveWith<BorderSide?>(
      (states) => states.contains(WidgetState.focused)
          ? BorderSide(color: scheme.onPrimary, width: 2.2)
          : null,
    );
    final text = ThemeData(brightness: brightness, useMaterial3: true).textTheme;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      focusColor: keyboardFocusFill,
      hoverColor: scheme.primary.withValues(alpha: dark ? 0.16 : 0.08),
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      fontFamily: 'Poppins',
      textTheme: text.copyWith(
        displaySmall: text.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1.2, height: 1.04),
        headlineLarge: text.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1.0, height: 1.05),
        headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.7, height: 1.08),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.45),
        bodySmall: text.bodySmall?.copyWith(height: 1.4),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface, foregroundColor: scheme.onSurface,
        elevation: 0, scrolledUnderElevation: 0, centerTitle: false,
        titleTextStyle: TextStyle(color: scheme.onSurface, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      listTileTheme: ListTileThemeData(
        focusColor: keyboardFocusFill,
        hoverColor: scheme.primary.withValues(alpha: dark ? 0.16 : 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          overlayColor: keyboardFocusOverlay,
          side: keyboardFocusOutline,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface, elevation: 0, margin: EdgeInsets.zero, clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: dark ? const Color(0xFF101512) : const Color(0xFFF8FAF5),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide(color: scheme.primary, width: 1.6)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF101411) : Colors.white,
        indicatorColor: scheme.primary.withValues(alpha: dark ? 0.18 : 0.13),
        height: 72, elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 10, letterSpacing: 0.1,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
        )),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: border), selectedColor: scheme.primary.withValues(alpha: 0.16),
        backgroundColor: surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        backgroundColor: scheme.primary, foregroundColor: scheme.onPrimary,
        minimumSize: const Size(0, 52), padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      ).copyWith(
        overlayColor: keyboardFocusOverlay,
        side: keyboardFocusFilledOutline,
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface, minimumSize: const Size(0, 48),
        side: BorderSide(color: border), textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ).copyWith(
        overlayColor: keyboardFocusOverlay,
        side: WidgetStateProperty.resolveWith<BorderSide?>((states) =>
          states.contains(WidgetState.focused)
              ? BorderSide(color: scheme.onSurface, width: 2.2)
              : BorderSide(color: border)),
      )),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
        foregroundColor: scheme.primary, textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ).copyWith(
        overlayColor: keyboardFocusOverlay,
        side: keyboardFocusOutline,
      )),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? scheme.onPrimary : null),
        trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? scheme.primary : null),
      ),
      sliderTheme: SliderThemeData(activeTrackColor: scheme.primary, thumbColor: scheme.primary, overlayColor: scheme.primary.withValues(alpha: 0.12)),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? panelRaised : const Color(0xFF202820),
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28)))),
      dialogTheme: DialogThemeData(backgroundColor: surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    );
  }
}
