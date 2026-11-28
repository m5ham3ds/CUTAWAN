import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import 'package:video_player/video_player.dart';

import '../../domain/caption_catalog.dart';
import '../../domain/clip_candidate.dart';
import '../../domain/clip_edit_overrides.dart';
import '../../domain/clip_preferences.dart';
import '../../domain/project_contract.dart';
import '../../domain/reframe_contract.dart';
import '../../domain/transcript_contract.dart';
import '../../services/android_filmstrip_service.dart';
import '../../services/caption_sidecar_generator.dart';
import '../../services/local_project_repository.dart';
import '../../widgets/clip_preview_viewport.dart';

class ClipEditorPage extends StatefulWidget {
  const ClipEditorPage({
    required this.project,
    required this.candidateSet,
    required this.candidate,
    required this.repository,
    required this.onSaved,
    super.key,
  });

  final CutawanProject project;
  final CandidateSet candidateSet;
  final ClipCandidate candidate;
  final LocalProjectRepository repository;
  final Future<void> Function() onSaved;

  @override
  State<ClipEditorPage> createState() => _ClipEditorPageState();
}

class _ClipEditorPageState extends State<ClipEditorPage> {
  VideoPlayerController? _player;
  final AndroidFilmstripService _filmstripService = const AndroidFilmstripService();
  List<FilmstripFrame> _filmstripFrames = const [];
  bool _filmstripLoading = false;
  String? _filmstripError;
  int _filmstripRequestId = 0;
  late final TextEditingController _titleController;
  late int _startMs;
  late int _endMs;
  late ClipPreferences _draftPreferences;
  ClipFramingMode _framingMode = ClipFramingMode.automatic;
  double _focusX = 0.5;
  double _focusY = 0.5;
  List<ClipFocusKeyframe> _focusKeyframes = const [];
  int _fadeInMs = 0;
  int _fadeOutMs = 0;
  CutawanTranscript? _transcript;
  ReframePlan? _reframePlan;
  List<Map<String, Object?>> _previewCues = const [];
  bool _loading = true;
  bool _loadingArtifacts = true;
  bool _artifactLoadFailed = false;
  bool _saving = false;
  bool _handlingBoundary = false;
  String? _error;
  String? _captionPreviewError;

  @override
  void initState() {
    super.initState();
    _startMs = widget.candidate.startMs;
    _endMs = widget.candidate.endMs;
    _draftPreferences = widget.project.preferences;
    _titleController = TextEditingController(text: widget.candidate.title);
    unawaited(_initializePlayer());
    unawaited(_loadEditorArtifacts());
  }

  Future<void> _initializePlayer() async {
    VideoPlayerController? controller;
    try {
      final uri = Uri.parse(widget.project.source.uri);
      controller = switch (uri.scheme) {
        'content' => VideoPlayerController.contentUri(uri),
        'file' => VideoPlayerController.file(File.fromUri(uri)),
        'http' || 'https' => VideoPlayerController.networkUrl(uri),
        _ => throw FormatException('مصدر الفيديو غير مدعوم للمعاينة: ${uri.scheme}'),
      };
      await controller.initialize();
      await controller.setLooping(false);
      final duration = controller.value.duration.inMilliseconds;
      if (duration < 500) {
        throw StateError('مدة الفيديو أقصر من أن تسمح بإنشاء مقطع صالح.');
      }
      _startMs = _startMs.clamp(0, duration - 1).toInt();
      _endMs = _endMs.clamp(_startMs + 1, duration).toInt();
      if (_endMs - _startMs < 500) {
        _startMs = (_endMs - 500).clamp(0, duration - 500).toInt();
        _endMs = _startMs + 500;
      }
      controller.addListener(_handlePlaybackBoundary);
      await controller.seekTo(Duration(milliseconds: _startMs));
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _player = controller;
        _loading = false;
        _rebuildPreviewCues();
      });
      unawaited(_loadFilmstripFrames());
    } catch (error) {
      await controller?.dispose();
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadFilmstripFrames() async {
    final requestId = ++_filmstripRequestId;
    setState(() {
      _filmstripLoading = true;
      _filmstripError = null;
    });
    try {
      final frames = await _filmstripService.generate(
        sourceUri: widget.project.source.uri,
        startMs: _startMs,
        endMs: _endMs,
        sampleCount: 7,
      );
      if (!mounted || requestId != _filmstripRequestId) return;
      setState(() {
        _filmstripFrames = frames;
        _filmstripLoading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _filmstripRequestId) return;
      setState(() {
        _filmstripLoading = false;
        _filmstripError = error.toString();
      });
    }
  }

  Widget _buildFilmstripPanel(BuildContext context) {
    final theme = Theme.of(context);
    return _sectionPanel(
      context: context,
      title: 'إطارات الخط الزمني',
      subtitle: 'صور مصغرة من الفيديو الأصلي؛ اضغط على أي إطار للانتقال إلى توقيته.',
      icon: Icons.movie_creation_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_filmstripLoading)
            const LinearProgressIndicator(minHeight: 2)
          else if (_filmstripError != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'تعذّر استخراج الإطارات: $_filmstripError',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'إعادة استخراج الإطارات',
                  onPressed: _loadFilmstripFrames,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            )
          else if (_filmstripFrames.isEmpty)
            OutlinedButton.icon(
              onPressed: _loadFilmstripFrames,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(cutawanText(context, 'استخراج الإطارات'))),
            )
          else
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _filmstripFrames.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final frame = _filmstripFrames[index];
                  final timestampLabel = _formatTime(frame.timestampMs);
                  final currentPosition =
                      _player?.value.position.inMilliseconds ?? -1;
                  final active =
                      (currentPosition - frame.timestampMs).abs() < 180;
                  return Semantics(
                    button: true,
                    label: 'إطار عند $timestampLabel',
                    child: InkWell(
                      onTap: () => _seekTo(frame.timestampMs),
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 112,
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                    color: active
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.outlineVariant,
                                    width: active ? 2 : 1,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.memory(
                                  frame.imageBytes,
                                  width: 112,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _formatTime(frame.timestampMs),
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _loadEditorArtifacts() async {
    try {
      final transcript = await widget.repository.loadTranscript(widget.project.id);
      final plan = await widget.repository.loadReframePlan(widget.project.id);
      final overrides = await widget.repository.loadClipEditOverrides(
        widget.project.id,
        widget.candidate.id,
      );
      if (!mounted) return;
      setState(() {
        _transcript = transcript;
        _reframePlan = plan;
        if (overrides != null) {
          _framingMode = overrides.framingMode;
          _focusX = overrides.focusX;
          _focusY = overrides.focusY;
          _focusKeyframes = overrides.focusKeyframes;
          _fadeInMs = overrides.fadeInMs;
          _fadeOutMs = overrides.fadeOutMs;
          _clampFadeDurationsToTrim(_endMs - _startMs);
        }
        _loadingArtifacts = false;
      });
      _rebuildPreviewCues();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingArtifacts = false;
        _artifactLoadFailed = true;
        _captionPreviewError = 'تعذّر تحميل أدلة الترجمة أو التأطير: $error';
      });
    }
  }

  void _rebuildPreviewCues() {
    final transcript = _transcript;
    if (transcript == null ||
        !transcript.wordTimingReliable ||
        !_draftPreferences.captionsEnabled) {
      _previewCues = const [];
      _captionPreviewError = null;
      return;
    }
    try {
      final candidate = widget.candidate.copyWith(
        startMs: _startMs,
        endMs: _endMs,
      );
      final generated = const CaptionSidecarGenerator().generate(
        transcript: transcript,
        candidate: candidate,
        style: _resolvedCaptionStyle,
        aspectRatio: _targetAspectRatio(),
        animationId: _draftPreferences.captionAnimationId,
        timingOffsetMs: _draftPreferences.captionTimingOffsetMs,
      );
      _previewCues = generated.cues;
      _captionPreviewError = generated.cues.isEmpty
          ? 'لا توجد كلمات ذات توقيت موثوق داخل نطاق هذا المقطع.'
          : null;
    } catch (error) {
      _previewCues = const [];
      _captionPreviewError = 'تعذّرت معاينة الترجمة: $error';
    }
  }

  CaptionStylePreset get _baseCaptionStyle => captionStylePresets.firstWhere(
        (style) => style.id == _draftPreferences.captionStyleId,
        orElse: () => captionStylePresets.first,
      );

  CaptionStylePreset get _resolvedCaptionStyle {
    final base = _baseCaptionStyle;
    return CaptionStylePreset(
      id: base.id,
      name: base.name,
      fontFamily: _draftPreferences.captionFontFamily ?? base.fontFamily,
      fontScale: _draftPreferences.captionFontScale > 0
          ? _draftPreferences.captionFontScale
          : base.fontScale,
      uppercase: _draftPreferences.captionUppercase ?? base.uppercase,
      textColor: _draftPreferences.mainTextColor,
      highlightColor: _draftPreferences.highlightColor,
      highlightBoxColor: _draftPreferences.captionBackgroundColor.toUpperCase() == '#000000'
          ? base.highlightBoxColor
          : _draftPreferences.captionBackgroundColor,
      outlineColor: base.outlineColor,
      outlineWidth: base.outlineWidth,
      shadow: base.shadow,
      bold: _draftPreferences.captionBold ?? base.bold,
      positionY: _draftPreferences.captionPositionY >= 0
          ? _draftPreferences.captionPositionY
          : base.positionY,
      wordsPerGroup: base.wordsPerGroup,
    );
  }

  void _updatePreferences(ClipPreferences preferences) {
    setState(() {
      _draftPreferences = preferences;
      _rebuildPreviewCues();
    });
  }

  void _handlePlaybackBoundary() {
    final player = _player;
    if (!mounted ||
        player == null ||
        !player.value.isInitialized ||
        !player.value.isPlaying ||
        _handlingBoundary) {
      return;
    }
    if (player.value.position.inMilliseconds < _endMs) return;
    _handlingBoundary = true;
    unawaited(
      player
          .pause()
          .then((_) => player.seekTo(Duration(milliseconds: _startMs)))
          .catchError((Object _) {})
          .whenComplete(() => _handlingBoundary = false),
    );
  }

  Future<void> _togglePlayback() async {
    final player = _player;
    if (player == null || !player.value.isInitialized) return;
    if (player.value.isPlaying) {
      await player.pause();
      return;
    }
    final position = player.value.position.inMilliseconds;
    if (position < _startMs || position >= _endMs) {
      await player.seekTo(Duration(milliseconds: _startMs));
    }
    await player.play();
  }

  Future<void> _seekTo(int milliseconds) async {
    final player = _player;
    if (player == null || !player.value.isInitialized) return;
    await player.seekTo(
      Duration(milliseconds: milliseconds.clamp(_startMs, _endMs).toInt()),
    );
  }

  void _clampFadeDurationsToTrim(int durationMs) {
    final maximumFadeIn = durationMs.clamp(0, 1500).toInt();
    _fadeInMs = _fadeInMs.clamp(0, maximumFadeIn).toInt();
    final maximumFadeOut = (durationMs - _fadeInMs).clamp(0, 1500).toInt();
    _fadeOutMs = _fadeOutMs.clamp(0, maximumFadeOut).toInt();
  }

  void _updateTrim(RangeValues values) {
    final player = _player;
    if (player == null || !player.value.isInitialized) return;
    final duration = player.value.duration.inMilliseconds;
    if (duration < 500) return;
    var start = values.start.round().clamp(0, duration - 1).toInt();
    var end = values.end.round().clamp(1, duration).toInt();
    if (end - start < 500) {
      if (start + 500 <= duration) {
        end = start + 500;
      } else {
        start = (end - 500).clamp(0, duration - 1).toInt();
      }
    }
    setState(() {
      _startMs = start;
      _endMs = end;
      _clampFadeDurationsToTrim(end - start);
      _rebuildPreviewCues();
    });
  }

  Future<void> _markTrimStart() async {
    final player = _player;
    if (player == null) return;
    final value = player.value.position.inMilliseconds.clamp(0, _endMs - 500).toInt();
    setState(() {
      _startMs = value;
      _clampFadeDurationsToTrim(_endMs - _startMs);
      _rebuildPreviewCues();
    });
    await _seekTo(_startMs);
    unawaited(_loadFilmstripFrames());
  }

  Future<void> _markTrimEnd() async {
    final player = _player;
    if (player == null) return;
    final duration = player.value.duration.inMilliseconds;
    final value = player.value.position.inMilliseconds
        .clamp(_startMs + 500, duration)
        .toInt();
    setState(() {
      _endMs = value;
      _clampFadeDurationsToTrim(_endMs - _startMs);
      _rebuildPreviewCues();
    });
    await _seekTo(_endMs);
    unawaited(_loadFilmstripFrames());
  }

  double _targetAspectRatio() => switch (_draftPreferences.aspectRatio) {
        ClipAspectRatio.portrait916 => 9 / 16,
        ClipAspectRatio.square11 => 1,
        ClipAspectRatio.landscape169 => 16 / 9,
        ClipAspectRatio.original => _player?.value.aspectRatio ?? 9 / 16,
      };

  ReframeShot? _activeAutomaticShot(int sourcePositionMs) {
    final plan = _reframePlan;
    if (plan == null ||
        (plan.aspectRatio - _targetAspectRatio()).abs() > _targetAspectRatio() * 0.03) {
      return null;
    }
    for (final shot in plan.shots) {
      if (sourcePositionMs >= shot.startMs && sourcePositionMs < shot.endMs) {
        return shot;
      }
    }
    return null;
  }

  Offset _focusAtSourceTime(int sourceTimeMs) {
    if (_focusKeyframes.isEmpty) return Offset(_focusX, _focusY);
    final first = _focusKeyframes.first;
    if (sourceTimeMs <= first.timestampMs) {
      return Offset(first.focusX, first.focusY);
    }
    for (var index = 1; index < _focusKeyframes.length; index++) {
      final previous = _focusKeyframes[index - 1];
      final next = _focusKeyframes[index];
      if (sourceTimeMs <= next.timestampMs) {
        final progress = ((sourceTimeMs - previous.timestampMs) /
                (next.timestampMs - previous.timestampMs))
            .clamp(0.0, 1.0)
            .toDouble();
        return Offset(
          previous.focusX + (next.focusX - previous.focusX) * progress,
          previous.focusY + (next.focusY - previous.focusY) * progress,
        );
      }
    }
    final last = _focusKeyframes.last;
    return Offset(last.focusX, last.focusY);
  }

  int _playheadSourceTimeMs() {
    final player = _player;
    final duration = player?.value.duration.inMilliseconds ?? _endMs;
    return (player?.value.position.inMilliseconds ?? _startMs)
        .clamp(0, duration)
        .toInt();
  }

  void _upsertFocusKeyframeAtPlayhead({double? focusX, double? focusY}) {
    final timestampMs = _playheadSourceTimeMs();
    final current = _focusAtSourceTime(timestampMs);
    final keyframe = ClipFocusKeyframe(
      timestampMs: timestampMs,
      focusX: (focusX ?? current.dx).clamp(0.0, 1.0).toDouble(),
      focusY: (focusY ?? current.dy).clamp(0.0, 1.0).toDouble(),
    );
    final updated = List<ClipFocusKeyframe>.of(_focusKeyframes);
    final existingIndex =
        updated.indexWhere((item) => item.timestampMs == timestampMs);
    if (existingIndex >= 0) {
      updated[existingIndex] = keyframe;
    } else {
      if (updated.length >= 120) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(cutawanText(context, 'وصلت إلى الحد الأقصى وهو 120 إطار تركيز.')))),
        );
        return;
      }
      updated.add(keyframe);
    }
    updated.sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    setState(() {
      _focusKeyframes = List<ClipFocusKeyframe>.unmodifiable(updated);
      _focusX = keyframe.focusX;
      _focusY = keyframe.focusY;
    });
  }

  void _addFocusKeyframeAtPlayhead() {
    final current = _focusAtSourceTime(_playheadSourceTimeMs());
    _upsertFocusKeyframeAtPlayhead(
      focusX: current.dx,
      focusY: current.dy,
    );
  }

  void _removeFocusKeyframe(int timestampMs) {
    setState(() {
      _focusKeyframes = List<ClipFocusKeyframe>.unmodifiable(
        _focusKeyframes
            .where((keyframe) => keyframe.timestampMs != timestampMs),
      );
    });
  }

  Alignment _manualFocusAlignment(int sourcePositionMs) {
    final focus = _focusAtSourceTime(sourcePositionMs);
    final sourceAspect = _player?.value.aspectRatio ?? 9 / 16;
    final targetAspect = _targetAspectRatio();
    var cropWidth = 1.0;
    var cropHeight = 1.0;
    if (sourceAspect > targetAspect) {
      cropWidth = targetAspect / sourceAspect;
    } else if (sourceAspect < targetAspect) {
      cropHeight = sourceAspect / targetAspect;
    }
    final left = (focus.dx - cropWidth / 2)
        .clamp(0.0, 1.0 - cropWidth)
        .toDouble();
    final top = (focus.dy - cropHeight / 2)
        .clamp(0.0, 1.0 - cropHeight)
        .toDouble();
    final alignment = ClipEditOverrides.previewAlignmentForCropRegion(
      x: left,
      y: top,
      width: cropWidth,
      height: cropHeight,
    );
    return Alignment(alignment['x']!, alignment['y']!);
  }

  BoxFit _previewFit(int sourcePositionMs) {
    if (_framingMode == ClipFramingMode.fullFrame) return BoxFit.contain;
    if (_framingMode == ClipFramingMode.manualFocus) return BoxFit.cover;
    final shot = _activeAutomaticShot(sourcePositionMs);
    if (shot == null || shot.mode == 'fit') return BoxFit.contain;
    return BoxFit.cover;
  }

  Alignment _previewAlignment(int sourcePositionMs) {
    if (_framingMode == ClipFramingMode.manualFocus) {
      return _manualFocusAlignment(sourcePositionMs);
    }
    final shot = _framingMode == ClipFramingMode.automatic
        ? _activeAutomaticShot(sourcePositionMs)
        : null;
    final region = shot?.region;
    if (region == null) return Alignment.center;
    final alignment = ClipEditOverrides.previewAlignmentForCropRegion(
      x: region.x,
      y: region.y,
      width: region.width,
      height: region.height,
    );
    return Alignment(alignment['x']!, alignment['y']!);
  }

  Map<String, Object?>? _activeCaptionCue(int sourcePositionMs) {
    final clipPosition = sourcePositionMs - _startMs;
    for (final cue in _previewCues) {
      final start = cue['startMs'];
      final end = cue['endMs'];
      if (start is int && end is int && clipPosition >= start && clipPosition < end) {
        return cue;
      }
    }
    return null;
  }

  Widget _captionOverlay(int sourcePositionMs, BuildContext context) {
    if (!_draftPreferences.captionsEnabled) return const SizedBox.shrink();
    final cue = _activeCaptionCue(sourcePositionMs);
    if (cue == null) return const SizedBox.shrink();
    final text = cue['text'] as String? ?? '';
    final rawWords = cue['words'];
    if (text.isEmpty || rawWords is! List) return const SizedBox.shrink();

    final style = _resolvedCaptionStyle;
    final localPosition = sourcePositionMs - _startMs;
    final spans = <TextSpan>[];
    var cursor = 0;
    final words = rawWords.whereType<Map<String, Object?>>().toList(growable: false)
      ..sort((a, b) => ((a['startOffset'] as num?)?.toInt() ?? 0)
          .compareTo((b['startOffset'] as num?)?.toInt() ?? 0));
    for (final word in words) {
      final startOffset = (word['startOffset'] as num?)?.toInt() ?? -1;
      final endOffset = (word['endOffset'] as num?)?.toInt() ?? -1;
      final startMs = (word['startMs'] as num?)?.toInt() ?? -1;
      final endMs = (word['endMs'] as num?)?.toInt() ?? -1;
      if (startOffset < cursor ||
          endOffset <= startOffset ||
          endOffset > text.length) {
        continue;
      }
      if (startOffset > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, startOffset)));
      }
      final active = localPosition >= startMs && localPosition < endMs;
      spans.add(TextSpan(
        text: text.substring(startOffset, endOffset),
        style: TextStyle(
          color: active ? _parseColor(style.highlightColor) : _parseColor(style.textColor),
          fontWeight: style.bold ? FontWeight.w900 : FontWeight.w600,
        ),
      ));
      cursor = endOffset;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    final arabic = (_transcript?.language.toLowerCase().startsWith('ar') ?? false) ||
        RegExp(r'[\u0600-\u06FF]').hasMatch(text);
    final fontSize = (MediaQuery.sizeOf(context).width * style.fontScale * 1.45)
        .clamp(13.0, 34.0)
        .toDouble();
    final background = style.highlightBoxColor == null
        ? Colors.black.withValues(alpha: 0.62)
        : _parseColor(style.highlightBoxColor!).withValues(alpha: 0.90);
    return Align(
      alignment: Alignment(
        0,
        (style.positionY.clamp(0.55, 0.93) * 2) - 1,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Directionality(
              textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
              child: RichText(
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: TextStyle(
                    fontFamily: style.fontFamily,
                    fontSize: fontSize,
                    fontWeight: style.bold ? FontWeight.w900 : FontWeight.w600,
                    color: _parseColor(style.textColor),
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  children: spans,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    final value = hex.replaceFirst('#', '');
    return Color(int.parse('FF$value', radix: 16));
  }

  String _formatTime(int milliseconds) {
    final value = milliseconds < 0 ? 0 : milliseconds;
    final minutes = value ~/ 60000;
    final seconds = (value % 60000) ~/ 1000;
    final tenths = (value % 1000) ~/ 100;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${tenths.toString()}';
  }

  String _ratioLabel(ClipAspectRatio ratio) => switch (ratio) {
        ClipAspectRatio.portrait916 => '9:16',
        ClipAspectRatio.square11 => '1:1',
        ClipAspectRatio.landscape169 => '16:9',
        ClipAspectRatio.original => 'الأصلية',
      };

  String _framingLabel(ClipFramingMode mode) => switch (mode) {
        ClipFramingMode.automatic => 'تلقائي',
        ClipFramingMode.fullFrame => 'الإطار كاملاً',
        ClipFramingMode.manualFocus => 'تركيز يدوي',
      };

  Future<void> _saveEdits() async {
    if (_saving) return;
    final player = _player;
    if (player == null || !player.value.isInitialized) return;
    final duration = player.value.duration.inMilliseconds;
    if (_startMs < 0 ||
        _endMs <= _startMs ||
        _endMs > duration ||
        _endMs - _startMs < 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(cutawanText(context, 'نطاق القص غير صالح.')))),
      );
      return;
    }

    final editedCandidate = widget.candidate.copyWith(
      startMs: _startMs,
      endMs: _endMs,
      title: _titleController.text.trim().isEmpty
          ? widget.candidate.title
          : _titleController.text.trim(),
    );
    final editedSet = widget.candidateSet.copyWith(
      candidates: widget.candidateSet.candidates
          .map((item) => item.id == editedCandidate.id ? editedCandidate : item)
          .toList(growable: false),
    );
    final preferences = _draftPreferences.copyWith(
      aspectRatio: _draftPreferences.aspectRatio,
    );
    final preferencesError = preferences.validate();
    if (preferencesError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('إعدادات التصدير غير صالحة: $preferencesError')),
      );
      return;
    }
    editedSet.validate();
    final overrides = ClipEditOverrides(
      clipId: widget.candidate.id,
      framingMode: _framingMode,
      focusX: _focusX,
      focusY: _focusY,
      focusKeyframes: _focusKeyframes,
      fadeInMs: _fadeInMs,
      fadeOutMs: _fadeOutMs,
    );
    overrides.validate();

    setState(() => _saving = true);
    try {
      final updatedProject = widget.project.copyWith(
        preferences: preferences,
        updatedAtUtc: DateTime.now().toUtc(),
      );
      await widget.repository.saveCandidates(widget.project.id, editedSet);
      await widget.repository.saveClipEditOverrides(widget.project.id, overrides);
      await widget.repository.save(updatedProject);
      await widget.onSaved();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(cutawanText(context, 'حُفظت تعديلات المقطع والتأطير والترجمة. أعد تشغيل المعالجة لتحديث ملف التصدير.'))),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر حفظ تعديلات المقطع: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _sectionPanel({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: scheme.onSurfaceVariant, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context, VideoPlayerValue value) {
    final player = _player!;
    final size = value.size;
    final sourcePosition = value.position.inMilliseconds;
    final fadeOpacity = ClipEditOverrides.blackFadeOpacity(
      localPositionMs: sourcePosition - _startMs,
      durationMs: _endMs - _startMs,
      fadeInMs: _fadeInMs,
      fadeOutMs: _fadeOutMs,
    );
    return _sectionPanel(
      context: context,
      title: 'معاينة المقطع',
      subtitle: 'المقطع المحدد · ${_formatTime(_startMs)} — ${_formatTime(_endMs)}',
      icon: Icons.play_circle_outline_rounded,
      child: Column(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: AspectRatio(
                aspectRatio: _targetAspectRatio(),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ColoredBox(
                    color: Colors.black,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipPreviewViewport(
                          fit: _previewFit(sourcePosition),
                          alignment: _previewAlignment(sourcePosition),
                          child: SizedBox(
                            width: size.width > 0 ? size.width : 16,
                            height: size.height > 0 ? size.height : 9,
                            child: VideoPlayer(player),
                          ),
                        ),
                        _captionOverlay(sourcePosition, context),
                        if (fadeOpacity > 0)
                          Positioned.fill(
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: fadeOpacity),
                            ),
                          ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.58),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _ratioLabel(_draftPreferences.aspectRatio),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: value.isPlaying ? 'إيقاف مؤقت' : 'تشغيل',
                onPressed: _togglePlayback,
                icon: Icon(value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_formatTime(sourcePosition.clamp(_startMs, _endMs).toInt())} / ${_formatTime(_endMs)}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'العودة إلى بداية المقطع',
                onPressed: () => _seekTo(_startMs),
                icon: const Icon(Icons.first_page_rounded),
              ),
              IconButton(
                tooltip: 'الانتقال إلى نهاية المقطع',
                onPressed: () => _seekTo(_endMs),
                icon: const Icon(Icons.last_page_rounded),
              ),
            ],
          ),
          Slider(
            value: sourcePosition.clamp(_startMs, _endMs).toDouble(),
            min: _startMs.toDouble(),
            max: _endMs.toDouble(),
            onChanged: (value) => _seekTo(value.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildTrimPanel(BuildContext context, int duration) {
    final theme = Theme.of(context);
    return _sectionPanel(
      context: context,
      title: 'تحديد المدة',
      subtitle: 'اسحب نقطتي البداية والنهاية أو ثبّتهما من موضع التشغيل الحالي.',
      icon: Icons.content_cut_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RangeSlider(
            values: RangeValues(_startMs.toDouble(), _endMs.toDouble()),
            min: 0,
            max: duration.toDouble(),
            divisions: (duration ~/ 250).clamp(1, 1200).toInt(),
            labels: RangeLabels(_formatTime(_startMs), _formatTime(_endMs)),
            onChangeStart: (_) {
              final player = _player;
              if (player?.value.isPlaying ?? false) unawaited(player!.pause());
            },
            onChanged: _updateTrim,
            onChangeEnd: (_) {
              final current = _player?.value.position.inMilliseconds ?? _startMs;
              if (current < _startMs || current > _endMs) {
                unawaited(_seekTo(_startMs));
              }
              unawaited(_loadFilmstripFrames());
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('البداية  ${_formatTime(_startMs)}', style: theme.textTheme.labelMedium),
              Text('النهاية  ${_formatTime(_endMs)}', style: theme.textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _markTrimStart,
                icon: const Icon(Icons.flag_outlined, size: 17),
                label: Text(cutawanText(context, 'تعيين البداية هنا'))),
              ),
              OutlinedButton.icon(
                onPressed: _markTrimEnd,
                icon: const Icon(Icons.flag_rounded, size: 17),
                label: Text(cutawanText(context, 'تعيين النهاية هنا'))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'مدة المقطع الناتجة: ${_formatTime(_endMs - _startMs)}',
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildTransitionPanel(BuildContext context) {
    final theme = Theme.of(context);
    final clipDurationMs = _endMs - _startMs;
    String durationLabel(int value) =>
        value == 0 ? 'إيقاف' : '${(value / 1000).toStringAsFixed(1)} ثانية';
    return _sectionPanel(
      context: context,
      title: 'تلاشي الصورة',
      subtitle: 'تلاشي بصري تدريجي من الأسود عند البداية وإلى الأسود عند النهاية. لا يغيّر مستوى الصوت.',
      icon: Icons.gradient_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تلاشي الدخول · ${durationLabel(_fadeInMs)}',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
          Slider(
            value: _fadeInMs.toDouble(),
            min: 0,
            max: 1500,
            divisions: 15,
            label: durationLabel(_fadeInMs),
            onChanged: (value) {
              setState(() {
                _fadeInMs = value.round().clamp(
                  0,
                  (clipDurationMs - _fadeOutMs).clamp(0, 1500),
                ).toInt();
              });
            },
          ),
          const SizedBox(height: 4),
          Text('تلاشي الخروج · ${durationLabel(_fadeOutMs)}',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
          Slider(
            value: _fadeOutMs.toDouble(),
            min: 0,
            max: 1500,
            divisions: 15,
            label: durationLabel(_fadeOutMs),
            onChanged: (value) {
              setState(() {
                _fadeOutMs = value.round().clamp(
                  0,
                  (clipDurationMs - _fadeInMs).clamp(0, 1500),
                ).toInt();
              });
            },
          ),
          Text(cutawanText(context, 'يمكن ضبط كل تلاشي حتى 1.5 ثانية، ويُحفظ مع إعدادات هذا المقطع فقط.')),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildFramingPanel(BuildContext context) {
    final theme = Theme.of(context);
    final ratios = <ClipAspectRatio, String>{
      ClipAspectRatio.portrait916: 'عمودي 9:16',
      ClipAspectRatio.square11: 'مربع 1:1',
      ClipAspectRatio.landscape169: 'أفقي 16:9',
      ClipAspectRatio.original: 'أصلية',
    };
    return _sectionPanel(
      context: context,
      title: 'التأطير ونقطة التركيز',
      subtitle: 'تحكّم في طريقة ملاءمة المشهد داخل إطار الإخراج.',
      icon: Icons.crop_free_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cutawanText(context, 'نسبة الإخراج')), style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: ratios.entries.map((entry) => ChoiceChip(
              label: Text(entry.value),
              selected: _draftPreferences.aspectRatio == entry.key,
              onSelected: (_) {
                _updatePreferences(_draftPreferences.copyWith(aspectRatio: entry.key));
              },
            )).toList(growable: false),
          ),
          const SizedBox(height: 14),
          Text(cutawanText(context, 'طريقة التأطير')), style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: ClipFramingMode.values.map((mode) => ChoiceChip(
              label: Text(_framingLabel(mode)),
              selected: _framingMode == mode,
              onSelected: (_) => setState(() => _framingMode = mode),
            )).toList(growable: false),
          ),
          if (_framingMode == ClipFramingMode.manualFocus) ...[
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final sourceTimeMs = _playheadSourceTimeMs();
                final currentFocus = _focusAtSourceTime(sourceTimeMs);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مركز القص الأفقي · ${(currentFocus.dx * 100).round()}%',
                    ),
                    Slider(
                      value: currentFocus.dx,
                      min: 0,
                      max: 1,
                      divisions: 100,
                      onChanged: (value) =>
                          _upsertFocusKeyframeAtPlayhead(focusX: value),
                    ),
                    Text(
                      'مركز القص العمودي · ${(currentFocus.dy * 100).round()}%',
                    ),
                    Slider(
                      value: currentFocus.dy,
                      min: 0,
                      max: 1,
                      divisions: 100,
                      onChanged: (value) =>
                          _upsertFocusKeyframeAtPlayhead(focusY: value),
                    ),
                    const SizedBox(height: 4),
                    FilledButton.tonalIcon(
                      onPressed: _addFocusKeyframeAtPlayhead,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(
                        'إضافة إطار تركيز عند ${_formatTime(sourceTimeMs)}',
                      ),
                    ),
                    if (_focusKeyframes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'إطارات التركيز · ${_focusKeyframes.length}/120',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _focusKeyframes.map((keyframe) {
                          return InputChip(
                            label: Text(_formatTime(keyframe.timestampMs)),
                            onPressed: () => _seekTo(keyframe.timestampMs),
                            onDeleted: () =>
                                _removeFocusKeyframe(keyframe.timestampMs),
                          );
                        }).toList(growable: false),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 6),
          Text(
            _framingMode == ClipFramingMode.automatic
                ? 'يستخدم التصدير مسار التأطير المحفوظ من تحليل المشهد. إذا غُيّرت النسبة فسيعاد التحليل عند تشغيل المعالجة.'
                : _framingMode == ClipFramingMode.fullFrame
                    ? 'يحافظ التصدير على المشهد كاملاً مع ملاءمته داخل النسبة المختارة.'
                    : (_focusKeyframes.isEmpty
                        ? 'يُطبّق التصدير قصّاً ثابتاً حول نقطة التركيز التي حددتها أعلاه.'
                        : 'يستوفي التصدير الحركة بين إطارات التركيز الزمنية بسلاسة ويحافظ على توقيتها.'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (_loadingArtifacts)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildColorSwatches({
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    const colors = [
      '#FFFFFF',
      '#FFD400',
      '#EF4444',
      '#22D3EE',
      '#4ADE80',
      '#F472B6',
      '#A78BFA',
      '#111827',
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: colors.map((hex) {
        final color = _parseColor(hex);
        final active = selected.toUpperCase() == hex;
        return Semantics(
          button: true,
          selected: active,
          label: 'لون $hex',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onSelected(hex),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.outlineVariant,
                  width: active ? 3 : 1,
                ),
              ),
              child: active
                  ? Icon(Icons.check_rounded, size: 16, color: color.computeLuminance() > 0.55 ? Colors.black : Colors.white)
                  : null,
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildCaptionsPanel(BuildContext context) {
    final theme = Theme.of(context);
    final style = _resolvedCaptionStyle;
    final animation = captionAnimationPresets.firstWhere(
      (item) => item.id == _draftPreferences.captionAnimationId,
      orElse: () => captionAnimationPresets.first,
    );
    final fontScale = _draftPreferences.captionFontScale > 0
        ? _draftPreferences.captionFontScale
        : _baseCaptionStyle.fontScale;
    final position = _draftPreferences.captionPositionY >= 0
        ? _draftPreferences.captionPositionY
        : _baseCaptionStyle.positionY;
    return _sectionPanel(
      context: context,
      title: 'الترجمة والمظهر',
      subtitle: 'معاينة الكلمات بتوقيتها، ثم تخصيص الهوية والحركة.',
      icon: Icons.closed_caption_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(cutawanText(context, 'إظهار الترجمة في التصدير'))),
            subtitle: Text(cutawanText(context, 'يتم توليد الترجمة من توقيتات Whisper المحفوظة.'))),
            value: _draftPreferences.captionsEnabled,
            onChanged: (value) => _updatePreferences(
              _draftPreferences.copyWith(captionsEnabled: value),
            ),
          ),
          if (_draftPreferences.captionsEnabled) ...[
            const SizedBox(height: 8),
            Text(cutawanText(context, 'أنماط النص')), style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: captionStylePresets.map((preset) => ChoiceChip(
                label: Text(preset.name),
                selected: preset.id == _draftPreferences.captionStyleId,
                onSelected: (_) => _updatePreferences(_draftPreferences.copyWith(
                  captionStyleId: preset.id,
                  mainTextColor: preset.textColor,
                  highlightColor: preset.highlightColor,
                  captionFontFamily: preset.fontFamily,
                  captionFontScale: preset.fontScale,
                  captionPositionY: preset.positionY,
                  captionUppercase: preset.uppercase,
                  captionBold: preset.bold,
                )),
              )).toList(growable: false),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: animation.id,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'حركة الكلمات',
                prefixIcon: Icon(Icons.animation_rounded),
              ),
              items: captionAnimationPresets.map((item) => DropdownMenuItem(
                value: item.id,
                child: Text(item.name),
              )).toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  _updatePreferences(_draftPreferences.copyWith(captionAnimationId: value));
                }
              },
            ),
            const SizedBox(height: 14),
            Text(cutawanText(context, 'لون النص')), style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _buildColorSwatches(
              selected: style.textColor,
              onSelected: (value) => _updatePreferences(
                _draftPreferences.copyWith(mainTextColor: value),
              ),
            ),
            const SizedBox(height: 12),
            Text(cutawanText(context, 'لون الكلمة النشطة')), style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _buildColorSwatches(
              selected: style.highlightColor,
              onSelected: (value) => _updatePreferences(
                _draftPreferences.copyWith(highlightColor: value),
              ),
            ),
            const SizedBox(height: 14),
            Text('حجم النص · ${(fontScale * 100).toStringAsFixed(1)}%'),
            Slider(
              value: fontScale.clamp(0.03, 0.075).toDouble(),
              min: 0.03,
              max: 0.075,
              divisions: 45,
              onChanged: (value) => _updatePreferences(
                _draftPreferences.copyWith(captionFontScale: value),
              ),
            ),
            Text('موضع الترجمة · ${(position * 100).round()}% من ارتفاع الإطار'),
            Slider(
              value: position.clamp(0.55, 0.92).toDouble(),
              min: 0.55,
              max: 0.92,
              divisions: 37,
              onChanged: (value) => _updatePreferences(
                _draftPreferences.copyWith(captionPositionY: value),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'مزامنة التوقيت · ${_draftPreferences.captionTimingOffsetMs > 0 ? '+' : ''}${_draftPreferences.captionTimingOffsetMs} ms',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Slider(
              value: _draftPreferences.captionTimingOffsetMs.toDouble(),
              min: -2000,
              max: 2000,
              divisions: 80,
              onChanged: (value) => _updatePreferences(
                _draftPreferences.copyWith(captionTimingOffsetMs: value.round()),
              ),
            ),
            if (_captionPreviewError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _captionPreviewError!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            if (_transcript == null || !_transcript!.wordTimingReliable)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(cutawanText(context, 'لا توجد توقيتات كلمات موثوقة لهذا المشروع؛ لن تُنشأ ترجمة متزامنة حتى يكتمل التفريغ المحلي.')),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _filmstripRequestId++;
    _titleController.dispose();
    final player = _player;
    if (player != null) {
      player.removeListener(_handlePlaybackBoundary);
      unawaited(player.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(cutawanText(context, 'محرر المقطع'))),
        actions: [
          IconButton(
            tooltip: 'حفظ التعديلات',
            onPressed: _saving || _loading || _error != null || _loadingArtifacts || _artifactLoadFailed
                ? null
                : _saveEdits,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || _player == null
              ? _PlaybackError(message: _error ?? 'مشغل الفيديو غير متاح.')
              : ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: _player!,
                  builder: (context, value, _) {
                    if (!value.isInitialized) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final duration = value.duration.inMilliseconds;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 120),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cutawanText(context, 'تحرير المقطع المحدد')),
                                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    widget.project.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: scheme.onSurface.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${widget.candidate.score.round()}/100',
                                style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'معرّف المقطع: ${widget.candidate.id}',
                          style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        _buildPreview(context, value),
                        _buildTrimPanel(context, duration),
                        _buildFilmstripPanel(context),
                        _buildTransitionPanel(context),
                        _buildFramingPanel(context),
                        _sectionPanel(
                          context: context,
                          title: 'بيانات المقطع',
                          subtitle: 'يُحفظ العنوان مع نتيجة هذا المقطع فقط.',
                          icon: Icons.title_rounded,
                          child: TextField(
                            controller: _titleController,
                            maxLength: 80,
                            decoration: const InputDecoration(
                              labelText: 'اسم المقطع',
                              prefixIcon: Icon(Icons.edit_outlined),
                            ),
                          ),
                        ),
                        _buildCaptionsPanel(context),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _saving || _loadingArtifacts || _artifactLoadFailed ? null : _saveEdits,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(_saving ? 'جارٍ حفظ التعديلات…' : 'حفظ والعودة إلى المراجعة'),
                        ),
                        const SizedBox(height: 10),
                        Text(cutawanText(context, 'الإعدادات النصية ونسبة الإخراج مشتركة على مستوى المشروع، أما القص ونقطة التركيز فمحفوظان لهذا المقطع وحده.')),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}

class _PlaybackError extends StatelessWidget {
  const _PlaybackError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_file_outlined, size: 38, color: scheme.error),
            const SizedBox(height: 12),
            Text(cutawanText(context, 'تعذّر فتح معاينة الفيديو')),
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
