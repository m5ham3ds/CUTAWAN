import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

import '../../domain/caption_animation.dart';
import '../../domain/caption_catalog.dart';
import '../../domain/caption_layout.dart';
import '../../domain/clip_preferences.dart';
import '../../domain/project_contract.dart';
import '../../domain/transcript_contract.dart';
import '../../services/local_project_repository.dart';
import '../home_shell/shared_ui_primitives.dart';
class CaptionStudioPage extends StatefulWidget {
  const CaptionStudioPage({
    required this.projects,
    required this.repository,
    required this.onProjectsChanged,
    super.key,
  });

  final ValueListenable<List<CutawanProject>> projects;
  final LocalProjectRepository repository;
  final Future<void> Function() onProjectsChanged;

  @override
  State<CaptionStudioPage> createState() => _CaptionStudioPageState();
}

class _CaptionStudioPageState extends State<CaptionStudioPage>
    with SingleTickerProviderStateMixin {
  static const _exportAnimations = {'static', 'karaoke_fill'};
  static const _arabicSample = 'هذه لحظة تستحق أن تتحول إلى مقطع قصير';
  static const _englishSample = 'This is the moment worth sharing with everyone';

  late final AnimationController _animation;
  String? _selectedProjectId;
  String _styleId = 'beast';
  String _animationId = 'word_pop';
  String _textColor = '#FFFFFF';
  String _highlightColor = '#FFD400';
  String _backgroundColor = '#000000';
  String _fontFamily = 'Anton';
  double _fontScale = 0.052;
  double _positionY = 0.72;
  int _timingOffsetMs = 0;
  bool _uppercase = true;
  bool _bold = false;
  bool _captionsEnabled = true;
  bool _rtl = true;
  bool _showSafeFrame = false;
  bool _loading = false;
  bool _dirty = false;
  String? _error;
  String? _savingProjectId;
  int _loadGeneration = 0;
  Map<String, Object?>? _loadedPreferencesSnapshot;
  List<CaptionWordTiming> _previewWords = const [];
  List<CaptionWordGroup> _previewGroups = const [];
  double _previewAspectRatio = 9 / 16;
  int _previewGroupIndex = 0;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    widget.projects.addListener(_handleProjectChange);
    final projects = widget.projects.value;
    if (projects.isNotEmpty) {
      _selectedProjectId = projects.first.id;
      unawaited(_loadLatestPreferences(projectId: projects.first.id));
    }
  }

  @override
  void didUpdateWidget(covariant CaptionStudioPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projects != widget.projects) {
      oldWidget.projects.removeListener(_handleProjectChange);
      widget.projects.addListener(_handleProjectChange);
      _handleProjectChange();
    } else if (oldWidget.repository != widget.repository &&
        _selectedProjectId != null) {
      unawaited(
        _loadLatestPreferences(projectId: _selectedProjectId!),
      );
    }
  }

  @override
  void dispose() {
    widget.projects.removeListener(_handleProjectChange);
    _animation.dispose();
    super.dispose();
  }

  CutawanProject? get _selectedProject {
    final id = _selectedProjectId;
    if (id == null) return null;
    for (final project in widget.projects.value) {
      if (project.id == id) return project;
    }
    return null;
  }

  CaptionStylePreset get _preset => captionStylePresets.firstWhere(
        (item) => item.id == _styleId,
        orElse: () => captionStylePresets.first,
      );

  CaptionAnimationPreset get _motion => captionAnimationPresets.firstWhere(
        (item) => item.id == _animationId,
        orElse: () => captionAnimationPresets.first,
      );

  bool get _animationExports =>
      _exportAnimations.contains(_animationId);

  String get _exportAnimationId =>
      _animationExports ? _animationId : 'static';

  CaptionWordGroup? get _previewGroup =>
      _previewGroups.isEmpty ? null : _previewGroups[_previewGroupIndex];

  String get _previewText {
    final group = _previewGroup;
    if (group == null) {
      final sample = _rtl ? _arabicSample : _englishSample;
      return !_rtl && _uppercase ? sample.toUpperCase() : sample;
    }
    final text = group.lines
        .map((line) => line.map((word) => word.text).join(' '))
        .join('\n');
    return !_rtl && _uppercase ? text.toUpperCase() : text;
  }

  double _aspectRatioFor(CutawanProject project) {
    switch (project.preferences.aspectRatio) {
      case ClipAspectRatio.portrait916:
        return 9 / 16;
      case ClipAspectRatio.square11:
        return 1;
      case ClipAspectRatio.landscape169:
        return 16 / 9;
      case ClipAspectRatio.original:
        final rotated = project.source.rotationDegrees.abs() % 180 == 90;
        final width = rotated ? project.source.height : project.source.width;
        final height = rotated ? project.source.width : project.source.height;
        return width / height;
    }
  }

  String _formatPreviewTime(int milliseconds) {
    final totalSeconds = milliseconds ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _handleProjectChange() {
    final projects = widget.projects.value;
    if (projects.isEmpty) {
      if (_selectedProjectId != null) {
        _selectProject(null);
      }
      return;
    }
    final selectedProjects = projects.where(
      (project) => project.id == _selectedProjectId,
    );
    if (selectedProjects.isEmpty) {
      _selectProject(projects.first.id);
      return;
    }
    final selected = selectedProjects.first;
    if (!_dirty &&
        _loadedPreferencesSnapshot != null &&
        !mapEquals(_loadedPreferencesSnapshot, selected.preferences.toJson())) {
      unawaited(_loadLatestPreferences(projectId: selected.id));
    }
  }

  void _selectProject(String? projectId) {
    if (projectId == _selectedProjectId && projectId != null) return;
    _loadGeneration++;
    setState(() {
      _selectedProjectId = projectId;
      _loading = projectId != null;
      _dirty = false;
      _loadedPreferencesSnapshot = null;
      _error = null;
      _previewWords = const [];
      _previewGroups = const [];
      _previewGroupIndex = 0;
    });
    if (projectId == null) {
      _rebuildPreviewGroups();
      return;
    }
    unawaited(_loadLatestPreferences(projectId: projectId));
  }

  Future<void> _loadLatestPreferences({
    required String projectId,
  }) async {
    final project = widget.projects.value.where(
      (item) => item.id == projectId,
    );
    if (project.isEmpty) {
      if (mounted && _selectedProjectId == projectId) {
        setState(() => _loading = false);
      }
      return;
    }
    final selected = project.first;
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    CutawanTranscript? transcript;
    String? transcriptError;
    try {
      transcript = await widget.repository.loadTranscript(projectId);
    } catch (error) {
      transcriptError = 'تعذّر قراءة التفريغ المحفوظ: $error';
    }
    if (!mounted ||
        generation != _loadGeneration ||
        _selectedProjectId != projectId) {
      return;
    }
    final loadedTranscript = transcript;

    final prefs = selected.preferences;
    final styleMatches = captionStylePresets.where(
      (item) => item.id == prefs.captionStyleId,
    );
    final style = styleMatches.isEmpty
        ? captionStylePresets.first
        : styleMatches.first;
    setState(() {
      _styleId = style.id;
      final previewAnimationId =
          prefs.captionPreviewAnimationId ?? prefs.captionAnimationId;
      _animationId = captionAnimationPresets.any(
        (item) => item.id == previewAnimationId,
      )
          ? previewAnimationId
          : 'static';
      _textColor = prefs.mainTextColor;
      _highlightColor = prefs.highlightColor;
      _backgroundColor = prefs.captionBackgroundColor.toUpperCase() == '#000000' &&
              style.highlightBoxColor != null
          ? style.highlightBoxColor!
          : prefs.captionBackgroundColor;
      _fontFamily = prefs.captionFontFamily ?? style.fontFamily;
      _fontScale =
          prefs.captionFontScale > 0 ? prefs.captionFontScale : style.fontScale;
      _positionY =
          prefs.captionPositionY >= 0 ? prefs.captionPositionY : style.positionY;
      _uppercase = prefs.captionUppercase ?? style.uppercase;
      _bold = prefs.captionBold ?? style.bold;
      _captionsEnabled = prefs.captionsEnabled;
      _timingOffsetMs = prefs.captionTimingOffsetMs;
      if (loadedTranscript != null) {
        final language = loadedTranscript.language.toLowerCase();
        _rtl = language.startsWith('ar') ||
            language.startsWith('fa') ||
            language.startsWith('ur');
        final duration = loadedTranscript.sourceDurationMs;
        _previewWords = loadedTranscript.words
            .map((word) {
              final shiftedStart = word.startMs + _timingOffsetMs;
              final shiftedEnd = word.endMs + _timingOffsetMs;
              return CaptionWordTiming(
                text: word.text,
                startMs: shiftedStart.clamp(0, duration).toInt(),
                endMs: shiftedEnd.clamp(0, duration).toInt(),
              );
            })
            .where((word) => word.endMs > word.startMs)
            .toList(growable: false);
      } else {
        _previewWords = const [];
      }
      _previewAspectRatio = _aspectRatioFor(selected);
      _previewGroupIndex = 0;
      _error = transcriptError;
      _loading = false;
      _dirty = false;
      _loadedPreferencesSnapshot =
          Map<String, Object?>.from(prefs.toJson());
      _rebuildPreviewGroups();
    });
  }

  void _rebuildPreviewGroups({bool restartAnimation = true}) {
    if (_previewWords.isEmpty) {
      _previewGroups = const [];
      _previewGroupIndex = 0;
      _animation.duration = const Duration(milliseconds: 1200);
    } else {
      try {
        final engine = const CaptionLayoutEngine();
        _previewGroups = engine.group(
          _previewWords,
          engine.budget(
            _preset,
            _previewAspectRatio,
            fontScaleOverride: _fontScale,
            fontFamilyOverride: _fontFamily,
            uppercaseOverride: _uppercase,
          ),
        );
        if (_previewGroups.isEmpty) {
          _previewGroupIndex = 0;
          _animation.duration = const Duration(milliseconds: 1200);
        } else {
          _previewGroupIndex =
              _previewGroupIndex.clamp(0, _previewGroups.length - 1).toInt();
          final group = _previewGroup!;
          final duration =
              (group.endMs - group.startMs).clamp(650, 12000).toInt();
          _animation.duration = Duration(milliseconds: duration);
        }
      } on FormatException catch (error) {
        _previewGroups = const [];
        _previewGroupIndex = 0;
        _error = 'تعذّر تجهيز معاينة التفريغ: ${error.message}';
        _animation.duration = const Duration(milliseconds: 1200);
      }
    }
    if (restartAnimation) _animation.repeat();
  }

  void _selectPreviewGroup(int? index) {
    if (index == null || index < 0 || index >= _previewGroups.length) return;
    setState(() => _previewGroupIndex = index);
    final group = _previewGroup!;
    _animation.duration = Duration(
      milliseconds: (group.endMs - group.startMs).clamp(650, 12000).toInt(),
    );
    _animation.repeat();
  }

  void _selectStyle(CaptionStylePreset style) {
    setState(() {
      _styleId = style.id;
      _textColor = style.textColor;
      _highlightColor = style.highlightColor;
      _backgroundColor = style.highlightBoxColor ?? '#000000';
      _fontFamily = style.fontFamily;
      _fontScale = style.fontScale;
      _positionY = style.positionY;
      _uppercase = style.uppercase;
      _bold = style.bold;
      _error = null;
      _dirty = true;
      _rebuildPreviewGroups();
    });
  }

  void _setColor(String field, String value) {
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
      setState(() => _error = 'اكتب اللون بصيغة #RRGGBB');
      return;
    }
    setState(() {
      switch (field) {
        case 'text':
          _textColor = value.toUpperCase();
          break;
        case 'highlight':
          _highlightColor = value.toUpperCase();
          break;
        case 'background':
          _backgroundColor = value.toUpperCase();
          break;
      }
      _error = null;
      _dirty = true;
    });
  }

  void _update(VoidCallback change, {bool rebuildLayout = false}) {
    setState(() {
      change();
      _dirty = true;
      if (rebuildLayout) _rebuildPreviewGroups();
    });
  }

  CaptionAnimationFrame _frameFor(double progress) {
    final group = _previewGroup;
    final preview = _previewText;
    final sampleWords =
        (_rtl ? _arabicSample : _englishSample).split(RegExp(r'\s+'));
    final wordCount = group?.words.length ?? sampleWords.length;
    final activeWord = group == null
        ? (progress * wordCount).floor().clamp(0, wordCount - 1).toInt()
        : group.words.indexWhere((word) {
            final time = group.startMs +
                ((group.endMs - group.startMs) * progress).round();
            return time >= word.startMs && time < word.endMs;
          });
    return const CaptionAnimationEngine().evaluate(
      animationId: _animationId,
      progress: progress,
      wordCount: wordCount,
      activeWord: activeWord,
      characterCount: preview.runes.length,
    );
  }

  Future<void> _savePreferences() async {
    if (_savingProjectId != null || _loading) return;
    final projectId = _selectedProjectId;
    if (projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(cutawanText(context, 'أنشئ مشروعاً أو اختر مشروعاً أولاً لحفظ الإعدادات.'))),
        ),
      );
      return;
    }
    final matches = widget.projects.value.where(
      (project) => project.id == projectId,
    );
    if (matches.isEmpty) {
      setState(() => _error = 'المشروع المحدد لم يعد موجوداً. حدّث قائمة المشاريع.');
      return;
    }
    final project = matches.first;
    final previewOnlyAnimation = !_animationExports;
    final exportAnimation = _exportAnimationId;
    final savedAt = DateTime.now().toUtc();
    final prefs = ClipPreferences.fromJson({
      ...project.preferences.toJson(),
      'captionStyleId': _styleId,
      'captionAnimationId': exportAnimation,
      'captionPreviewAnimationId': _animationId,
      'mainTextColor': _textColor,
      'highlightColor': _highlightColor,
      'captionBackgroundColor': _backgroundColor,
      'captionFontFamily': _fontFamily,
      'captionFontScale': _fontScale,
      'captionPositionY': _positionY,
      'captionUppercase': _uppercase,
      'captionBold': _bold,
      'captionsEnabled': _captionsEnabled,
      'captionTimingOffsetMs': _timingOffsetMs,
    });
    setState(() {
      _savingProjectId = project.id;
      _error = null;
    });
    try {
      await widget.repository.save(
        project.copyWith(
          preferences: prefs,
          updatedAtUtc: savedAt,
        ),
      );
      _loadedPreferencesSnapshot =
          Map<String, Object?>.from(prefs.toJson());
      await widget.onProjectsChanged();
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            previewOnlyAnimation
                ? 'حُفظت إعدادات المشروع. الحركة المختارة للمعاينة فقط؛ سيستخدم MP4 تأثير Static حتى يتوفر دعمها في التصدير.'
                : 'تم حفظ إعدادات Caption Studio في المشروع المحدد.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'تعذّر حفظ إعدادات الاستوديو: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _savingProjectId = null);
      }
    }
  }

  Widget _buildProjectSelector(
    BuildContext context,
    List<CutawanProject> projects,
  ) {
    final theme = Theme.of(context);
    final selected = _selectedProject;
    return CutawanPanel(
      accent: selected != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CutawanEyebrow(
            'المشروع المستهدف',
            icon: Icons.folder_open_rounded,
          ),
          const SizedBox(height: 10),
          KeyedSubtree(
            key: const ValueKey('caption-project-selector'),
            child: DropdownButtonFormField<String>(
            key: ValueKey('caption-project-selector-${selected?.id ?? 'none'}'),
            initialValue: selected?.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'المشروع المستهدف',
              prefixIcon: Icon(Icons.movie_creation_outlined),
            ),
            items: projects
                .map(
                  (project) => DropdownMenuItem<String>(
                    value: project.id,
                    child: Text(
                      project.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: projects.isEmpty || _loading || _savingProjectId != null
                ? null
                : _selectProject,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  selected == null
                      ? 'لا يوجد مشروع محدد'
                      : selected.source.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('caption-project-reload'),
                tooltip: 'تحميل الإعدادات المحفوظة مجدداً',
                onPressed: selected == null || _loading || _savingProjectId != null
                    ? null
                    : () => unawaited(
                          _loadLatestPreferences(projectId: selected.id),
                        ),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2),
          if (selected != null && _previewWords.isNotEmpty)
            Text(cutawanText(context, 'تم تحميل ${_previewWords.length} كلمة مؤقتة من التفريغ المحفوظ.')),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            )
          else if (selected != null)
            Text(cutawanText(context, 'لا يوجد تفريغ موثوق لهذا المشروع؛ ستُستخدم كلمات تجريبية في المعاينة فقط.')),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final theme = Theme.of(context);
    final style = _preset;
    final preview = _previewText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CutawanEyebrow(
          'معاينة متزامنة مع الكلمات',
          icon: Icons.play_circle_outline_rounded,
        ),
        const SizedBox(height: 10),
        if (_previewGroups.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: Text(cutawanText(context, 'المجموعة ${_previewGroupIndex + 1} من ${_previewGroups.length} · '))
                  '${_formatPreviewTime(_previewGroup!.startMs)}–'
                  '${_formatPreviewTime(_previewGroup!.endMs)}',
                  key: const ValueKey('caption-timed-group-label'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              DropdownButton<int>(
                key: const ValueKey('caption-timed-group-selector'),
                value: _previewGroupIndex,
                items: List.generate(
                  _previewGroups.length,
                  (index) => DropdownMenuItem<int>(
                    value: index,
                    child: Text(cutawanText(context, 'مجموعة ${index + 1}'))),
                  ),
                ),
                onChanged: _selectPreviewGroup,
              ),
            ],
          )
        else
          Text(
            _selectedProject == null
                ? 'معاينة تجريبية · اختر مشروعاً بعد إنشائه لعرض الكلمات المحفوظة.'
                : 'معاينة تجريبية · أنشئ تفريغاً موثوقاً لهذا المشروع لعرض توقيت كلماته.',
            key: const ValueKey('caption-sample-preview-notice'),
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            final frame = _frameFor(_animation.value);
            final showBackground = style.highlightBoxColor != null ||
                _backgroundColor.toUpperCase() != '#000000';
            return Container(
              height: 270,
              decoration: BoxDecoration(
                color: const Color(0xFF171717),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PreviewSafeFramePainter(
                        showFrame: _showSafeFrame,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment(0, _positionY * 2 - 1),
                    child: Transform.translate(
                      offset: Offset(0, frame.translateY),
                      child: Opacity(
                        opacity: frame.opacity,
                        child: Transform.scale(
                          scale: frame.scale,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 18),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: showBackground
                                  ? _captionColorFromHex(
                                      _backgroundColor.toUpperCase() == '#000000' &&
                                              style.highlightBoxColor != null
                                          ? style.highlightBoxColor!
                                          : _backgroundColor,
                                    )
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: frame.glow > 0
                                  ? [
                                      BoxShadow(
                                        color: _captionColorFromHex(_highlightColor)
                                            .withValues(
                                          alpha: 0.25 * frame.glow,
                                        ),
                                        blurRadius: 18,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Directionality(
                              textDirection: _rtl
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              child: _buildPreviewText(preview, style, frame),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                _animationExports
                    ? 'هذه الحركة مدعومة في معاينة الاستوديو وتصدير MP4.'
                    : 'هذه الحركة للمعاينة فقط؛ تصدير MP4 يدعم حالياً Static وKaraoke Fill.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _animationExports
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (!_animationExports)
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(cutawanText(context, 'المعاينة تعرض كلمات التفريغ المحفوظة. مزامنة العرض مع فيديو حي ليست جزءاً من هذه الصفحة.')),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          CutawanStatusNote(text: _error!),
        ],
      ],
    );
  }

  Widget _buildStyleGallery(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CutawanEyebrow('الأنماط البصرية', icon: Icons.palette_outlined),
        const SizedBox(height: 8),
        Wrap(
          key: const ValueKey('caption-style-presets'),
          spacing: 8,
          runSpacing: 8,
          children: captionStylePresets
              .map(
                (item) => ChoiceChip(
                  key: ValueKey('caption-style-${item.id}'),
                  label: Text(item.name),
                  selected: _styleId == item.id,
                  onSelected: (_) => _selectStyle(item),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 8),
        Text(cutawanText(context, 'اختيار النمط يحمّل إعداداته الابتدائية، ويمكن تخصيص الخط والألوان والموضع بعد ذلك.')),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildMotionGallery(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CutawanEyebrow(
          'الحركة ومعاينة الدخول',
          icon: Icons.motion_photos_on_outlined,
        ),
        const SizedBox(height: 8),
        Wrap(
          key: const ValueKey('caption-animation-presets'),
          spacing: 8,
          runSpacing: 8,
          children: captionAnimationPresets
              .map(
                (item) => ChoiceChip(
                  key: ValueKey('caption-animation-${item.id}'),
                  label: Text(item.name),
                  selected: _animationId == item.id,
                  onSelected: (_) => _update(() {
                    _animationId = item.id;
                    _error = null;
                  }),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 8),
        CutawanPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _animationExports
                    ? Icons.check_circle_outline_rounded
                    : Icons.visibility_outlined,
                color: _animationExports
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_motion.name}: ${_motion.description}\n'
                  '${_animationExports ? 'متاح في ملف MP4.' : 'مثال بصري فقط؛ سيحفظ تأثير التصدير على Static.'}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColorField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return _CaptionColorField(
      label: label,
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildTypographyControls(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CutawanEyebrow('الخط والتنسيق', icon: Icons.text_fields_rounded),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: const ValueKey('caption-font-family'),
          initialValue: _fontFamily,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'عائلة الخط'),
          items: const [
            DropdownMenuItem(value: 'Anton', child: Text('Anton')),
            DropdownMenuItem(value: 'Poppins', child: Text('Poppins')),
            DropdownMenuItem(
              value: 'Poppins Medium',
              child: Text('Poppins Medium'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            _update(() => _fontFamily = value, rebuildLayout: true);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(cutawanText(context, 'نص عريض'))),
          value: _bold,
          onChanged: (value) => _update(() => _bold = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(cutawanText(context, 'أحرف كبيرة للإنجليزية'))),
          value: _uppercase,
          onChanged: (value) => _update(
            () => _uppercase = value,
            rebuildLayout: true,
          ),
        ),
        Text(cutawanText(context, 'حجم الخط · ${(_fontScale * 100).toStringAsFixed(1)}%')),
          style: theme.textTheme.labelLarge,
        ),
        Slider(
          key: const ValueKey('caption-font-scale'),
          value: _fontScale.clamp(0.025, 0.075).toDouble(),
          min: 0.025,
          max: 0.075,
          divisions: 50,
          onChanged: (value) => _update(
            () => _fontScale = value,
            rebuildLayout: true,
          ),
        ),
        Text(cutawanText(context, 'موضع النص · ${(_positionY * 100).round()}% من أعلى الإطار')),
          style: theme.textTheme.labelLarge,
        ),
        Slider(
          key: const ValueKey('caption-position-y'),
          value: _positionY,
          min: 0.1,
          max: 0.9,
          divisions: 80,
          onChanged: (value) => _update(() => _positionY = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(cutawanText(context, 'إظهار إطار الأمان'))),
          value: _showSafeFrame,
          onChanged: (value) => setState(() => _showSafeFrame = value),
        ),
        const SizedBox(height: 6),
        const CutawanEyebrow('ألوان الترجمة', icon: Icons.color_lens_outlined),
        const SizedBox(height: 8),
        _buildColorField(
          label: 'لون النص',
          value: _textColor,
          onChanged: (value) => _setColor('text', value),
        ),
        _buildColorField(
          label: 'لون الكلمة النشطة',
          value: _highlightColor,
          onChanged: (value) => _setColor('highlight', value),
        ),
        _buildColorField(
          label: 'خلفية صندوق التمييز',
          value: _backgroundColor,
          onChanged: (value) => _setColor('background', value),
        ),
      ],
    );
  }

  Widget _buildTimingControls(BuildContext context) {
    final theme = Theme.of(context);
    final prefix = _timingOffsetMs > 0 ? '+' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CutawanEyebrow(
          'مزامنة الكلمات',
          icon: Icons.sync_alt_rounded,
        ),
        const SizedBox(height: 8),
        Text(cutawanText(context, 'إزاحة توقيت الكلمات · $prefix$_timingOffsetMs ms')),
          key: const ValueKey('caption-timing-offset-label'),
          style: theme.textTheme.labelLarge,
        ),
        Slider(
          key: const ValueKey('caption-timing-offset'),
          value: _timingOffsetMs.toDouble(),
          min: -2000,
          max: 2000,
          divisions: 80,
          onChanged: (value) => _update(
            () => _timingOffsetMs = value.round(),
            rebuildLayout: true,
          ),
        ),
        Text(cutawanText(context, 'القيمة تحفظ داخل المشروع وتؤثر في توقيت الكلمات المُصدّرة. المعاينة التجريبية لا تستبدل تشغيل الفيديو.')),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projects = widget.projects.value;
    final selected = _selectedProject;
    final style = _preset;
    final motion = _motion;
    return ListView(
      key: const ValueKey('caption-studio-list'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      children: [
        const CutawanEyebrow(
          'CAPTION STUDIO',
          icon: Icons.closed_caption_rounded,
        ),
        const SizedBox(height: 12),
        Text(cutawanText(context, 'مختبر الهوية النصية')),
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 30,
          ),
        ),
        const SizedBox(height: 7),
        Text(cutawanText(context, 'اضبط شكل الكلمات وتوقيتها ثم احفظ الإعدادات داخل المشروع الذي تختاره.')),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _buildProjectSelector(context, projects),
        if (projects.isEmpty) ...[
          const SizedBox(height: 12),
          const CutawanEmptyState(
            icon: Icons.movie_creation_outlined,
            title: 'لا توجد مشاريع بعد',
            description: 'يمكنك استكشاف المعاينة والأنماط الآن، ثم اختيار مشروع لحفظ إعدادات الترجمة داخله.',
          ),
        ],
        const SizedBox(height: 18),
        CutawanPanel(
          padding: const EdgeInsets.all(14),
          child: _buildPreview(context),
        ),
        const SizedBox(height: 22),
        _buildStyleGallery(context),
        const SizedBox(height: 22),
        _buildMotionGallery(context),
        const SizedBox(height: 22),
        _buildTypographyControls(context),
        const SizedBox(height: 22),
        SwitchListTile(
          key: const ValueKey('caption-export-enabled'),
          contentPadding: EdgeInsets.zero,
          title: Text(cutawanText(context, 'إظهار الترجمة في تصدير الفيديو'))),
          subtitle: Text(cutawanText(context, 'عند الإيقاف تبقى إعدادات النمط محفوظة دون حرق الكلمات داخل MP4.'))),
          value: _captionsEnabled,
          onChanged: (value) => _update(() => _captionsEnabled = value),
        ),
        const SizedBox(height: 22),
        _buildTimingControls(context),
        const SizedBox(height: 18),
        SwitchListTile(
          key: const ValueKey('caption-direction-switch'),
          contentPadding: EdgeInsets.zero,
          title: Text(cutawanText(context, 'اتجاه معاينة النص'))),
          subtitle: Text(_rtl ? 'العربية · من اليمين إلى اليسار' : 'English · left to right'),
          value: _rtl,
          onChanged: (value) => setState(() => _rtl = value),
        ),
        if (_dirty)
          const CutawanStatusNote(
            text: 'توجد تعديلات غير محفوظة على المشروع المحدد.',
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('caption-studio-save'),
          onPressed: selected == null ||
                  _loading ||
                  _savingProjectId != null
              ? null
              : _savePreferences,
          icon: _savingProjectId == null
              ? const Icon(Icons.save_outlined)
              : const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
          label: Text(
            _savingProjectId == null
                ? 'حفظ الإعدادات في المشروع المحدد'
                : 'جارٍ الحفظ…',
          ),
        ),
        const SizedBox(height: 8),
        Text(cutawanText(context, 'Preset: ${style.id} · معاينة الحركة: ${motion.id} · تصدير MP4: $_exportAnimationId')),
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewText(
    String text,
    CaptionStylePreset style,
    CaptionAnimationFrame frame,
  ) {
    if (_animationId == 'typewriter') {
      final partial = String.fromCharCodes(
        text.runes.take(frame.revealedCharacters),
      );
      return Text(
        partial,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _captionColorFromHex(_textColor),
          fontFamily: _fontFamily,
          fontSize: (250 * _fontScale).clamp(10.0, 36.0).toDouble(),
          fontWeight: (_bold || style.bold) ? FontWeight.bold : FontWeight.w600,
          shadows: [
            if (style.outlineWidth > 0)
              Shadow(
                color: _captionColorFromHex(style.outlineColor),
                blurRadius: style.outlineWidth * 1.6,
              ),
          ],
        ),
      );
    }
    final words = text.split(RegExp(r'\s+'));
    final visible = words.take(frame.revealedWords);
    final spans = <InlineSpan>[];
    var index = 0;
    for (final word in visible) {
      final active = index == frame.highlightedWord;
      spans.add(
        TextSpan(
          text: '$word ',
          style: TextStyle(
            color: active
                ? _captionColorFromHex(_highlightColor)
                : _captionColorFromHex(_textColor),
            fontFamily: _fontFamily,
            fontSize: (250 * _fontScale).clamp(10.0, 36.0).toDouble(),
            fontWeight: (_bold || style.bold) ? FontWeight.bold : FontWeight.w600,
            shadows: [
              if (style.outlineWidth > 0)
                Shadow(
                  color: _captionColorFromHex(style.outlineColor),
                  blurRadius: style.outlineWidth * 1.6,
                ),
              if (style.shadow > 0)
                Shadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: style.shadow * 3,
                  offset: const Offset(1, 2),
                ),
            ],
          ),
        ),
      );
      index++;
    }
    return RichText(
      textAlign: TextAlign.center,
      textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
      text: TextSpan(children: spans),
    );
  }
}

class _CaptionColorField extends StatefulWidget {
  const _CaptionColorField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_CaptionColorField> createState() => _CaptionColorFieldState();
}

class _CaptionColorFieldState extends State<_CaptionColorField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _CaptionColorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: _controller,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: '#RRGGBB',
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: CircleAvatar(
                backgroundColor: _captionColorFromHex(widget.value),
                radius: 10,
              ),
            ),
          ),
          onSubmitted: widget.onChanged,
        ),
      );
}

class _PreviewSafeFramePainter extends CustomPainter {
  const _PreviewSafeFramePainter({required this.showFrame});

  final bool showFrame;

  @override
  void paint(Canvas canvas, Size size) {
    if (!showFrame) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.08,
        size.height * 0.08,
        size.width * 0.84,
        size.height * 0.84,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PreviewSafeFramePainter oldDelegate) =>
      oldDelegate.showFrame != showFrame;
}


Color _captionColorFromHex(String hex) {
  final parsed = int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0xFFFFFF;
  return Color(0xFF000000 | parsed);
}
