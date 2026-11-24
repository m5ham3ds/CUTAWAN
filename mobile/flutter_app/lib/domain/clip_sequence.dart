import 'clip_candidate.dart';

enum ClipSequenceTrackType { video, audio, overlay }

class ClipSequenceTrack {
  const ClipSequenceTrack({
    required this.id,
    required this.type,
    required this.name,
    required this.order,
  });

  final String id;
  final ClipSequenceTrackType type;
  final String name;
  final int order;

  void validate() {
    if (!_isSafeSequenceId(id) ||
        name.trim().isEmpty ||
        name.trim().length > 80 ||
        order < 0 ||
        order >= ClipSequence.maxTracks) {
      throw const FormatException('Sequence track identity or display order is invalid.');
    }
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.name,
        'name': name,
        'order': order,
      };

  factory ClipSequenceTrack.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? '';
    final matchingTypes =
        ClipSequenceTrackType.values.where((value) => value.name == typeName);
    if (matchingTypes.isEmpty) {
      throw const FormatException('Sequence track type is unsupported.');
    }
    final track = ClipSequenceTrack(
      id: json['id'] as String? ?? '',
      type: matchingTypes.first,
      name: json['name'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? -1,
    );
    track.validate();
    return track;
  }
}

class ClipSequenceItem {
  const ClipSequenceItem({
    required this.id,
    required this.candidateId,
    required this.trackId,
    required this.sourceStartMs,
    required this.sourceEndMs,
    required this.timelineStartMs,
  });

  final String id;
  final String candidateId;
  final String trackId;
  final int sourceStartMs;
  final int sourceEndMs;
  final int timelineStartMs;

  int get durationMs => sourceEndMs - sourceStartMs;
  int get timelineEndMs => timelineStartMs + durationMs;

  void validate() {
    if (!_isSafeSequenceId(id) ||
        !_isSafeSequenceId(candidateId) ||
        !_isSafeSequenceId(trackId) ||
        sourceStartMs < 0 ||
        sourceEndMs <= sourceStartMs ||
        timelineStartMs < 0 ||
        timelineEndMs <= timelineStartMs) {
      throw const FormatException('Sequence clip identity or time range is invalid.');
    }
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'candidateId': candidateId,
        'trackId': trackId,
        'sourceStartMs': sourceStartMs,
        'sourceEndMs': sourceEndMs,
        'timelineStartMs': timelineStartMs,
      };

  factory ClipSequenceItem.fromJson(Map<String, dynamic> json) {
    final item = ClipSequenceItem(
      id: json['id'] as String? ?? '',
      candidateId: json['candidateId'] as String? ?? '',
      trackId: json['trackId'] as String? ?? '',
      sourceStartMs: (json['sourceStartMs'] as num?)?.toInt() ?? -1,
      sourceEndMs: (json['sourceEndMs'] as num?)?.toInt() ?? -1,
      timelineStartMs: (json['timelineStartMs'] as num?)?.toInt() ?? -1,
    );
    item.validate();
    return item;
  }
}

class ClipSequence {
  ClipSequence({
    required this.schemaVersion,
    required this.sourceDurationMs,
    required List<ClipSequenceTrack> tracks,
    required List<ClipSequenceItem> clips,
  })  : tracks = List.unmodifiable(tracks),
        clips = List.unmodifiable(clips);

  factory ClipSequence.empty({required int sourceDurationMs}) => ClipSequence(
        schemaVersion: currentSchemaVersion,
        sourceDurationMs: sourceDurationMs,
        tracks: const [
          ClipSequenceTrack(
            id: 'track_video_main',
            type: ClipSequenceTrackType.video,
            name: 'Main video',
            order: 0,
          ),
        ],
        clips: const [],
      );

  static const currentSchemaVersion = 1;
  static const maxTracks = 16;
  static const maxClips = 500;

  final int schemaVersion;
  final int sourceDurationMs;
  final List<ClipSequenceTrack> tracks;
  final List<ClipSequenceItem> clips;

  void validate({
    required CandidateSet candidateSet,
    required int expectedSourceDurationMs,
  }) {
    candidateSet.validate();
    if (schemaVersion != currentSchemaVersion ||
        sourceDurationMs <= 0 ||
        sourceDurationMs != expectedSourceDurationMs ||
        candidateSet.sourceDurationMs != expectedSourceDurationMs ||
        tracks.isEmpty ||
        tracks.length > maxTracks ||
        clips.length > maxClips) {
      throw const FormatException('Sequence header, track count or clip count is invalid.');
    }

    final tracksById = <String, ClipSequenceTrack>{};
    final trackOrders = <int>{};
    var hasVideoTrack = false;
    for (final track in tracks) {
      track.validate();
      if (tracksById.containsKey(track.id) ||
          !trackOrders.add(track.order)) {
        throw const FormatException('Sequence track IDs and display orders must be unique.');
      }
      tracksById[track.id] = track;
      if (track.type == ClipSequenceTrackType.video) hasVideoTrack = true;
    }
    if (!hasVideoTrack) {
      throw const FormatException('A sequence must contain a video track.');
    }

    final candidatesById = {
      for (final candidate in candidateSet.candidates) candidate.id: candidate,
    };
    final clipIds = <String>{};
    final clipsByTrack = <String, List<ClipSequenceItem>>{};
    for (final clip in clips) {
      clip.validate();
      if (!clipIds.add(clip.id)) {
        throw const FormatException('Sequence clip IDs must be unique.');
      }
      if (!tracksById.containsKey(clip.trackId)) {
        throw const FormatException('Sequence clip references an unknown track.');
      }
      final candidate = candidatesById[clip.candidateId];
      if (candidate == null ||
          clip.sourceStartMs < candidate.startMs ||
          clip.sourceEndMs > candidate.endMs ||
          clip.sourceEndMs > sourceDurationMs) {
        throw const FormatException(
          'Sequence clip source range must remain inside its referenced candidate.',
        );
      }
      clipsByTrack.putIfAbsent(clip.trackId, () => []).add(clip);
    }

    for (final entry in clipsByTrack.entries) {
      final track = tracksById[entry.key]!;
      if (track.type == ClipSequenceTrackType.overlay) continue;
      final ordered = entry.value.toList()
        ..sort((a, b) {
          final byStart = a.timelineStartMs.compareTo(b.timelineStartMs);
          return byStart != 0 ? byStart : a.timelineEndMs.compareTo(b.timelineEndMs);
        });
      var previousEndMs = -1;
      for (final clip in ordered) {
        if (clip.timelineStartMs < previousEndMs) {
          throw FormatException(
            'Clips on ${track.type.name} track ${track.id} cannot overlap without transition support.',
          );
        }
        previousEndMs = clip.timelineEndMs;
      }
    }
  }

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'sourceDurationMs': sourceDurationMs,
        'tracks': tracks.map((track) => track.toJson()).toList(),
        'clips': clips.map((clip) => clip.toJson()).toList(),
      };

  factory ClipSequence.fromJson(Map<String, dynamic> json) {
    final rawTracks = json['tracks'];
    final rawClips = json['clips'];
    if (rawTracks is! List || rawClips is! List) {
      throw const FormatException('Sequence tracks and clips must be arrays.');
    }
    return ClipSequence(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      sourceDurationMs: (json['sourceDurationMs'] as num?)?.toInt() ?? 0,
      tracks: rawTracks.map((value) {
        if (value is! Map) {
          throw const FormatException('Sequence track must be an object.');
        }
        return ClipSequenceTrack.fromJson(Map<String, dynamic>.from(value));
      }).toList(growable: false),
      clips: rawClips.map((value) {
        if (value is! Map) {
          throw const FormatException('Sequence clip must be an object.');
        }
        return ClipSequenceItem.fromJson(Map<String, dynamic>.from(value));
      }).toList(growable: false),
    );
  }
}

bool _isSafeSequenceId(String value) =>
    RegExp(r'^[A-Za-z0-9_-]{3,120}$').hasMatch(value);
