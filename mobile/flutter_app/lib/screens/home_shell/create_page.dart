part of '../home_shell.dart';

class CreatePage extends StatefulWidget {
  const CreatePage({
    required this.repository,
    required this.onProjectSaved,
    super.key,
  });

  final LocalProjectRepository repository;
  final Future<void> Function() onProjectSaved;

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  final _urlController = TextEditingController();
  final _minimumSecondsController = TextEditingController(text: '15');
  final _maximumSecondsController = TextEditingController(text: '90');
  int _clipCount = 10;
  ClipDurationMode _duration = ClipDurationMode.automatic;
  ClipAspectRatio _ratio = ClipAspectRatio.portrait916;
  int _customMinimumSeconds = 15;
  int _customMaximumSeconds = 90;
  String _resolution = '1080p';
  String _captionStyleId = 'karaoke';
  String _captionAnimationId = 'word_pop';
  bool _captions = true;
  bool _speakerTracking = true;
  bool _isImporting = false;
  DownloadCancellation? _downloadCancellation;
  VideoDownloadProgress? _downloadProgress;
  DateTime _lastProgressUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _downloadCancellation?.cancel();
    _urlController.dispose();
    _minimumSecondsController.dispose();
    _maximumSecondsController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) { return; }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  ClipPreferences _currentPreferences() {
    final minimumSeconds = _duration == ClipDurationMode.custom
        ? int.tryParse(_minimumSecondsController.text.trim())
        : _customMinimumSeconds;
    final maximumSeconds = _duration == ClipDurationMode.custom
        ? int.tryParse(_maximumSecondsController.text.trim())
        : _customMaximumSeconds;
    if (minimumSeconds == null || maximumSeconds == null) {
      throw const FormatException('أدخل حدّي المدة المخصصة كأرقام صحيحة.');
    }
    final preferences = ClipPreferences(
      requestedClipCount: _clipCount,
      durationMode: _duration,
      customMinimumSeconds: minimumSeconds,
      customMaximumSeconds: maximumSeconds,
      aspectRatio: _ratio,
      resolution: _resolution,
      captionsEnabled: _captions,
      speakerTrackingEnabled: _speakerTracking,
      captionStyleId: _captionStyleId,
      captionAnimationId: _captionAnimationId,
    );
    final validationError = preferences.validate();
    if (validationError != null) { throw FormatException(validationError); }
    return preferences;
  }

  Future<void> _importVideo() async {
    if (_isImporting) { return; }
    setState(() => _isImporting = true);
    try {
      final preferences = _currentPreferences();
      final source = await AndroidVideoPicker.pickVideo();
      if (!mounted) {
        if (source != null) {
          await AndroidVideoPicker.releasePersistedPermission(source.uri);
        }
        return;
      }
      if (source == null) {
        _showMessage('تم إلغاء اختيار الفيديو.');
        return;
      }

      final project = CutawanProject.create(
        source: source,
        preferences: preferences,
      );
      await widget.repository.save(project);
      await widget.onProjectSaved();
      _showMessage('تم استيراد الفيديو وحفظ المشروع محليًا.');
    } on PlatformException catch (error) {
      _showMessage(error.message ?? 'تعذّر استيراد الفيديو من Android.');
    } on FormatException catch (error) {
      _showMessage('بيانات الفيديو غير صالحة: ${error.message}');
    } catch (error) {
      _showMessage('فشل حفظ المشروع: $error');
    } finally {
      if (mounted) { setState(() => _isImporting = false); }
    }
  }

  Future<void> _downloadDirectVideo() async {
    if (_isImporting) { return; }
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showMessage('أدخل رابط ملف فيديو مباشر أولًا.');
      return;
    }

    late final ClipPreferences preferences;
    try {
      preferences = _currentPreferences();
    } on FormatException catch (error) {
      _showMessage(error.message);
      return;
    }

    final cancellation = DownloadCancellation();
    setState(() {
      _isImporting = true;
      _downloadCancellation = cancellation;
      _downloadProgress = null;
    });

    try {
      final downloader = DirectVideoDownloader(
        availableStorageBytes: AndroidVideoPicker.availableStorageBytes,
        inspectLocalFile: AndroidVideoPicker.inspectLocalFile,
      );
      final source = await downloader.download(
        url,
        cancellation: cancellation,
        onProgress: (progress) {
          final now = DateTime.now();
          if (now.difference(_lastProgressUpdate).inMilliseconds < 180 &&
              progress.fraction != 1) {
            return;
          }
          _lastProgressUpdate = now;
          if (mounted) { setState(() => _downloadProgress = progress); }
        },
      );
      if (!mounted) {
        await downloader.deleteDownloadedVideo(source.uri);
        return;
      }
      final project = CutawanProject.create(
        source: source,
        preferences: preferences,
      );
      try {
        await widget.repository.save(project);
      } catch (_) {
        await downloader.deleteDownloadedVideo(source.uri);
        rethrow;
      }
      await widget.onProjectSaved();
      _urlController.clear();
      _showMessage('اكتمل التنزيل، وفُحص الفيديو، وحُفظ المشروع محليًا.');
    } on VideoDownloadCancelled {
      _showMessage('أُلغي التنزيل وحُذفت الأجزاء المؤقتة.');
    } on PlatformException catch (error) {
      _showMessage(error.message ?? 'تعذّر الوصول إلى خدمات تخزين Android.');
    } catch (error) {
      _showMessage('تعذّر تنزيل الفيديو: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _downloadCancellation = null;
          _downloadProgress = null;
        });
      }
    }
  }

  void _cancelDownload() {
    _downloadCancellation?.cancel();
  }

  String get _durationLabel => switch (_duration) {
        ClipDurationMode.automatic => 'تلقائي حسب اكتمال اللحظة',
        ClipDurationMode.seconds15To30 => '15–30 ثانية',
        ClipDurationMode.seconds30To45 => '30–45 ثانية',
        ClipDurationMode.seconds30To60 => '30–60 ثانية',
        ClipDurationMode.seconds60To90 => '60–90 ثانية',
        ClipDurationMode.custom => 'مدة مخصصة',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 32),
      children: [
        const _Eyebrow('مساحة العمل  /  مشروع جديد', icon: Icons.auto_awesome_rounded),
        const SizedBox(height: 14),
        Text(
          'من المصدر إلى\nمقاطع تستحق المشاهدة.',
          style: theme.textTheme.headlineMedium?.copyWith(
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'ارفع الفيديو، حدّد أسلوب القصّ، واترك مساحة العمل ترتّب خطوات المعالجة.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 20),
        _Panel(
          accent: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              return Row(children: [
                Container(
                  width: compact ? 34 : 46,
                  height: compact ? 34 : 46,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(Icons.movie_creation_outlined, color: theme.colorScheme.primary),
                ),
                SizedBox(width: compact ? 5 : 13),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مساحة إنشاء جديدة', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 3),
                    Text(
                      'إعداداتك محفوظة داخل المشروع ويمكن تعديلها قبل المعالجة.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: compact ? 9 : null,
                      ),
                      maxLines: compact ? 2 : null,
                      overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
                    ),
                  ],
                )),
                if (!compact) Icon(Icons.arrow_back_rounded, color: theme.colorScheme.primary),
              ]);
            },
          ),
        ),
        const SizedBox(height: 24),
        const _Eyebrow('01  /  مصدر الفيديو', icon: Icons.video_file_outlined),
        const SizedBox(height: 8),
        TextField(
          controller: _urlController,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'رابط مباشر لملف MP4 / MOV / WebM',
            prefixIcon: Icon(Icons.link),
          ),
          onSubmitted: (_) => _downloadDirectVideo(),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 390;
            final downloadButton = FilledButton.icon(
              onPressed: _isImporting ? null : _downloadDirectVideo,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('تنزيل رابط مباشر'),
            );
            final importButton = OutlinedButton.icon(
              onPressed: _isImporting ? null : _importVideo,
              icon: _isImporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_outlined),
              label: Text(_isImporting ? 'جارٍ الاستيراد' : 'اختيار فيديو'),
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  downloadButton,
                  const SizedBox(height: 9),
                  SizedBox(width: double.infinity, child: importButton),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: downloadButton),
                const SizedBox(width: 10),
                importButton,
              ],
            );
          },
        ),
        if (_isImporting && _downloadProgress != null) ...[
          const SizedBox(height: 14),
          LinearProgressIndicator(value: _downloadProgress!.fraction),
          const SizedBox(height: 6),
          Text(
            _downloadProgress!.totalBytes == null
                ? 'تم تنزيل ${_formatBytes(_downloadProgress!.receivedBytes)}'
                : '${_formatBytes(_downloadProgress!.receivedBytes)} من ${_formatBytes(_downloadProgress!.totalBytes!)}',
            style: theme.textTheme.bodySmall,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _cancelDownload,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('إلغاء التنزيل'),
            ),
          ),
        ],
        const SizedBox(height: 9),
        Text(
          'يدعم تنزيل روابط HTTP/HTTPS المباشرة لملفات الفيديو فقط. روابط YouTube والمنصات الاجتماعية التي تتطلب تجاوز قيود أو DRM غير مدعومة. ويمكنك اختيار ملف محلي عبر منتقي Android.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 30),
        const Divider(),
        const SizedBox(height: 18),
        const _Eyebrow('02  /  إعدادات المقاطع', icon: Icons.tune_rounded),
        const SizedBox(height: 14),
        Text('عدد المقاطع', style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [5, 10, 15, 20]
              .map((value) => ChoiceChip(
                    label: Text('$value'),
                    selected: _clipCount == value,
                    onSelected: (_) => setState(() => _clipCount = value),
                  ))
              .toList(),
        ),
        const SizedBox(height: 22),
        Text('المدة المستهدفة', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<ClipDurationMode>(
          initialValue: _duration,
          isExpanded: true,
          items: ClipDurationMode.values
              .map((mode) => DropdownMenuItem(
                    value: mode,
                    child: Text(switch (mode) {
                      ClipDurationMode.automatic => 'تلقائي حسب اكتمال اللحظة',
                      ClipDurationMode.seconds15To30 => '15–30 ثانية',
                      ClipDurationMode.seconds30To45 => '30–45 ثانية',
                      ClipDurationMode.seconds30To60 => '30–60 ثانية',
                      ClipDurationMode.seconds60To90 => '60–90 ثانية',
                      ClipDurationMode.custom => 'مدة مخصصة',
                    }),
                  ))
              .toList(),
          onChanged: (value) {
            if (value != null) { setState(() => _duration = value); }
          },
        ),
        if (_duration == ClipDurationMode.custom) ...[
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final minimumField = TextField(
                controller: _minimumSecondsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'أقل مدة (ثانية)',
                ),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null) {
                    setState(() => _customMinimumSeconds = parsed);
                  }
                },
              );
              final maximumField = TextField(
                controller: _maximumSecondsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'أقصى مدة (ثانية)',
                ),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null) {
                    setState(() => _customMaximumSeconds = parsed);
                  }
                },
              );
              if (constraints.maxWidth < 390) {
                return Column(
                  children: [
                    minimumField,
                    const SizedBox(height: 10),
                    maximumField,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: minimumField),
                  const SizedBox(width: 12),
                  Expanded(child: maximumField),
                ],
              );
            },
          ),
        ],
        const SizedBox(height: 22),
        Text('نسبة الأبعاد', style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: ClipAspectRatio.values.map((ratio) {
            final label = switch (ratio) {
              ClipAspectRatio.portrait916 => '9:16',
              ClipAspectRatio.square11 => '1:1',
              ClipAspectRatio.landscape169 => '16:9',
              ClipAspectRatio.original => 'الأصلية',
            };
            return ChoiceChip(
              label: Text(label),
              selected: _ratio == ratio,
              onSelected: (_) => setState(() => _ratio = ratio),
            );
          }).toList(),
        ),
        const SizedBox(height: 22),
        Text('جودة التصدير', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _resolution,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: '720p', child: Text('720p')),
            DropdownMenuItem(value: '1080p', child: Text('1080p')),
          ],
          onChanged: (value) {
            if (value != null) { setState(() => _resolution = value); }
          },
        ),
        const SizedBox(height: 14),
        _Panel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.closed_caption_outlined),
            title: const Text('كابشن ذكي'),
            subtitle: const Text('تفريغ الكلام وتطبيق النمط والحركة المختارين.'),
            value: _captions,
            onChanged: (value) => setState(() => _captions = value),
          ),
        ),
        _Panel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.face_retouching_natural_outlined),
            title: const Text('تتبع الوجه والتأطير'),
            subtitle: const Text('يُحفظ كخيار للمشروع؛ التنفيذ الكامل يتطلب محرك الرؤية.'),
            value: _speakerTracking,
            onChanged: (value) => setState(() => _speakerTracking = value),
          ),
        ),
        if (_captions) ...[
          const SizedBox(height: 12),
          Text('تصميم الكابشن', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _captionStyleId,
            isExpanded: true,
            items: captionStylePresets
                .map((style) => DropdownMenuItem(
                      value: style.id,
                      child: Text(style.name),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) { setState(() => _captionStyleId = value); }
            },
          ),
          const SizedBox(height: 16),
          Text('حركة النص', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _captionAnimationId,
            isExpanded: true,
            items: captionAnimationPresets
                .map((animation) => DropdownMenuItem(
                      value: animation.id,
                      child: Text(animation.name),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) { setState(() => _captionAnimationId = value); }
            },
          ),
        ],
        Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('خيارات متقدمة', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('المدة والتكوين وسلوك اختيار المقاطع'),
            children: const [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.tune),
                title: Text('التفاصيل الإضافية'),
                subtitle: Text(
                  'ستضاف حدود المدة المخصصة وترتيب المقاطع ومستوى إزالة التكرار في مرحلة إعداد المحرك.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
        _SummaryLine(label: 'عدد المقاطع', value: '$_clipCount'),
        _SummaryLine(label: 'المدة', value: _durationLabel),
        _SummaryLine(label: 'الجودة', value: _resolution),
        if (_captions) ...[
          _SummaryLine(
            label: 'تصميم الكابشن',
            value: captionStylePresets
                .firstWhere((style) => style.id == _captionStyleId)
                .name,
          ),
          _SummaryLine(
            label: 'حركة النص',
            value: captionAnimationPresets
                .firstWhere((animation) => animation.id == _captionAnimationId)
                .name,
          ),
        ],
        _SummaryLine(
          label: 'التكوين',
          value: switch (_ratio) {
            ClipAspectRatio.portrait916 => '9:16',
            ClipAspectRatio.square11 => '1:1',
            ClipAspectRatio.landscape169 => '16:9',
            ClipAspectRatio.original => 'الأصلية',
          },
        ),
        _SummaryLine(label: 'الكابشن', value: _captions ? 'مفعّل' : 'متوقف'),
        _SummaryLine(
          label: 'تتبع المتحدث',
          value: _speakerTracking ? 'محدد' : 'متوقف',
        ),
        const SizedBox(height: 18),
        const _StatusNote(
          text:
              'استيراد الفيديو وحفظ بياناته محليًا متاحان الآن. تحليل الروابط والتفريغ الصوتي وإنشاء المقاطع لم تُربط بمحركاتها بعد.',
        ),
      ],
    );
  }
}
