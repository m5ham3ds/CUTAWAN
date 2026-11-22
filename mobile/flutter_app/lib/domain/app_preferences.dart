enum AppThemeMode { system, light, dark }

class AppPreferences {
  const AppPreferences({
    this.themeMode = AppThemeMode.system,
    this.reduceMotion = false,
  });

  final AppThemeMode themeMode;
  final bool reduceMotion;

  AppPreferences copyWith({
    AppThemeMode? themeMode,
    bool? reduceMotion,
  }) =>
      AppPreferences(
        themeMode: themeMode ?? this.themeMode,
        reduceMotion: reduceMotion ?? this.reduceMotion,
      );

  Map<String, Object?> toJson() => {
        'themeMode': themeMode.name,
        'reduceMotion': reduceMotion,
      };

  factory AppPreferences.fromJson(Map<String, dynamic> json) {
    final themeName = json['themeMode'];
    final themeMode = AppThemeMode.values.firstWhere(
      (mode) => mode.name == themeName,
      orElse: () => AppThemeMode.system,
    );
    return AppPreferences(
      themeMode: themeMode,
      reduceMotion: json['reduceMotion'] as bool? ?? false,
    );
  }
}
