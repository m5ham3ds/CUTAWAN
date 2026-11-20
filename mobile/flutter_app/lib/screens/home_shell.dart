import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whisper_cpp_flutter_plus/whisper_cpp_flutter_plus.dart';

import '../domain/caption_catalog.dart';
import '../domain/clip_preferences.dart';
import '../domain/project_contract.dart';
import '../domain/transcript_contract.dart';
import '../domain/clip_candidate.dart';
import '../services/android_video_picker.dart';
import '../services/direct_video_downloader.dart';
import '../services/local_project_repository.dart';
import '../services/whisper_transcription_service.dart';
import '../services/qwen_model_manager.dart';
import '../services/candidate_discovery_service.dart';
import '../services/local_editorial_annotation_service.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.repository, this.storageUsageBytes});

  final LocalProjectRepository? repository;
  final Future<int> Function()? storageUsageBytes;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final LocalProjectRepository _repository;
  final ValueNotifier<List<CutawanProject>> _projects =
      ValueNotifier<List<CutawanProject>>([]);
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LocalProjectRepository();
    _reloadProjects();
  }

  Future<void> _reloadProjects() async {
    try {
      final projects = await _repository.listProjects();
      if (mounted) { _projects.value = projects; }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر قراءة سجل المشاريع: $error')),
        );
      }
    }
  }

  void _openModels() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ModelsPage()),
    );
  }

  @override
  void dispose() {
    _projects.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      CreatePage(repository: _repository, onProjectSaved: _reloadProjects),
      JobsPage(
        projects: _projects,
        repository: _repository,
        onProjectsChanged: _reloadProjects,
        storageUsageBytes: widget.storageUsageBytes,
      ),
      ReviewPage(
        projects: _projects,
        repository: _repository,
        onProjectsChanged: _reloadProjects,
      ),
      const CaptionStudioPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CUTAWAN', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2)),
            Text('MOBILE CLIPPING STUDIO', style: TextStyle(fontSize: 9, letterSpacing: 1.6)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'مركز النماذج',
            onPressed: _openModels,
            icon: const Icon(Icons.memory_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.add_link_outlined), selectedIcon: Icon(Icons.add_link), label: 'إدخال'),
          NavigationDestination(icon: Icon(Icons.pending_actions_outlined), selectedIcon: Icon(Icons.pending_actions), label: 'المهام'),
          NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library), label: 'المراجعة'),
          NavigationDestination(icon: Icon(Icons.subtitles_outlined), selectedIcon: Icon(Icons.subtitles), label: 'الاستوديو'),
        ],
      ),
    );
  }
}

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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        const _Eyebrow('مساحة العمل  /  مشروع جديد'),
        const SizedBox(height: 14),
        Text(
          'فيديو طويل يدخل.\nمقاطع أقوى تخرج.',
          style: theme.textTheme.headlineMedium?.copyWith(
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'اختر المصدر، ثم اضبط عدد المقاطع والمدة والتكوين قبل التحليل.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 28),
        const _Eyebrow('01  /  مصدر الفيديو'),
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
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _isImporting ? null : _downloadDirectVideo,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('تنزيل رابط مباشر'),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _isImporting ? null : _importVideo,
              icon: _isImporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_outlined),
              label: Text(_isImporting ? 'جارٍ الاستيراد' : 'اختيار فيديو'),
            ),
          ],
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
        const _Eyebrow('02  /  إعدادات المقاطع'),
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
          Row(
            children: [
              Expanded(
                child: TextField(
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
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
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
                ),
              ),
            ],
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('إضافة الكابشن'),
          subtitle: const Text('تطبيق تصميم وحركة على الكلام'),
          value: _captions,
          onChanged: (value) => setState(() => _captions = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('تتبع المتحدث'),
          subtitle: const Text('إعداد محفوظ؛ يحتاج محرك الرؤية'),
          value: _speakerTracking,
          onChanged: (value) => setState(() => _speakerTracking = value),
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

class JobsPage extends StatelessWidget {
  const JobsPage({
    required this.projects,
    required this.repository,
    required this.onProjectsChanged,
    this.storageUsageBytes,
    super.key,
  });

  final ValueListenable<List<CutawanProject>> projects;
  final LocalProjectRepository repository;
  final Future<void> Function() onProjectsChanged;
  final Future<int> Function()? storageUsageBytes;

  DirectVideoDownloader _downloader() => DirectVideoDownloader(
        availableStorageBytes: AndroidVideoPicker.availableStorageBytes,
        inspectLocalFile: AndroidVideoPicker.inspectLocalFile,
      );

  Future<void> _cancel(BuildContext context, CutawanProject project) async {
    try {
      await repository.cancelJob(project.id);
      await onProjectsChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء سجل المهمة وحفظ الحالة.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر إلغاء المهمة: $error')),
        );
      }
    }
  }

  Future<void> _deleteProject(
    BuildContext context,
    CutawanProject project,
  ) async {
    final isDownloadedFile = Uri.tryParse(project.source.uri)?.scheme == 'file';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المشروع'),
        content: Text(
          isDownloadedFile
              ? 'سيُحذف المشروع ونسخة الفيديو التي نزّلها Cutawan من مساحة التطبيق. لا يمكن التراجع عن ذلك.'
              : 'سيُحذف سجل المشروع فقط. ملفك الأصلي في مزود الملفات لن يتغير.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) { return; }

    try {
      if (isDownloadedFile) {
        await _downloader().deleteDownloadedVideo(project.source.uri);
      }
      if (Uri.tryParse(project.source.uri)?.scheme == 'content') {
        final sourceIsStillUsed = projects.value.any(
          (item) => item.id != project.id && item.source.uri == project.source.uri,
        );
        if (!sourceIsStillUsed) {
          await AndroidVideoPicker.releasePersistedPermission(project.source.uri);
        }
      }
      await repository.delete(project.id);
      await onProjectsChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف سجل المشروع من الجهاز.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر حذف المشروع: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CutawanProject>>(
      valueListenable: projects,
      builder: (context, items, _) {
        final storageFuture =
            (storageUsageBytes ?? _downloader().storageUsageBytes)();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            const _Eyebrow('مساحة العمل  /  سجل المعالجة'),
            const SizedBox(height: 14),
            Text(
              'المهام والمشاريع',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'هذه سجلات مشاريع محفوظة على الجهاز. لم يبدأ محرك التحليل الفعلي بعد.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<int>(
              future: storageFuture,
              builder: (context, snapshot) => Card(
                child: ListTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: const Text('مساحة تنزيلات Cutawan'),
                  subtitle: Text(
                    snapshot.hasData
                        ? _formatBytes(snapshot.data!)
                        : snapshot.hasError
                            ? 'تعذّر قراءة مساحة التخزين'
                            : 'جارٍ حساب المساحة…',
                  ),
                  trailing: IconButton(
                    tooltip: 'تحديث',
                    onPressed: onProjectsChanged,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const _EmptyState(
                icon: Icons.pending_actions_outlined,
                title: 'لا توجد مهام بعد',
                description:
                    'استورد فيديو من شاشة الإدخال ليظهر المشروع وسجل المهمة هنا.',
              )
            else
              for (final project in items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(project.source.displayName),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(_jobStatusLabel(project.job.status)),
                            if (project.job.canCancel)
                              TextButton.icon(
                                onPressed: () => _cancel(context, project),
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('إلغاء السجل'),
                              ),
                            TextButton.icon(
                              onPressed: () => _deleteProject(context, project),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('حذف المشروع'),
                            ),
                          ],
                        ),
                        Text(
                          'المهمة: ${project.job.id}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '${project.source.width} × ${project.source.height}  ·  ${_formatDuration(project.source.durationMs)}  ·  ${_formatBytes(project.source.sizeBytes)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class ReviewPage extends StatefulWidget {
  const ReviewPage({
    required this.projects,
    required this.repository,
    required this.onProjectsChanged,
    super.key,
  });

  final ValueListenable<List<CutawanProject>> projects;
  final LocalProjectRepository repository;
  final Future<void> Function() onProjectsChanged;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final Map<String, CutawanTranscript?> _transcripts = {};
  final Map<String, CandidateSet?> _candidateSets = {};
  final Set<String> _loadingArtifacts = {};
  String? _busyProjectId;
  String? _busyStage;
  String? _lastError;
  double? _progress;

  @override
  void initState() {
    super.initState();
    widget.projects.addListener(_handleProjectsChanged);
    _handleProjectsChanged();
  }

  @override
  void didUpdateWidget(covariant ReviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projects != widget.projects) {
      oldWidget.projects.removeListener(_handleProjectsChanged);
      widget.projects.addListener(_handleProjectsChanged);
      _handleProjectsChanged();
    }
  }

  @override
  void dispose() {
    widget.projects.removeListener(_handleProjectsChanged);
    super.dispose();
  }

  void _handleProjectsChanged() {
    for (final project in widget.projects.value) {
      _loadArtifacts(project.id);
    }
  }

  Future<void> _loadArtifacts(String projectId) async {
    if (_loadingArtifacts.contains(projectId)) { return; }
    _loadingArtifacts.add(projectId);
    try {
      final transcript = await widget.repository.loadTranscript(projectId);
      final candidates = await widget.repository.loadCandidates(projectId);
      if (!mounted) { return; }
      setState(() {
        _transcripts[projectId] = transcript;
        _candidateSets[projectId] = candidates;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _lastError = 'تعذّر تحميل نتائج التحليل: $error');
      }
    } finally {
      _loadingArtifacts.remove(projectId);
    }
  }

  Future<void> _verifySource(
    BuildContext context,
    CutawanProject project,
  ) async {
    try {
      final refreshed = await AndroidVideoPicker.inspectVideo(project.source.uri);
      final unchanged = project.source.hasSameMediaInfo(refreshed);
      await widget.repository.refreshSource(project.id, refreshed);
      await widget.onProjectsChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              unchanged
                  ? 'الملف ما زال متاحًا والبيانات تطابق السجل المحفوظ.'
                  : 'الملف متاح؛ تم تحديث بياناته المحفوظة بعد إعادة الفحص.',
            ),
          ),
        );
      }
    } on PlatformException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'تعذّر الوصول إلى الملف المحفوظ.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل فحص مصدر الفيديو: $error')),
        );
      }
    }
  }

  Future<void> _transcribe(CutawanProject project) async {
    if (_busyProjectId != null) return;
    setState(() {
      _busyProjectId = project.id;
      _busyStage = 'whisper';
      _lastError = null;
      _progress = 0;
    });
    try {
      final transcript = await WhisperTranscriptionService().transcribeVideo(
        sourceUri: project.source.uri,
        sourceDurationMs: project.source.durationMs,
        onProgress: (percent) {
          if (!mounted || _busyProjectId != project.id) return;
          setState(() => _progress = percent / 100);
        },
      );
      await widget.repository.saveTranscript(project.id, transcript);
      await _loadArtifacts(project.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              transcript.wordTimingReliable
                  ? 'اكتمل التفريغ المحلي وحُفظ توقيت الكلمات.'
                  : 'حُفظ النص، لكن توقيت الكلمات غير كافٍ لاكتشاف المقاطع.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) { setState(() => _lastError = 'فشل التفريغ المحلي: $error'); }
    } finally {
      if (mounted) {
        setState(() {
          _busyProjectId = null;
          _busyStage = null;
          _progress = null;
        });
      }
    }
  }

  Future<void> _discover(CutawanProject project) async {
    if (_busyProjectId != null) return;
    setState(() {
      _busyProjectId = project.id;
      _busyStage = 'candidates';
      _lastError = null;
      _progress = null;
    });
    var localModelUsed = false;
    try {
      final transcript = _transcripts[project.id] ??
          await widget.repository.loadTranscript(project.id);
      if (transcript == null) {
        throw StateError('نفّذ التفريغ المحلي أولاً.');
      }
      final discovery = const CandidateDiscoveryService();
      var candidateSet = discovery.discover(transcript, project.preferences);
      try {
        final modelFile = await QwenModelManager().findInstalled();
        if (modelFile != null) {
          candidateSet = await const LocalEditorialAnnotationService().annotate(
            candidateSet,
            modelPath: modelFile.path,
          );
          localModelUsed = candidateSet.candidates.any((item) => item.modelAnnotated);
        }
      } catch (error) {
        if (mounted) {
          setState(() => _lastError =
              'تم إنشاء المقاطع بالترتيب الحتمي، لكن تعذّر تشغيل نموذج Qwen المحلي: $error');
        }
      }
      await widget.repository.saveCandidates(project.id, candidateSet);
      await _loadArtifacts(project.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              candidateSet.candidates.isEmpty
                  ? 'لم يعثر التحليل على مقاطع مكتملة ضمن المدة المحددة؛ لم تتم إضافة مقاطع وهمية.'
                  : localModelUsed
                      ? 'تم حفظ ${candidateSet.candidates.length} اقتراحًا مع تعليقات النموذج المحلي.'
                      : 'تم حفظ ${candidateSet.candidates.length} اقتراحًا من أدلة التفريغ والصوت والصورة.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) { setState(() => _lastError = 'فشل اكتشاف المقاطع: $error'); }
    } finally {
      if (mounted) {
        setState(() {
          _busyProjectId = null;
          _busyStage = null;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CutawanProject>>(
      valueListenable: widget.projects,
      builder: (context, items, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          const _Eyebrow('مساحة العمل  /  التحليل والمراجعة'),
          const SizedBox(height: 14),
          Text(
            'مراجعة المشاريع',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'التفريغ واكتشاف المقاطع يعملان محليًا بعد تثبيت النماذج. درجات الاقتراحات مؤشرات تحريرية وليست ضمانًا للانتشار.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
          ),
          if (_lastError != null) ...[
            const SizedBox(height: 12),
            _StatusNote(text: _lastError!),
          ],
          const SizedBox(height: 24),
          if (items.isEmpty)
            const _EmptyState(
              icon: Icons.video_collection_outlined,
              title: 'لا توجد مقاطع للمراجعة',
              description: 'استورد فيديو من شاشة الإدخال ليظهر هنا.',
            )
          else
            for (final project in items) _projectCard(context, project),
        ],
      ),
    );
  }

  Widget _projectCard(BuildContext context, CutawanProject project) {
    final theme = Theme.of(context);
    final transcript = _transcripts[project.id];
    final candidateSet = _candidateSets[project.id];
    final isBusy = _busyProjectId == project.id;
    final isLoading = _loadingArtifacts.contains(project.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(project.source.displayName),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${project.source.width} × ${project.source.height}')),
                Chip(label: Text(_formatDuration(project.source.durationMs))),
                Chip(label: Text(_formatBytes(project.source.sizeBytes))),
              ],
            ),
            Text(
              'المصدر: ${project.source.mimeType}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: isBusy ? null : () => _verifySource(context, project),
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('إعادة فحص الوصول والبيانات'),
                ),
                FilledButton.tonalIcon(
                  onPressed: isBusy ? null : () => _transcribe(project),
                  icon: const Icon(Icons.graphic_eq),
                  label: const Text('تفريغ الكلام'),
                ),
                FilledButton.icon(
                  onPressed: isBusy || transcript == null ||
                          !transcript.wordTimingReliable
                      ? null
                      : () => _discover(project),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('اقتراح المقاطع'),
                ),
              ],
            ),
            if (isBusy) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 6),
              Text(
                _busyStage == 'whisper'
                    ? 'Whisper يعمل على الجهاز…'
                    : 'تحليل الحدود وترتيب المقاطع محليًا…',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (isLoading) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],
            if (transcript != null) ...[
              const Divider(height: 24),
              Text(
                'التفريغ • ${transcript.language} • ${transcript.words.length} كلمة',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                transcript.wordTimingReliable
                    ? 'توقيت الكلمات متاح ويمكن استخدامه لضبط حدود المقاطع.'
                    : 'النص محفوظ، لكن توقيت الكلمات غير موثوق؛ اكتشاف المقاطع معطّل لتجنب قصّ عشوائي.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (transcript.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  transcript.text.length > 420
                      ? '${transcript.text.substring(0, 420)}…'
                      : transcript.text,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
            if (candidateSet != null) ...[
              const Divider(height: 24),
              Text(
                'الاقتراحات • ${candidateSet.candidates.length}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'المحرك: ${candidateSet.rankingEngine} · لا توجد مقاطع مضافة لتلبية العدد المطلوب إذا لم توجد أدلة كافية.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (final candidate in candidateSet.candidates)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(candidate.title.isEmpty ? 'مقطع مقترح' : candidate.title),
                  subtitle: Text(
                    '${_formatDuration(candidate.startMs)}–${_formatDuration(candidate.endMs)} · ${candidate.durationMs ~/ 1000}s · ${candidate.score.toStringAsFixed(0)}/100'
                    '${candidate.modelAnnotated ? ' · وصف محلي' : ''}'
                    '\n${candidate.explanations.take(2).join(' · ')}',
                  ),
                  isThreeLine: true,
                  leading: const Icon(Icons.movie_creation_outlined),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

String _jobStatusLabel(ProjectJobStatus status) => switch (status) {
      ProjectJobStatus.prepared => 'المصدر محفوظ — جاهز للتحليل (لم يبدأ المحرك)',
      ProjectJobStatus.running => 'قيد التنفيذ',
      ProjectJobStatus.completed => 'مكتملة',
      ProjectJobStatus.cancelled => 'أُلغي سجل المهمة',
      ProjectJobStatus.failed => 'فشلت المهمة',
    };

String _formatDuration(int milliseconds) {
  final seconds = milliseconds ~/ 1000;
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}

String _formatBytes(int bytes) {
  if (bytes <= 0) { return 'الحجم غير متاح'; }
  if (bytes < 1024 * 1024) { return '${(bytes / 1024).toStringAsFixed(0)} KB'; }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class CaptionStudioPage extends StatefulWidget {
  const CaptionStudioPage({super.key});

  @override
  State<CaptionStudioPage> createState() => _CaptionStudioPageState();
}

class _CaptionStudioPageState extends State<CaptionStudioPage> {
  String _styleId = 'beast';
  String _animationId = 'word_pop';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedStyle = captionStylePresets.firstWhere((style) => style.id == _styleId);
    final selectedAnimation = captionAnimationPresets.firstWhere((item) => item.id == _animationId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        const _Eyebrow('مساحة العمل  /  Caption Studio'),
        const SizedBox(height: 14),
        Text('اصنع أسلوبك الخاص', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('اختر التصميم البصري والحركة كلًّا على حدة.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 24),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: const Color(0xFF211E19),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: selectedStyle.highlightBoxColor == null ? Colors.transparent : _colorFromHex(selectedStyle.highlightBoxColor!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'هذه لحظة تستحق أن تتحول إلى مقطع قصير',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _colorFromHex(selectedStyle.textColor),
                  fontSize: 20,
                  fontWeight: selectedStyle.bold ? FontWeight.bold : FontWeight.w600,
                  shadows: [Shadow(color: _colorFromHex(selectedStyle.outlineColor), blurRadius: selectedStyle.outlineWidth * 2)],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('معاينة شكلية للإعدادات فقط؛ لا تمثل حركة فعلية أو تصديرًا.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 26),
        const _Eyebrow('التصميم البصري'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: captionStylePresets.map((style) => ChoiceChip(
            label: Text(style.name),
            selected: _styleId == style.id,
            onSelected: (_) => setState(() => _styleId = style.id),
          )).toList(),
        ),
        const SizedBox(height: 24),
        const _Eyebrow('حركة النص'),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _animationId,
          isExpanded: true,
          items: captionAnimationPresets.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
          onChanged: (value) { if (value != null) setState(() => _animationId = value); },
        ),
        const SizedBox(height: 12),
        Text('${selectedStyle.name} · ${selectedAnimation.name}: ${selectedAnimation.description}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 20),
        const _StatusNote(text: 'إعدادات التصميم موجودة، لكن المعاينة الحركية ومحرر الخطوط والألوان والتصدير المتطابق ستربط بمحرك الوسائط لاحقًا.'),
      ],
    );
  }
}

class ModelsPage extends StatefulWidget {
  const ModelsPage({super.key});

  @override
  State<ModelsPage> createState() => _ModelsPageState();
}

class _ModelsPageState extends State<ModelsPage> {
  final WhisperModelManager _whisper = WhisperModelManager();
  final QwenModelManager _qwen = QwenModelManager();
  bool _loading = true;
  bool _busy = false;
  bool _whisperInstalled = false;
  bool _qwenInstalled = false;
  double? _progress;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshModels();
  }

  @override
  void dispose() {
    _whisper.close();
    super.dispose();
  }

  Future<void> _refreshModels() async {
    try {
      final whisperFile =
          await _whisper.findCatalogModel(WhisperModelCatalog.base);
      final qwenFile = await _qwen.findInstalled();
      if (!mounted) { return; }
      setState(() {
        _whisperInstalled = whisperFile != null;
        _qwenInstalled = qwenFile != null;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'تعذّر التحقق من سلامة أحد النماذج: $error';
          _loading = false;
        });
      }
    }
  }

  Future<bool> _hasFreeSpace(int requiredBytes) async {
    final available = await AndroidVideoPicker.availableStorageBytes();
    if (available >= requiredBytes) { return true; }
    if (mounted) {
      setState(() => _error =
          'المساحة الحرة غير كافية. المطلوب نحو ${_formatBytes(requiredBytes)}، والمتاح ${_formatBytes(available)}.');
    }
    return false;
  }

  Future<void> _downloadWhisper() async {
    if (_busy) { return; }
    final required = WhisperModelCatalog.base.approximateBytes +
        96 * 1024 * 1024;
    if (!await _hasFreeSpace(required)) { return; }
    setState(() {
      _busy = true;
      _progress = 0;
      _error = null;
    });
    try {
      await for (final update
          in _whisper.downloadCatalogModel(WhisperModelCatalog.base)) {
        if (mounted) { setState(() => _progress = update.fraction); }
      }
      await _refreshModels();
    } catch (error) {
      if (mounted) { setState(() => _error = 'فشل تنزيل/التحقق من Whisper: $error'); }
    } finally {
      if (mounted) { setState(() { _busy = false; _progress = null; }); }
    }
  }

  Future<void> _downloadQwen() async {
    if (_busy) { return; }
    if (!await _hasFreeSpace(QwenModelManager.minimumFreeBytes)) { return; }
    setState(() {
      _busy = true;
      _progress = 0;
      _error = null;
    });
    try {
      await _qwen.download(onProgress: (update) {
        if (mounted) { setState(() => _progress = update.fraction); }
      });
      await _refreshModels();
    } catch (error) {
      if (mounted) { setState(() => _error = 'فشل تنزيل/التحقق من Qwen: $error'); }
    } finally {
      if (mounted) { setState(() { _busy = false; _progress = null; }); }
    }
  }

  Future<void> _deleteWhisper() async {
    if (_busy) { return; }
    try {
      final directory = await _whisper.directory;
      final model = await _whisper.find(WhisperModelCatalog.base.fileName);
      if (model != null) { await model.delete(); }
      if (mounted) { setState(() => _whisperInstalled = false); }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حذف ملف Whisper من ${directory.path}.')),
        );
      }
    } catch (error) {
      if (mounted) { setState(() => _error = 'تعذّر حذف نموذج Whisper: $error'); }
    }
  }

  Future<void> _deleteQwen() async {
    if (_busy) { return; }
    try {
      await _qwen.deleteInstalled();
      if (mounted) { setState(() => _qwenInstalled = false); }
    } catch (error) {
      if (mounted) { setState(() => _error = 'تعذّر حذف نموذج Qwen: $error'); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('مركز النماذج المحلية')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'نماذج الذكاء الاصطناعي',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'تُنزل النماذج عند اختيارك فقط، وتُحفظ في مساحة التطبيق. تُتحقق بصمة SHA-256 قبل إتاحتها للمحركات.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _StatusNote(text: _error!),
          ],
          if (_busy) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 6),
            Text(
              _progress == null
                  ? 'جارٍ تجهيز النموذج…'
                  : 'اكتمل ${(_progress! * 100).round()}%',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 20),
          _modelCard(
            context,
            title: 'Whisper Base متعدد اللغات',
            description:
                'تفريغ محلي للعربية والإنجليزية مع توقيتات الكلمات. الحجم التقريبي 148 MB؛ المحرك يعمل بوضع CPU على ARM64.',
            metadata: 'whisper.cpp · مرجع نموذج مثبت · ملف الأوزان لا يُضمّن في APK',
            installed: _whisperInstalled,
            onInstall: _downloadWhisper,
            onRemove: _deleteWhisper,
          ),
          const SizedBox(height: 12),
          _modelCard(
            context,
            title: 'Qwen2.5-0.5B-Instruct Q4_K_M',
            description:
                'نموذج GGUF محلي لتعليقات تحريرية على المقاطع الموجودة. الحجم 491.4 MB تقريبًا؛ CPU ونافذة سياق صغيرة لتقليل الذاكرة.',
            metadata: 'llama.cpp · Qwen · Apache-2.0 · لا يغيّر توقيت المقاطع أو درجاتها',
            installed: _qwenInstalled,
            onInstall: _downloadQwen,
            onRemove: _deleteQwen,
          ),
          const SizedBox(height: 16),
          const _StatusNote(
            text: 'كشف المشاهد هنا يعتمد على تغيّر الإطارات، وليس كشف الوجوه أو فهم المشهد. لا يوجد إرسال سحابي للتفريغ أو الفيديو. يلزم اختبار الأداء والحرارة على جهاز فعلي قبل اعتماد جودة الإنتاج.',
          ),
          if (_loading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          TextButton.icon(
            onPressed: _busy ? null : _refreshModels,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة فحص النماذج'),
          ),
        ],
      ),
    );
  }

  Widget _modelCard(
    BuildContext context, {
    required String title,
    required String description,
    required String metadata,
    required bool installed,
    required Future<void> Function() onInstall,
    required Future<void> Function() onRemove,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.memory_outlined)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Chip(
                  label: Text(installed ? 'متحقق' : 'غير مثبت'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 6),
            Text(
              metadata,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : installed ? null : onInstall,
                  icon: const Icon(Icons.download_outlined),
                  label: Text(installed ? 'مثبت' : 'تنزيل والتحقق'),
                ),
                if (installed)
                  TextButton.icon(
                    onPressed: _busy ? null : onRemove,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('إزالة'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      );
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}

class _StatusNote extends StatelessWidget {
  const _StatusNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, size: 18, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45))),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.description});
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 10),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 52, color: theme.colorScheme.secondary),
        const SizedBox(height: 16),
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(description, textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5)),
      ]),
    );
  }
}

Color _colorFromHex(String hex) {
  final value = hex.replaceFirst('#', '');
  final parsed = int.tryParse(value, radix: 16) ?? 0xFFFFFF;
  return Color(0xFF000000 | parsed);
}
