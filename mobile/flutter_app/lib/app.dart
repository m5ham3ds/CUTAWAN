import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'domain/app_preferences.dart';
import 'l10n/app_strings.dart';
import 'screens/home_shell.dart';
import 'services/app_preferences_store.dart';
import 'services/local_project_repository.dart';
import 'theme/cutawan_theme.dart';

class CutawanApp extends StatefulWidget {
  const CutawanApp({
    super.key,
    this.repository,
    this.storageUsageBytes,
    this.settingsStore,
  });

  final LocalProjectRepository? repository;
  final Future<int> Function()? storageUsageBytes;
  final AppPreferencesStore? settingsStore;

  @override
  State<CutawanApp> createState() => _CutawanAppState();
}

class _CutawanAppState extends State<CutawanApp> {
  late final AppPreferencesStore _settingsStore;
  late final bool _ownsSettingsStore;

  @override
  void initState() {
    super.initState();
    _ownsSettingsStore = widget.settingsStore == null;
    _settingsStore = widget.settingsStore ?? AppPreferencesStore();
    unawaited(_settingsStore.load());
  }

  @override
  void dispose() {
    if (_ownsSettingsStore) _settingsStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _settingsStore.preferences,
      builder: (context, preferences, _) {
        final themeMode = switch (preferences.themeMode) {
          AppThemeMode.system => ThemeMode.system,
          AppThemeMode.light => ThemeMode.light,
          AppThemeMode.dark => ThemeMode.dark,
        };
        final locale = switch (preferences.language) {
          AppLanguage.system => null,
          AppLanguage.arabic => const Locale('ar'),
          AppLanguage.english => const Locale('en'),
        };
        return MaterialApp(
          title: 'Cutawan',
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            if (preferences.language == AppLanguage.arabic) {
              return const Locale('ar');
            }
            if (preferences.language == AppLanguage.english) {
              return const Locale('en');
            }
            return deviceLocale?.languageCode.toLowerCase() == 'ar'
                ? const Locale('ar')
                : const Locale('en');
          },
          theme: CutawanTheme.light(accentColor: preferences.accentColor),
          darkTheme: CutawanTheme.dark(accentColor: preferences.accentColor),
          themeMode: themeMode,
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                disableAnimations:
                    media.disableAnimations || preferences.reduceMotion,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: HomeShell(
            repository: widget.repository,
            storageUsageBytes: widget.storageUsageBytes,
            settingsStore: _settingsStore,
          ),
        );
      },
    );
  }
}
