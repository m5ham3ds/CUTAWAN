part of '../home_shell.dart';

class CaptionStudioPage extends StatefulWidget {
  const CaptionStudioPage({required this.projects, required this.repository, required this.onProjectsChanged, super.key});
  final ValueListenable<List<CutawanProject>> projects;
  final LocalProjectRepository repository;
  final Future<void> Function() onProjectsChanged;
  @override State<CaptionStudioPage> createState() => _CaptionStudioPageState();
}

class _CaptionStudioPageState extends State<CaptionStudioPage> with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  String _styleId = 'beast';
  String _animationId = 'word_pop';
  String _textColor = '#FFFFFF';
  String _highlightColor = '#FFD400';
  String _backgroundColor = '#000000';
  String _fontFamily = 'Anton';
  double _fontScale = 0.052;
  double _positionY = 0.72;
  bool _uppercase = true;
  bool _bold = false;
  bool _rtl = true;
  bool _showSafeFrame = false;
  String? _error;
  String? _savingProjectId;
  bool _loaded = false;
  List<CaptionWordTiming> _previewWords = const [];
  List<CaptionWordGroup> _previewGroups = const [];
  double _previewAspectRatio = 9 / 16;
  int _previewGroupIndex = 0;
  static const _arabicSample = 'هذه لحظة تستحق أن تتحول إلى مقطع قصير';
  static const _englishSample = 'This is the moment worth sharing with everyone';

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    widget.projects.addListener(_handleProjectChange);
    _loadLatestPreferences();
  }
  @override
  void didUpdateWidget(covariant CaptionStudioPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projects != widget.projects) {
      oldWidget.projects.removeListener(_handleProjectChange);
      widget.projects.addListener(_handleProjectChange);
      _loaded = false;
      _loadLatestPreferences();
    }
  }
  @override
  void dispose() {
    widget.projects.removeListener(_handleProjectChange);
    _animation.dispose();
    super.dispose();
  }
  CaptionStylePreset get _preset => captionStylePresets.firstWhere((item) => item.id == _styleId);
  CaptionAnimationPreset get _motion => captionAnimationPresets.firstWhere((item) => item.id == _animationId);
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

  void _rebuildPreviewGroups({bool restartAnimation = true}) {
    if (_previewWords.isEmpty) {
      _previewGroups = const [];
      _previewGroupIndex = 0;
      _animation.duration = const Duration(milliseconds: 1200);
    } else {
      try {
        _previewGroups = const CaptionLayoutEngine().group(
          _previewWords,
          const CaptionLayoutEngine().budget(
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

  void _handleProjectChange() {
    _loaded = false;
    _loadLatestPreferences();
  }

  Future<void> _loadLatestPreferences() async {
    if (_loaded) return;
    final projects = widget.projects.value;
    if (projects.isEmpty) {
      if (!mounted) return;
      setState(() {
        _previewWords = const [];
        _previewGroups = const [];
        _previewAspectRatio = 9 / 16;
        _previewGroupIndex = 0;
        _loaded = true;
        _rebuildPreviewGroups();
      });
      return;
    }

    final project = projects.first;
    final prefs = project.preferences;
    final matches =
        captionStylePresets.where((item) => item.id == prefs.captionStyleId);
    final style = matches.isEmpty ? captionStylePresets.first : matches.first;
    CutawanTranscript? transcript;
    String? transcriptError;
    try {
      transcript = await widget.repository.loadTranscript(project.id);
    } catch (error) {
      transcriptError = 'تعذّر قراءة التفريغ المحفوظ: $error';
    }
    if (!mounted ||
        widget.projects.value.isEmpty ||
        widget.projects.value.first.id != project.id) {
      return;
    }

    setState(() {
      _styleId = style.id;
      _animationId = captionAnimationPresets
              .any((item) => item.id == prefs.captionAnimationId)
          ? prefs.captionAnimationId
          : 'static';
      _textColor = prefs.mainTextColor;
      _highlightColor = prefs.highlightColor;
      _backgroundColor = prefs.captionBackgroundColor;
      _fontFamily = prefs.captionFontFamily ?? style.fontFamily;
      _fontScale =
          prefs.captionFontScale > 0 ? prefs.captionFontScale : style.fontScale;
      _positionY =
          prefs.captionPositionY >= 0 ? prefs.captionPositionY : style.positionY;
      _uppercase = prefs.captionUppercase ?? style.uppercase;
      _bold = prefs.captionBold ?? style.bold;
      if (transcript != null) {
        final language = transcript.language.toLowerCase();
        _rtl = language.startsWith('ar') ||
            language.startsWith('fa') ||
            language.startsWith('ur');
      }
      _previewWords = transcript == null
          ? const []
          : transcript.words
              .map((word) => CaptionWordTiming(
                    text: word.text,
                    startMs: word.startMs,
                    endMs: word.endMs,
                  ))
              .toList(growable: false);
      _previewAspectRatio = _aspectRatioFor(project);
      _previewGroupIndex = 0;
      _error = transcriptError;
      _loaded = true;
      _rebuildPreviewGroups();
    });
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
      _rebuildPreviewGroups();
    });
  }
  void _setColor(String field, String value) {
    final validColor = RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value);
    if (!validColor) {
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
    if (_savingProjectId != null) {
      return;
    }
    final projects = widget.projects.value;
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أنشئ مشروعاً أولاً حتى تحفظ إعدادات الاستوديو داخله.')));
      return;
    }
    final project = projects.first;
    final prefs = ClipPreferences.fromJson({
      ...project.preferences.toJson(),
      'captionStyleId': _styleId,
      'captionAnimationId': _animationId,
      'mainTextColor': _textColor,
      'highlightColor': _highlightColor,
      'captionBackgroundColor': _backgroundColor,
      'captionFontFamily': _fontFamily,
      'captionFontScale': _fontScale,
      'captionPositionY': _positionY,
      'captionUppercase': _uppercase,
      'captionBold': _bold,
    });
    setState(() { _savingProjectId = project.id; _error = null; });
    try {
      await widget.repository.save(project.copyWith(preferences: prefs, updatedAtUtc: DateTime.now().toUtc()));
      await widget.onProjectsChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ إعدادات الاستوديو في المشروع.')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = _preset;
    final motion = _motion;
    final preview = _previewText;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        const _Eyebrow('مساحة العمل  /  Caption Studio', icon: Icons.closed_caption_rounded),
        const SizedBox(height: 14),
        Text('مختبر الهوية النصية', style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900, fontSize: 31)),
        const SizedBox(height: 8),
        Text('ابنِ بصمة بصرية متناسقة للكلمات: النمط، الخط، لوحة الألوان، موضع العرض وحركة التوقيت.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 18),
        _Panel(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), child: Row(children: [const Expanded(child: Text('معاينة اتجاه النص')), Switch(key: const ValueKey('caption-direction-switch'), value: _rtl, onChanged: (value) => setState(() => _rtl = value)), Text(_rtl ? 'العربية' : 'English')])),
        const SizedBox(height: 8),
        if (_previewGroups.isNotEmpty) ...[
          Text('معاينة من التفريغ المحفوظ', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: Text(
                'المجموعة ${_previewGroupIndex + 1} من ${_previewGroups.length} · ${_formatPreviewTime(_previewGroup!.startMs)}–${_formatPreviewTime(_previewGroup!.endMs)}',
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
                  child: Text('مجموعة ${index + 1}'),
                ),
              ),
              onChanged: _selectPreviewGroup,
            ),
          ]),
        ] else
          Text(
            widget.projects.value.isEmpty
                ? 'معاينة تجريبية · أنشئ مشروعاً وأجرِ التفريغ لرؤية توقيت كلماتك.'
                : 'لا يوجد تفريغ محفوظ لهذا المشروع؛ تُعرض معاينة تجريبية حتى إكمال التفريغ.',
            key: const ValueKey('caption-sample-preview-notice'),
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            final frame = _frameFor(_animation.value);
            return Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 270,
                decoration: BoxDecoration(color: const Color(0xFF171717), borderRadius: BorderRadius.circular(18), border: Border.all(color: theme.colorScheme.outlineVariant)),
                clipBehavior: Clip.antiAlias,
                child: Stack(children: [
                Positioned.fill(child: CustomPaint(painter: _PreviewSafeFramePainter(showFrame: _showSafeFrame))),
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(color: style.highlightBoxColor == null ? Colors.transparent : _colorFromHex(_backgroundColor), borderRadius: BorderRadius.circular(10), boxShadow: frame.glow > 0 ? [BoxShadow(color: _colorFromHex(_highlightColor).withValues(alpha: 0.25 * frame.glow), blurRadius: 18)] : null),
                          child: Directionality(
                            textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
                            child: _buildPreviewText(preview, style, frame),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ]),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text('تعرض المعاينة كلمات التفريغ بتوقيتها. مزامنتها مع تشغيل الفيديو وحرق الكابشن داخل MP4 ما زالا ضمن عمل محرّك التصدير.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        if (_error != null) ...[const SizedBox(height: 10), _StatusNote(text: _error!)],
        const SizedBox(height: 22),
        const _Eyebrow('التصميم البصري', icon: Icons.palette_outlined),
        const SizedBox(height: 10),
        Wrap(key: const ValueKey('caption-style-presets'), spacing: 8, runSpacing: 8, children: captionStylePresets.map((item) => ChoiceChip(key: ValueKey('caption-style-${item.id}'), label: Text(item.name), selected: _styleId == item.id, onSelected: (_) => _selectStyle(item))).toList()),
        const SizedBox(height: 22),
        const _Eyebrow('الحركة المستقلة', icon: Icons.motion_photos_on_outlined),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _animationId,
          isExpanded: true,
          items: captionAnimationPresets.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
          onChanged: (value) { if (value != null) {
              setState(() => _animationId = value);
            } },
        ),
        const SizedBox(height: 6),
        Text('${motion.name}: ${motion.description}', style: theme.textTheme.bodySmall),
        const SizedBox(height: 18),
        const _Eyebrow('الخط والتنسيق', icon: Icons.text_fields_rounded),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _fontFamily,
          decoration: const InputDecoration(labelText: 'عائلة الخط'),
          items: const [DropdownMenuItem(value: 'Anton', child: Text('Anton')), DropdownMenuItem(value: 'Poppins', child: Text('Poppins')), DropdownMenuItem(value: 'Poppins Medium', child: Text('Poppins Medium'))],
          onChanged: (value) { if (value != null) {
              setState(() {
                _fontFamily = value;
                _rebuildPreviewGroups();
              });
            } },
        ),
        Material(
          color: Colors.transparent,
          child: SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('نص عريض'), value: _bold, onChanged: (value) => setState(() => _bold = value)),
        ),
        Material(
          color: Colors.transparent,
          child: SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('أحرف كبيرة للإنجليزية'), value: _uppercase, onChanged: (value) {
            setState(() {
              _uppercase = value;
              _rebuildPreviewGroups();
            });
          }),
        ),
        Text('حجم الخط · ${(_fontScale * 100).toStringAsFixed(1)}%'),
        Slider(value: _fontScale, min: 0.025, max: 0.075, divisions: 50, onChanged: (value) {
          setState(() {
            _fontScale = value;
            _rebuildPreviewGroups();
          });
        }),
        Text('موضع النص · ${(_positionY * 100).round()}% من أعلى الإطار'),
        Slider(value: _positionY, min: 0.1, max: 0.9, divisions: 80, onChanged: (value) => setState(() => _positionY = value)),
        Material(
          color: Colors.transparent,
          child: SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('إظهار إطار الأمان'), value: _showSafeFrame, onChanged: (value) => setState(() => _showSafeFrame = value)),
        ),
        const SizedBox(height: 8),
        const _Eyebrow('الألوان', icon: Icons.color_lens_outlined),
        const SizedBox(height: 8),
        _CaptionColorField(label: 'لون النص', value: _textColor, onChanged: (value) => _setColor('text', value)),
        _CaptionColorField(label: 'لون التمييز', value: _highlightColor, onChanged: (value) => _setColor('highlight', value)),
        _CaptionColorField(label: 'خلفية صندوق التمييز', value: _backgroundColor, onChanged: (value) => _setColor('background', value)),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _savingProjectId == null ? _savePreferences : null,
          icon: _savingProjectId == null ? const Icon(Icons.save_outlined) : const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          label: Text(_savingProjectId == null ? 'حفظ إعدادات الاستوديو في المشروع' : 'جارٍ الحفظ…'),
        ),
        const SizedBox(height: 8),
        Text('Preset: ${style.id} · Animation: ${motion.id}', style: theme.textTheme.labelSmall),
      ],
    );
  }

  Widget _buildPreviewText(String text, CaptionStylePreset style, CaptionAnimationFrame frame) {
    if (_animationId == 'typewriter') {
      final partial = String.fromCharCodes(text.runes.take(frame.revealedCharacters));
      return Text(partial, textAlign: TextAlign.center, style: TextStyle(
        color: _colorFromHex(_textColor),
        fontFamily: _fontFamily,
        fontSize: (250 * _fontScale).clamp(10.0, 36.0).toDouble(),
        fontWeight: (_bold || style.bold) ? FontWeight.bold : FontWeight.w600,
        shadows: [if (style.outlineWidth > 0) Shadow(color: _colorFromHex(style.outlineColor), blurRadius: style.outlineWidth * 1.6)],
      ));
    }
    final words = text.split(RegExp(r'\s+'));
    final visible = words.take(frame.revealedWords);
    final spans = <InlineSpan>[];
    var index = 0;
    for (final word in visible) {
      final active = index == frame.highlightedWord;
      spans.add(TextSpan(text: '$word ', style: TextStyle(
        color: active ? _colorFromHex(_highlightColor) : _colorFromHex(_textColor),
        fontFamily: _fontFamily,
        fontSize: (250 * _fontScale).clamp(10.0, 36.0).toDouble(),
        fontWeight: (_bold || style.bold) ? FontWeight.bold : FontWeight.w600,
        shadows: [
          if (style.outlineWidth > 0) Shadow(color: _colorFromHex(style.outlineColor), blurRadius: style.outlineWidth * 1.6),
          if (style.shadow > 0) Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: style.shadow * 3, offset: const Offset(1, 2)),
        ],
      )));
      index++;
    }
    return RichText(textAlign: TextAlign.center, textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr, text: TextSpan(children: spans));
  }
}

class _CaptionColorField extends StatefulWidget {
  const _CaptionColorField({required this.label, required this.value, required this.onChanged});
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  @override State<_CaptionColorField> createState() => _CaptionColorFieldState();
}
class _CaptionColorFieldState extends State<_CaptionColorField> {
  late final TextEditingController _controller;
  @override void initState() { super.initState(); _controller = TextEditingController(text: widget.value); }
  @override void didUpdateWidget(covariant _CaptionColorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.value = TextEditingValue(text: widget.value, selection: TextSelection.collapsed(offset: widget.value.length));
      }
  }
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(controller: _controller, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: widget.label, hintText: '#RRGGBB', prefixIcon: Padding(padding: const EdgeInsets.all(12), child: CircleAvatar(backgroundColor: _colorFromHex(widget.value), radius: 10))), onSubmitted: widget.onChanged),
  );
}
class _PreviewSafeFramePainter extends CustomPainter {
  const _PreviewSafeFramePainter({required this.showFrame});
  final bool showFrame;
  @override void paint(Canvas canvas, Size size) {
    if (!showFrame) {
      return;
    }
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.18)..style = PaintingStyle.stroke..strokeWidth = 1;
    canvas.drawRect(Rect.fromLTWH(size.width * 0.08, size.height * 0.08, size.width * 0.84, size.height * 0.84), paint);
  }
  @override bool shouldRepaint(covariant _PreviewSafeFramePainter oldDelegate) => oldDelegate.showFrame != showFrame;
}
