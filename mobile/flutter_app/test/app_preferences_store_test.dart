import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/domain/app_preferences.dart';
import 'package:cutawan_mobile/services/app_preferences_store.dart';

void main() {
  test('app preferences default to system language, red accent, and normal motion', () {
    const preferences = AppPreferences();
    expect(preferences.themeMode, AppThemeMode.system);
    expect(preferences.language, AppLanguage.system);
    expect(preferences.accentColor, AppAccentColor.red);
    expect(preferences.reduceMotion, isFalse);
  });

  test('theme and reduced-motion preferences survive store recreation', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cutawan-app-preferences-',
    );
    addTearDown(() => directory.delete(recursive: true));

    final firstStore = AppPreferencesStore(
      directoryProvider: () async => directory,
    );
    await firstStore.load();
    await firstStore.update(
      const AppPreferences(
        themeMode: AppThemeMode.dark,
        language: AppLanguage.english,
        accentColor: AppAccentColor.purple,
        reduceMotion: true,
      ),
    );
    firstStore.dispose();

    final restoredStore = AppPreferencesStore(
      directoryProvider: () async => directory,
    );
    addTearDown(restoredStore.dispose);
    await restoredStore.load();

    expect(restoredStore.preferences.value.themeMode, AppThemeMode.dark);
    expect(restoredStore.preferences.value.language, AppLanguage.english);
    expect(restoredStore.preferences.value.accentColor, AppAccentColor.purple);
    expect(restoredStore.preferences.value.reduceMotion, isTrue);
  });

  test('unknown saved theme values safely fall back to system mode', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cutawan-app-preferences-invalid-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      directory.path + Platform.pathSeparator + AppPreferencesStore.fileName,
    );
    await file.writeAsString(
      '{"themeMode":"unknown","reduceMotion":true}',
    );

    final store = AppPreferencesStore(
      directoryProvider: () async => directory,
    );
    addTearDown(store.dispose);
    await store.load();

    expect(store.preferences.value.themeMode, AppThemeMode.system);
    expect(store.preferences.value.language, AppLanguage.system);
    expect(store.preferences.value.accentColor, AppAccentColor.red);
    expect(store.preferences.value.reduceMotion, isTrue);
  });
}
