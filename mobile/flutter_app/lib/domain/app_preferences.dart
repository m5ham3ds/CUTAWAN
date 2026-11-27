enum AppThemeMode { system, light, dark }
enum AppLanguage { system, arabic, english }
enum AppAccentColor { red, blue, orange, purple, yellow }

class AppPreferences {
  const AppPreferences({
    this.themeMode = AppThemeMode.system,
    this.language = AppLanguage.system,
    this.accentColor = AppAccentColor.red,
    this.reduceMotion = false,
  });

  final AppThemeMode themeMode;
  final AppLanguage language;
  final AppAccentColor accentColor;
  final bool reduceMotion;

  AppPreferences copyWith({
    AppThemeMode? themeMode,
    AppLanguage? language,
    AppAccentColor? accentColor,
    bool? reduceMotion,
  }) =>
      AppPreferences(
        themeMode: themeMode ?? this.themeMode,
        language: language ?? this.language,
        accentColor: accentColor ?? this.accentColor,
        reduceMotion: reduceMotion ?? this.reduceMotion,
      );

  Map<String, Object?> toJson() => {
        'themeMode': themeMode.name,
        'language': language.name,
        'accentColor': accentColor.name,
        'reduceMotion': reduceMotion,
      };

  factory AppPreferences.fromJson(Map<String, dynamic> json) {
    T readEnum<T extends Enum>(List<T> values, Object? value, T fallback) =>
        values.firstWhere((item) => item.name == value, orElse: () => fallback);

    return AppPreferences(
      themeMode: readEnum(AppThemeMode.values, json['themeMode'], AppThemeMode.system),
      language: readEnum(AppLanguage.values, json['language'], AppLanguage.system),
      accentColor: readEnum(AppAccentColor.values, json['accentColor'], AppAccentColor.red),
      reduceMotion: json['reduceMotion'] as bool? ?? false,
    );
  }
}
