import 'dart:async';

import 'package:flutter/material.dart';

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
        return MaterialApp(
          title: 'Cutawan',
          debugShowCheckedModeBanner: false,
          theme: CutawanTheme.light(),
          darkTheme: CutawanTheme.dark(),
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
