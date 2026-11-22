import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/app_preferences.dart';

typedef AppPreferencesDirectoryProvider = Future<Directory> Function();

class AppPreferencesStore {
  AppPreferencesStore({
    AppPreferencesDirectoryProvider? directoryProvider,
  }) : _directoryProvider =
            directoryProvider ?? getApplicationSupportDirectory;

  AppPreferencesStore.inMemory() : _directoryProvider = null;

  static const fileName = 'app_preferences.json';

  final AppPreferencesDirectoryProvider? _directoryProvider;
  final ValueNotifier<AppPreferences> preferences =
      ValueNotifier<AppPreferences>(const AppPreferences());

  Future<void>? _loadOperation;
  String? _loadError;
  bool _disposed = false;

  String? get loadError => _loadError;

  Future<void> load() => _loadOperation ??= _loadFromDisk();

  Future<void> _loadFromDisk() async {
    final directoryProvider = _directoryProvider;
    if (directoryProvider == null) return;

    try {
      final directory = await directoryProvider();
      final file = File(
        directory.path + Platform.pathSeparator + fileName,
      );
      if (!await file.exists()) return;

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'App preferences file must contain a JSON object.',
        );
      }
      preferences.value = AppPreferences.fromJson(decoded);
      _loadError = null;
    } catch (error) {
      _loadError = error.toString();
    }
  }

  Future<void> update(AppPreferences next) async {
    if (_disposed) {
      throw StateError('AppPreferencesStore has been disposed.');
    }
    await load();

    final directoryProvider = _directoryProvider;
    if (directoryProvider != null) {
      final directory = await directoryProvider();
      await directory.create(recursive: true);
      final file = File(
        directory.path + Platform.pathSeparator + fileName,
      );
      final temporaryFile = File(file.path + '.tmp');

      try {
        await temporaryFile.writeAsString(
          jsonEncode(next.toJson()),
          flush: true,
        );
        await temporaryFile.rename(file.path);
      } catch (_) {
        if (await temporaryFile.exists()) {
          await temporaryFile.delete();
        }
        rethrow;
      }
    }

    _loadError = null;
    preferences.value = next;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    preferences.dispose();
  }
}
