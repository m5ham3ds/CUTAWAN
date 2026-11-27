import 'package:flutter/material.dart';

import '../design/app_tokens.dart';

class CutawanTheme {
  const CutawanTheme._();

  /// RAVEN23 orange remains a restrained brand/progress accent.
  static const Color accent = Color(0xFFF57C00);
  static const Color darkPage = Color(0xFF111315);
  static const Color lightPage = Color(0xFFFCFCFD);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final page = dark ? darkPage : lightPage;
    final ink = dark ? const Color(0xFFF7F7F7) : const Color(0xFF141516);
    final muted = dark ? const Color(0xFFA7A8A8) : const Color(0xFF5C5F63);
    final secondary = dark ? const Color(0xFFD6D7D7) : const Color(0xFF2F3134);
    Color lift(double alpha) =>
        Color.alphaBlend(ink.withValues(alpha: alpha), page);

    final surface = lift(dark ? 0.045 : 0.035);
    final raised = lift(dark ? 0.085 : 0.07);
    final hairline = ink.withValues(alpha: 0.12);
    final outline = ink.withValues(alpha: 0.24);
    final overlay = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed)) {
        return ink.withValues(alpha: 0.12);
      }
      if (states.contains(WidgetState.focused)) {
        return ink.withValues(alpha: 0.10);
      }
      if (states.contains(WidgetState.hovered)) {
        return ink.withValues(alpha: 0.06);
      }
      return null;
    });
    final surfaceFocusSide =
        WidgetStateProperty.resolveWith<BorderSide?>((states) {
      if (states.contains(WidgetState.focused)) {
        return BorderSide(color: ink, width: 2);
      }
      return null;
    });
    final filledFocusSide =
        WidgetStateProperty.resolveWith<BorderSide?>((states) {
      if (states.contains(WidgetState.focused)) {
        return BorderSide(color: page, width: 2);
      }
      return null;
    });

    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(
      primary: accent,
      onPrimary: const Color(0xFF201A17),
      primaryContainer: raised,
      onPrimaryContainer: ink,
      secondary: secondary,
      onSecondary: page,
      secondaryContainer: surface,
      onSecondaryContainer: ink,
      tertiary: muted,
      onTertiary: page,
      tertiaryContainer: raised,
      onTertiaryContainer: ink,
      error: dark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E),
      onError: dark ? const Color(0xFF690005) : Colors.white,
      errorContainer:
          dark ? const Color(0xFF5B1B1B) : const Color(0xFFF9DEDC),
      onErrorContainer:
          dark ? const Color(0xFFFFDAD6) : const Color(0xFF410E0B),
      surface: page,
      onSurface: ink,
      onSurfaceVariant: muted,
      surfaceContainerLowest: page,
      surfaceContainerLow: lift(dark ? 0.025 : 0.02),
      surfaceContainer: surface,
      surfaceContainerHigh: raised,
      surfaceContainerHighest: lift(dark ? 0.12 : 0.10),
      outline: outline,
      outlineVariant: hairline,
    );

    final text = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: AppType.regular,
    ).textTheme.apply(
      bodyColor: ink,
      displayColor: ink,
      fontFamily: AppType.regular,
    );

    final filledStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
      backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) =>
          states.contains(WidgetState.disabled) ? raised : ink),
      foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) =>
          states.contains(WidgetState.disabled) ? muted : page),
      overlayColor: overlay,
      side: filledFocusSide,
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
      ),
      textStyle: const WidgetStatePropertyAll(AppType.button),
      elevation: const WidgetStatePropertyAll(0),
    );
    final outlinedStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
      foregroundColor: WidgetStatePropertyAll(ink),
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: overlay,
      side: WidgetStateProperty.resolveWith<BorderSide?>((states) =>
          states.contains(WidgetState.focused)
              ? BorderSide(color: ink, width: 2)
              : BorderSide(color: outline)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
      ),
      textStyle: const WidgetStatePropertyAll(AppType.button),
    );
    final textButtonStyle = ButtonStyle(
      foregroundColor: WidgetStatePropertyAll(ink),
      overlayColor: overlay,
      side: surfaceFocusSide,
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
      ),
      textStyle: const WidgetStatePropertyAll(AppType.button),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: page,
      canvasColor: page,
      focusColor: ink.withValues(alpha: 0.10),
      hoverColor: ink.withValues(alpha: 0.06),
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      fontFamily: AppType.regular,
      textTheme: text.copyWith(
        displayLarge: AppType.heroTitle.copyWith(color: ink),
        displayMedium: AppType.pageTitle.copyWith(color: ink),
        displaySmall: AppType.pageTitle.copyWith(color: ink),
        headlineLarge: AppType.pageTitle.copyWith(color: ink),
        headlineMedium: AppType.sectionHeader.copyWith(color: ink),
        headlineSmall: AppType.sectionHeader.copyWith(color: ink),
        titleLarge: AppType.sectionHeader.copyWith(color: ink),
        titleMedium: AppType.cardTitle.copyWith(color: ink),
        titleSmall: AppType.cardTitle.copyWith(color: ink),
        bodyLarge: AppType.body.copyWith(color: ink),
        bodyMedium: AppType.body.copyWith(color: ink),
        bodySmall: AppType.metadata.copyWith(color: muted),
        labelLarge: AppType.button.copyWith(color: ink),
        labelMedium: AppType.metadata.copyWith(color: muted),
        labelSmall: AppType.kicker.copyWith(color: muted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: page,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppType.sectionHeader.copyWith(color: ink),
        iconTheme: IconThemeData(color: muted),
      ),
      iconTheme: IconThemeData(color: muted),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          tapTargetSize: MaterialTapTargetSize.padded,
          foregroundColor: WidgetStatePropertyAll(muted),
          overlayColor: overlay,
          side: surfaceFocusSide,
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.button),
            ),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: hairline),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        minVerticalPadding: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: filledStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: filledStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedStyle),
      textButtonTheme: TextButtonThemeData(style: textButtonStyle),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: AppType.body.copyWith(color: muted),
        labelStyle: AppType.body.copyWith(color: muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
          borderSide: BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
          borderSide: BorderSide(color: ink.withValues(alpha: 0.60), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        prefixIconColor: muted,
        suffixIconColor: muted,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ink.withValues(alpha: 0.08),
        selectedColor: ink,
        disabledColor: raised,
        secondarySelectedColor: ink,
        side: BorderSide.none,
        showCheckmark: false,
        labelStyle: AppType.metadata.copyWith(color: ink),
        secondaryLabelStyle: AppType.metadata.copyWith(color: page),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: ink,
        unselectedLabelColor: muted,
        indicatorColor: ink,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: AppType.button,
        unselectedLabelStyle: AppType.metadata,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: page,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 60,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) =>
            AppType.metadata.copyWith(
              color: states.contains(WidgetState.selected) ? ink : muted,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            )),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) =>
              states.contains(WidgetState.selected) ? page : ink),
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) =>
              states.contains(WidgetState.selected) ? ink : surface),
          side: const WidgetStatePropertyAll(BorderSide.none),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.button),
            ),
          ),
          overlayColor: overlay,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) =>
            states.contains(WidgetState.selected) ? Colors.white : muted),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) =>
            states.contains(WidgetState.selected)
                ? accent
                : ink.withValues(alpha: 0.14)),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) =>
            states.contains(WidgetState.selected) ? accent : Colors.transparent),
        checkColor: const WidgetStatePropertyAll(Colors.black),
        side: BorderSide(color: muted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) =>
            states.contains(WidgetState.selected) ? accent : muted),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: muted,
        linearTrackColor: raised,
        circularTrackColor: raised,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: raised,
        foregroundColor: ink,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: raised,
        contentTextStyle: AppType.body.copyWith(color: ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sheet),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        textStyle: AppType.body.copyWith(color: ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: hairline),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionHandleColor: accent,
        selectionColor: accent.withValues(alpha: 0.22),
      ),
    );
  }
}
