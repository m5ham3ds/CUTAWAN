part of '../home_shell.dart';

class CreatePage extends StatefulWidget {
  const CreatePage({required this.repository, required this.onProjectSaved, super.key});
  final LocalProjectRepository repository;
  final Future<void> Function() onProjectSaved;
  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  final _urlController = TextEditingController();
  final _minimumController = TextEditingController(text: '15');
  final _maximumController = TextEditingController(text: '90');
  int _step = 0;
  VideoAssetMetadata? _source;
  bool _sourceIsDownloaded = false;
  bool _projectSaved = false;
  bool _busy = false;
  DownloadCancellation? _cancellation;
  VideoDownloadProgress? _downloadProgress;
  DateTime _lastProgress = DateTime.fromMillisecondsSinceEpoch(0);
  int _clipCount = 10;
  ClipDurationMode _duration = ClipDurationMode.automatic;
  ClipAspectRatio _ratio = ClipAspectRatio.portrait916;
  String _resolution = '1080p';
  String _styleId = 'karaoke';
  String _animationId = 'word_pop';
  bool _captions = true;

  @override
  void dispose() {
    _cancellation?.cancel();
    final source = _source;
    if (source != null && !_projectSaved) {
      unawaited(_discardSource(source, downloaded: _sourceIsDownloaded));
    }
    _urlController.dispose();
    _minimumController.dispose();
    _maximumController.dispose();
    super.dispose();
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  ClipPreferences _preferences() {
    final minimum = _duration == ClipDurationMode.custom
        ? int.tryParse(_minimumController.text.trim())
        : 15;
    final maximum = _duration == ClipDurationMode.custom
        ? int.tryParse(_maximumController.text.trim())
        : 90;
    if (minimum == null || maximum == null) {
      throw const FormatException('أدخل حدّي المدة المخصصة كأرقام صحيحة.');
    }
    final value = ClipPreferences(
      requestedClipCount: _clipCount,
      durationMode: _duration,
      customMinimumSeconds: minimum,
      customMaximumSeconds: maximum,
      aspectRatio: _ratio,
      resolution: _resolution,
      captionsEnabled: _captions,
      speakerTrackingEnabled: true,
      captionStyleId: _styleId,
      captionAnimationId: _animationId,
    );
    final error = value.validate();
    if (error != null) throw FormatException(error);
    return value;
  }

  DirectVideoDownloader _downloader() => DirectVideoDownloader(
        availableStorageBytes: AndroidVideoPicker.availableStorageBytes,
        inspectLocalFile: AndroidVideoPicker.inspectLocalFile,
      );

  Future<void> _selectVideo() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await AndroidVideoPicker.pickVideo();
      if (picked == null) {
        _message('لم يتم اختيار فيديو.');
      } else {
        await _setPendingSource(picked, downloaded: false);
      }
    } on PlatformException catch (error) {
      _message(error.message ?? 'تعذّر اختيار الفيديو من Android.');
    } catch (error) {
      _message('تعذّر تجهيز الفيديو: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _downloadVideo() async {
    if (_busy) return;
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _message('أدخل رابط ملف فيديو مباشر أولاً.');
      return;
    }
    final cancellation = DownloadCancellation();
    setState(() {
      _busy = true;
      _cancellation = cancellation;
      _downloadProgress = null;
    });
    try {
      final source = await _downloader().download(
        url,
        cancellation: cancellation,
        onProgress: (progress) {
          final now = DateTime.now();
          if (now.difference(_lastProgress).inMilliseconds < 180 &&
              progress.fraction != 1) {
            return;
          }
          _lastProgress = now;
          if (mounted) {
            setState(() => _downloadProgress = progress);
          }
        },
      );
      if (!mounted) {
        await _discardSource(source, downloaded: true);
        return;
      }
      _urlController.clear();
      await _setPendingSource(source, downloaded: true);
      _message('اكتمل تنزيل الفيديو وفحصه. انتقل إلى إعدادات المشروع.');
    } on VideoDownloadCancelled {
      _message('أُلغي التنزيل وحُذفت الأجزاء المؤقتة.');
    } on PlatformException catch (error) {
      _message(error.message ?? 'تعذّر الوصول إلى خدمات تخزين Android.');
    } catch (error) {
      _message('تعذّر تنزيل الفيديو: $error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _cancellation = null;
          _downloadProgress = null;
        });
      }
    }
  }

  void _cancelDownload() => _cancellation?.cancel();

  Future<void> _setPendingSource(VideoAssetMetadata next, {required bool downloaded}) async {
    if (!mounted) {
      await _discardSource(next, downloaded: downloaded);
      return;
    }
    final previous = _source;
    final previousDownloaded = _sourceIsDownloaded;
    setState(() {
      _source = next;
      _sourceIsDownloaded = downloaded;
    });
    if (previous != null && previous.uri != next.uri && !_projectSaved) {
      await _discardSource(previous, downloaded: previousDownloaded);
    }
  }

  Future<void> _discardSource(VideoAssetMetadata source, {required bool downloaded}) async {
    if (downloaded && Uri.tryParse(source.uri)?.scheme == 'file') {
      try {
        await _downloader().deleteDownloadedVideo(source.uri);
      } catch (_) {
        // Best-effort cleanup of a download owned by this app.
      }
      return;
    }
    if (Uri.tryParse(source.uri)?.scheme != 'content') return;
    try {
      final projects = await widget.repository.listProjects();
      if (!projects.any((project) => project.source.uri == source.uri)) {
        await AndroidVideoPicker.releasePersistedPermission(source.uri);
      }
    } catch (_) {
      // Keep SAF access if the repository cannot be checked safely.
    }
  }

  Future<void> _createProject() async {
    if (_busy) return;
    final source = _source;
    if (source == null) {
      setState(() => _step = 0);
      _message('اختر الفيديو أولاً.');
      return;
    }
    late final ClipPreferences prefs;
    try {
      prefs = _preferences();
    } on FormatException catch (error) {
      _message(error.message);
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.repository.save(CutawanProject.create(source: source, preferences: prefs));
      _projectSaved = true;
      _source = null;
      _sourceIsDownloaded = false;
      await widget.onProjectSaved();
    } on PlatformException catch (error) {
      _message(error.message ?? 'تعذّر حفظ المشروع على Android.');
    } catch (error) {
      _message('تعذّر إنشاء المشروع: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String get _durationLabel => switch (_duration) {
        ClipDurationMode.automatic => 'تلقائي',
        ClipDurationMode.seconds15To30 => '15–30 ثانية',
        ClipDurationMode.seconds30To45 => '30–45 ثانية',
        ClipDurationMode.seconds30To60 => '30–60 ثانية',
        ClipDurationMode.seconds60To90 => '60–90 ثانية',
        ClipDurationMode.custom => 'مخصصة',
      };

  String get _ratioLabel => switch (_ratio) {
        ClipAspectRatio.portrait916 => '9:16',
        ClipAspectRatio.square11 => '1:1',
        ClipAspectRatio.landscape169 => '16:9',
        ClipAspectRatio.original => 'الأصلية',
      };

  Widget _sourceCard({bool change = false}) {
    final source = _source!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _Panel(
      accent: true,
      child: Row(children: [
        Icon(Icons.video_file_outlined, color: scheme.primary, size: 28),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(source.displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${source.width} × ${source.height} · ${_formatDuration(source.durationMs)} · ${_formatBytes(source.sizeBytes)}',
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            Text(source.mimeType, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        )),
        if (change)
          IconButton(
            key: const ValueKey('create-change-source'),
            tooltip: 'تغيير الفيديو',
            onPressed: _busy ? null : () => setState(() => _step = 0),
            icon: const Icon(Icons.edit_outlined),
          )
        else
          Icon(Icons.check_circle_rounded, color: scheme.primary),
      ]),
    );
  }

  Widget _buildSourceStep(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _Eyebrow('01 / مصدر الفيديو', icon: Icons.video_file_outlined),
      const SizedBox(height: 8),
      Text('أضف الفيديو الأصلي', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text('ابدأ بملف واحد. بعد فحصه سننتقل إلى إعداد عدد المقاطع ومدتها ونسبة الإخراج.',
        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.5)),
      const SizedBox(height: 16),
      _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          key: const ValueKey('create-direct-video-url'),
          controller: _urlController,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'رابط ملف الفيديو المباشر',
            hintText: 'https://example.com/video.mp4',
            prefixIcon: Icon(Icons.link_rounded),
          ),
          onSubmitted: (_) => _downloadVideo(),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, constraints) {
          final download = FilledButton.icon(
            key: const ValueKey('create-download-direct'),
            onPressed: _busy ? null : _downloadVideo,
            icon: const Icon(Icons.download_rounded),
            label: const Text('تنزيل الرابط'),
          );
          final pick = OutlinedButton.icon(
            key: const ValueKey('create-pick-local'),
            onPressed: _busy ? null : _selectVideo,
            icon: const Icon(Icons.folder_open_rounded),
            label: const Text('اختيار فيديو'),
          );
          if (constraints.maxWidth < 390) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [download, const SizedBox(height: 9), pick]);
          }
          return Row(children: [Expanded(child: download), const SizedBox(width: 10), Expanded(child: pick)]);
        }),
        if (_busy && _downloadProgress != null) ...[
          const SizedBox(height: 14),
          LinearProgressIndicator(value: _downloadProgress!.fraction, borderRadius: BorderRadius.circular(99)),
          const SizedBox(height: 7),
          Text(_downloadProgress!.totalBytes == null
              ? 'تم تنزيل ${_formatBytes(_downloadProgress!.receivedBytes)}'
              : '${_formatBytes(_downloadProgress!.receivedBytes)} من ${_formatBytes(_downloadProgress!.totalBytes!)}',
            style: theme.textTheme.bodySmall),
          Align(alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(onPressed: _cancelDownload,
              icon: const Icon(Icons.close_rounded), label: const Text('إلغاء التنزيل'))),
        ],
        if (_busy && _downloadProgress == null) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          const SizedBox(height: 7),
          Text('جارٍ اختيار الفيديو وفحص بياناته…', style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 10),
        Text('المصادر المتاحة: ملفات الجهاز وروابط HTTP/HTTPS المباشرة لملفات الفيديو. روابط YouTube وTwitch وVimeo والمنصات التي تتطلب تجاوز قيود الوصول غير مدعومة حاليًا.',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.45)),
      ])),
      if (_source != null) ...[
        const SizedBox(height: 16),
        Text('المصدر المختار', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _sourceCard(),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          key: const ValueKey('create-step-continue'),
          onPressed: _busy ? null : () => setState(() => _step = 1),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('متابعة إلى إعدادات المقاطع'),
        )),
      ],
    ]);
  }

  Widget _buildSettingsStep(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _Eyebrow('02 / إعداد المشروع', icon: Icons.tune_rounded),
      const SizedBox(height: 8),
      Text('اضبط المقاطع قبل الإنشاء', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text('راجع الإعدادات قبل إنشاء المشروع. سيحتفظ المشروع بها لاستخدامها في مسار المعالجة.',
        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.5)),
      const SizedBox(height: 16),
      _sourceCard(change: true),
      const SizedBox(height: 14),
      _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('عدد المقاطع المطلوبة', style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [5, 10, 15, 20].map((count) => ChoiceChip(
          key: ValueKey('create-clip-count-$count'),
          label: Text('$count'),
          selected: _clipCount == count,
          onSelected: _busy ? null : (_) => setState(() => _clipCount = count),
        )).toList()),
        const SizedBox(height: 18),
        Text('المدة المستهدفة', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<ClipDurationMode>(
          key: const ValueKey('create-duration-mode'),
          initialValue: _duration,
          isExpanded: true,
          items: ClipDurationMode.values.map((mode) => DropdownMenuItem(
            value: mode,
            child: Text(switch (mode) {
              ClipDurationMode.automatic => 'تلقائي حسب اكتمال اللحظة',
              ClipDurationMode.seconds15To30 => '15–30 ثانية',
              ClipDurationMode.seconds30To45 => '30–45 ثانية',
              ClipDurationMode.seconds30To60 => '30–60 ثانية',
              ClipDurationMode.seconds60To90 => '60–90 ثانية',
              ClipDurationMode.custom => 'مدة مخصصة',
            }),
          )).toList(),
          onChanged: _busy ? null : (value) {
            if (value != null) {
              setState(() => _duration = value);
            }
          },
        ),
        if (_duration == ClipDurationMode.custom) ...[
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final minField = TextField(
              key: const ValueKey('create-minimum-seconds'),
              controller: _minimumController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'أقل مدة (ثانية)'),
            );
            final maxField = TextField(
              key: const ValueKey('create-maximum-seconds'),
              controller: _maximumController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'أقصى مدة (ثانية)'),
            );
            if (constraints.maxWidth < 390) {
              return Column(children: [minField, const SizedBox(height: 10), maxField]);
            }
            return Row(children: [Expanded(child: minField), const SizedBox(width: 12), Expanded(child: maxField)]);
          }),
        ],
      ])),
      const SizedBox(height: 12),
      _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('نسبة أبعاد الفيديو', style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: ClipAspectRatio.values.map((ratio) {
          final label = switch (ratio) {
            ClipAspectRatio.portrait916 => '9:16',
            ClipAspectRatio.square11 => '1:1',
            ClipAspectRatio.landscape169 => '16:9',
            ClipAspectRatio.original => 'الأصلية',
          };
          return ChoiceChip(
            key: ValueKey('create-ratio-${ratio.name}'),
            label: Text(label),
            selected: _ratio == ratio,
            onSelected: _busy ? null : (_) => setState(() => _ratio = ratio),
          );
        }).toList()),
        const SizedBox(height: 18),
        Text('جودة الإخراج', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: const ValueKey('create-export-resolution'),
          initialValue: _resolution,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: '720p', child: Text('720p')),
            DropdownMenuItem(value: '1080p', child: Text('1080p')),
          ],
          onChanged: _busy ? null : (value) {
            if (value != null) {
              setState(() => _resolution = value);
            }
          },
        ),
      ])),
      const SizedBox(height: 12),
      _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SwitchListTile(
          key: const ValueKey('create-captions-enabled'),
          contentPadding: EdgeInsets.zero,
          title: const Text('إنشاء الترجمة النصية'),
          subtitle: const Text('تفريغ الكلام وتوليد توقيت الكلمات وتركيب الترجمة على المقاطع.'),
          value: _captions,
          onChanged: _busy ? null : (value) => setState(() => _captions = value),
        ),
        if (_captions) ...[
          const Divider(height: 20),
          Text('نمط الترجمة', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: const ValueKey('create-caption-style'),
            initialValue: _styleId,
            isExpanded: true,
            items: captionStylePresets.map((style) => DropdownMenuItem(value: style.id, child: Text(style.name))).toList(),
            onChanged: _busy ? null : (value) {
              if (value != null) {
                setState(() => _styleId = value);
              }
            },
          ),
          const SizedBox(height: 14),
          Text('حركة الكلمات', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: const ValueKey('create-caption-animation'),
            initialValue: _animationId,
            isExpanded: true,
            items: captionAnimationPresets.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
            onChanged: _busy ? null : (value) {
              if (value != null) {
                setState(() => _animationId = value);
              }
            },
          ),
        ],
      ])),
      _Panel(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.center_focus_strong_rounded, color: scheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('تحليل التأطير التلقائي', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('يحلل CUTAWAN الإطارات ويضع خطة للتأطير عند توفر دليل بصري كافٍ. تعمل هذه الخطوة تلقائيًا حاليًا، ولا تعني التعرّف المؤكد على المتحدث النشط.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.45)),
        ])),
      ])),
      const SizedBox(height: 14),
      _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ملخص المشروع', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        _SummaryLine(label: 'عدد المقاطع', value: '$_clipCount'),
        _SummaryLine(label: 'المدة', value: _durationLabel),
        _SummaryLine(label: 'نسبة الأبعاد', value: _ratioLabel),
        _SummaryLine(label: 'جودة الإخراج', value: _resolution),
        _SummaryLine(label: 'الترجمة النصية', value: _captions ? 'مفعّلة' : 'متوقفة'),
        if (_captions) ...[
          _SummaryLine(label: 'نمط الترجمة', value: captionStylePresets.firstWhere((item) => item.id == _styleId).name),
          _SummaryLine(label: 'الحركة', value: captionAnimationPresets.firstWhere((item) => item.id == _animationId).name),
        ],
      ])),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          key: const ValueKey('create-step-back'),
          onPressed: _busy ? null : () => setState(() => _step = 0),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('العودة للفيديو'),
        )),
        const SizedBox(width: 10),
        Expanded(child: FilledButton.icon(
          key: const ValueKey('create-project-submit'),
          onPressed: _busy ? null : _createProject,
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.rocket_launch_rounded),
          label: Text(_busy ? 'جارٍ الحفظ…' : 'إنشاء المشروع'),
        )),
      ]),
      const SizedBox(height: 6),
      Text('بعد الحفظ ستنتقل إلى المراجعة لتشغيل التحليل ومتابعة المقاطع والتصدير.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
    ]);
  }

  Widget _stepIndicator(int number, String label, {required bool active, required bool complete}) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: active ? scheme.primary.withValues(alpha: 0.12) : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: active ? scheme.primary : scheme.outlineVariant),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: active || complete ? scheme.primary : scheme.surfaceContainerHighest,
          child: complete
              ? Icon(Icons.check_rounded, size: 16, color: scheme.onPrimary)
              : Text('$number', style: TextStyle(
                  color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
                  fontSize: 12, fontWeight: FontWeight.w800,
                )),
        ),
        const SizedBox(width: 8),
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: active ? scheme.primary : scheme.onSurfaceVariant, fontWeight: FontWeight.w800))),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SingleChildScrollView(
      key: const ValueKey('create-workflow-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 116),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.movie_creation_outlined, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('مشروع فيديو جديد', style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text('من المصدر إلى مقاطع تستحق المشاهدة.', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            ])),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _stepIndicator(1, 'الفيديو', active: _step == 0, complete: _source != null),
            const SizedBox(width: 9),
            _stepIndicator(2, 'إعدادات المقاطع', active: _step == 1, complete: false),
          ]),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey<int>(_step),
              child: _step == 0 ? _buildSourceStep(context) : _buildSettingsStep(context),
            ),
          ),
        ]),
      )),
    );
  }
}
