import 'clip_candidate.dart';

enum ClipSequenceTrackType { video, audio, overlay }

enum ClipSequenceTransitionType { dipToBlack }

class ClipSequenceTransition {
  const ClipSequenceTransition({
    this.type = ClipSequenceTransitionType.dipToBlack,
    required this.durationMs,
  });

  final ClipSequenceTransitionType type;
  final int durationMs;

  void validate() {
    if (durationMs < 200 || durationMs > 2000) {
      throw const FormatException(
        'Dip-to-black transition duration must be between 200 and 2000 ms.',
      );
    }
  }

  Map<String, Object?> toJson() => {
        'type': type.name,
        'durationMs': durationMs,
      };

  factory ClipSequenceTransition.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? '';
    final matchingTypes = ClipSequenceTransitionType.values
        .where((value) => value.name == typeName);
    if (matchingTypes.isEmpty) {
      throw const FormatException('Sequence transition type is unsupported.');
    }
    final transition = ClipSequenceTransition(
      type: matchingTypes.first,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
    );
    transition.validate();
    return transition;
  }
}

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
    this.transitionAfter,
  });

  final String id;
  final String candidateId;
  final String trackId;
  final int sourceStartMs;
  final int sourceEndMs;
  final int timelineStartMs;
  final ClipSequenceTransition? transitionAfter;

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
    transitionAfter?.validate();
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'candidateId': candidateId,
        'trackId': trackId,
        'sourceStartMs': sourceStartMs,
        'sourceEndMs': sourceEndMs,
        'timelineStartMs': timelineStartMs,
        if (transitionAfter != null)
          'transitionAfter': transitionAfter!.toJson(),
      };

  factory ClipSequenceItem.fromJson(Map<String, dynamic> json) {
    final rawTransition = json['transitionAfter'];
    if (rawTransition != null && rawTransition is! Map) {
      throw const FormatException('Sequence transition must be an object.');
    }
    final item = ClipSequenceItem(
      id: json['id'] as String? ?? '',
      candidateId: json['candidateId'] as String? ?? '',
      trackId: json['trackId'] as String? ?? '',
      sourceStartMs: (json['sourceStartMs'] as num?)?.toInt() ?? -1,
      sourceEndMs: (json['sourceEndMs'] as num?)?.toInt() ?? -1,
      timelineStartMs: (json['timelineStartMs'] as num?)?.toInt() ?? -1,
      transitionAfter: rawTransition == null
          ? null
          : ClipSequenceTransition.fromJson(
              Map<String, dynamic>.from(rawTransition as Map),
            ),
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
      final ordered = entry.value.toList()
        ..sort((a, b) {
          final byStart = a.timelineStartMs.compareTo(b.timelineStartMs);
          return byStart != 0 ? byStart : a.timelineEndMs.compareTo(b.timelineEndMs);
        });
      var previousEndMs = -1;
      for (final clip in ordered) {
        if (clip.timelineStartMs < previousEndMs) {
          throw FormatException(
            'Clips on ${track.type.name} track ${track.id} cannot overlap within one Media3 sequence.',
          );
        }
        previousEndMs = clip.timelineEndMs;
      }

      for (var index = 0; index < ordered.length; index++) {
        final clip = ordered[index];
        final transition = clip.transitionAfter;
        if (transition != null) {
          if (track.type != ClipSequenceTrackType.video ||
              index == ordered.length - 1) {
            throw const FormatException(
              'Dip-to-black transitions require a following clip on a video track.',
            );
          }
          final next = ordered[index + 1];
          if (clip.timelineEndMs != next.timelineStartMs) {
            throw const FormatException(
              'Dip-to-black transitions require adjacent clips with no timeline gap.',
            );
          }
        }

        final previousTransition =
            index == 0 ? null : ordered[index - 1].transitionAfter;
        final incomingFadeMs = previousTransition == null
            ? 0
            : previousTransition.durationMs -
                previousTransition.durationMs ~/ 2;
        final outgoingFadeMs =
            transition == null ? 0 : transition.durationMs ~/ 2;
        if (incomingFadeMs + outgoingFadeMs > clip.durationMs) {
          throw const FormatException(
            'Incoming and outgoing transitions exceed the clip duration.',
          );
        }
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
