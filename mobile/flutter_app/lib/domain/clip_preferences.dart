enum ClipAspectRatio {
  portrait916,
  square11,
  landscape169,
  original,
}

enum ClipDurationMode {
  automatic,
  seconds15To30,
  seconds30To45,
  seconds30To60,
  seconds60To90,
  custom,
}

class ClipPreferences {
  const ClipPreferences({
    this.requestedClipCount = 20,
    this.durationMode = ClipDurationMode.automatic,
    this.customMinimumSeconds = 15,
    this.customMaximumSeconds = 90,
    this.aspectRatio = ClipAspectRatio.portrait916,
    this.resolution = '1080p',
    this.captionsEnabled = true,
    this.speakerTrackingEnabled = true,
    this.captionStyleId = 'beast',
    this.captionAnimationId = 'word_pop',
    this.mainTextColor = '#FFFFFF',
    this.highlightColor = '#FFD400',
    this.captionBackgroundColor = '#000000',
  });

  final int requestedClipCount;
  final ClipDurationMode durationMode;
  final int customMinimumSeconds;
  final int customMaximumSeconds;
  final ClipAspectRatio aspectRatio;
  final String resolution;
  final bool captionsEnabled;
  final bool speakerTrackingEnabled;
  final String captionStyleId;
  final String captionAnimationId;
  final String mainTextColor;
  final String highlightColor;
  final String captionBackgroundColor;

  String? validate() {
    if (requestedClipCount < 1 || requestedClipCount > 50) {
      return 'Clip count must be between 1 and 50.';
    }
    if (customMinimumSeconds < 5 ||
        customMaximumSeconds < customMinimumSeconds ||
        customMaximumSeconds > 180) {
      return 'Custom clip duration must be between 5 and 180 seconds.';
    }
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(mainTextColor) ||
        !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(highlightColor) ||
        !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(captionBackgroundColor)) {
      return 'Caption colors must use #RRGGBB hex values.';
    }
    if (captionStyleId.isEmpty || captionAnimationId.isEmpty) {
      return 'Caption style and animation IDs must not be empty.';
    }
    return null;
  }

  Map<String, Object?> toJson() => {
        'requestedClipCount': requestedClipCount,
        'durationMode': durationMode.name,
        'customMinimumSeconds': customMinimumSeconds,
        'customMaximumSeconds': customMaximumSeconds,
        'aspectRatio': aspectRatio.name,
        'resolution': resolution,
        'captionsEnabled': captionsEnabled,
        'speakerTrackingEnabled': speakerTrackingEnabled,
        'captionStyleId': captionStyleId,
        'captionAnimationId': captionAnimationId,
        'mainTextColor': mainTextColor,
        'highlightColor': highlightColor,
        'captionBackgroundColor': captionBackgroundColor,
      };

  factory ClipPreferences.fromJson(Map<String, dynamic> json) {
    T enumValue<T extends Enum>(List<T> values, Object? value, T fallback) {
      if (value == null) return fallback;
      for (final candidate in values) {
        if (candidate.name == value) return candidate;
      }
      throw FormatException('Unknown enum value: $value');
    }

    final preferences = ClipPreferences(
      requestedClipCount: (json['requestedClipCount'] as num?)?.toInt() ?? 20,
      durationMode: enumValue(
        ClipDurationMode.values,
        json['durationMode'],
        ClipDurationMode.automatic,
      ),
      customMinimumSeconds:
          (json['customMinimumSeconds'] as num?)?.toInt() ?? 15,
      customMaximumSeconds:
          (json['customMaximumSeconds'] as num?)?.toInt() ?? 90,
      aspectRatio: enumValue(
        ClipAspectRatio.values,
        json['aspectRatio'],
        ClipAspectRatio.portrait916,
      ),
      resolution: json['resolution'] as String? ?? '1080p',
      captionsEnabled: json['captionsEnabled'] as bool? ?? true,
      speakerTrackingEnabled:
          json['speakerTrackingEnabled'] as bool? ?? true,
      captionStyleId: json['captionStyleId'] as String? ?? 'beast',
      captionAnimationId: json['captionAnimationId'] as String? ?? 'word_pop',
      mainTextColor: json['mainTextColor'] as String? ?? '#FFFFFF',
      highlightColor: json['highlightColor'] as String? ?? '#FFD400',
      captionBackgroundColor:
          json['captionBackgroundColor'] as String? ?? '#000000',
    );
    final error = preferences.validate();
    if (error != null) throw FormatException(error);
    return preferences;
  }
}
