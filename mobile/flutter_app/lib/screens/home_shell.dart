import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/caption_catalog.dart';
import '../domain/clip_preferences.dart';
import '../domain/project_contract.dart';
import '../services/android_video_picker.dart';
import '../services/direct_video_downloader.dart';
import '../services/direct_video_downloader.dart';
import '../services/local_project_repository.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.repository});

  final LocalProjectRepository? repository;

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
      if (mounted) _projects.value = projects;
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
  int _clipCount = 10;
  ClipDurationMode _duration = ClipDurationMode.automatic;
  ClipAspectRatio _ratio = ClipAspectRatio.portrait916;
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
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _importVideo() async {
    if (_isImporting) return;
    setState(() => _isImporting = true);
    try {
      final source = await AndroidVideoPicker.pickVideo();
      if (!mounted) return;
      if (source == null) {
        _showMessage('تم إلغاء اختيار الفيديو.');
        return;
      }

      final preferences = ClipPreferences(
        requestedClipCount: _clipCount,
        durationMode: _duration,
        aspectRatio: _ratio,
        captionsEnabled: _captions,
        speakerTrackingEnabled: _speakerTracking,
      );
      final validationError = preferences.validate();
      if (validationError != null) {
        _showMessage(validationError);
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
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _downloadDirectVideo() async {
    if (_isImporting) return;
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showMessage('أدخل رابط ملف فيديو مباشر أولًا.');
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
          if (mounted) setState(() => _downloadProgress = progress);
        },
      );
      if (!mounted) return;
      final project = CutawanProject.create(
        source: source,
        preferences: ClipPreferences(
          requestedClipCount: _clipCount,
          durationMode: _duration,
          aspectRatio: _ratio,
          captionsEnabled: _captions,
          speakerTrackingEnabled: _speakerTracking,
        ),
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
            if (value != null) setState(() => _duration = value);
          },
        ),
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
    super.key,
  });

  final ValueListenable<List<CutawanProject>> projects;
  final LocalProjectRepository repository;
  final Future<void> Function() onProjectsChanged;

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
    if (confirmed != true) return;

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
        final storageFuture = _downloader().storageUsageBytes();
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

class ReviewPage extends StatelessWidget {
  const ReviewPage({
    required this.projects,
    required this.repository,
    required this.onProjectsChanged,
    super.key,
  });

  final ValueListenable<List<CutawanProject>> projects;
  final LocalProjectRepository repository;
  final Future<void> Function() onProjectsChanged;

  Future<void> _verifySource(
    BuildContext context,
    CutawanProject project,
  ) async {
    try {
      final refreshed = await AndroidVideoPicker.inspectVideo(project.source.uri);
      final unchanged = project.source.hasSameMediaInfo(refreshed);
      await repository.refreshSource(project.id, refreshed);
      await onProjectsChanged();
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CutawanProject>>(
      valueListenable: projects,
      builder: (context, items, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          const _Eyebrow('مساحة العمل  /  اختيار النتائج'),
          const SizedBox(height: 14),
          Text(
            'مراجعة المشاريع',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'راجع ملف المصدر وبياناته المحفوظة، ثم أعد فحص صلاحية الوصول إلى الملف.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 24),
          if (items.isEmpty)
            const _EmptyState(
              icon: Icons.video_collection_outlined,
              title: 'لا توجد مقاطع للمراجعة',
              description:
                  'بعد استيراد الفيديو سيظهر هنا مشروعه وبيانات المصدر. لا توجد مقاطع مولدة لأن محرك التحليل لم يُربط بعد.',
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
                      const SizedBox(height: 6),
                      Text(
                        'المصدر: ${project.source.mimeType}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _verifySource(context, project),
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('إعادة فحص الوصول والبيانات'),
                      ),
                    ],
                  ),
                ),
              ),
        ],
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
  if (bytes <= 0) return 'الحجم غير متاح';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
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

class ModelsPage extends StatelessWidget {
  const ModelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final models = [
      ('Whisper.cpp', 'تحويل الكلام إلى نص وتوقيت الكلمات', Icons.graphic_eq),
      ('llama.cpp + GGUF', 'تحليل النص وترتيب اللحظات', Icons.psychology_alt_outlined),
      ('ONNX Runtime', 'كشف الوجوه والمتحدث النشط وVAD', Icons.face_retouching_natural),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('مركز النماذج المحلية')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('نماذج الذكاء الاصطناعي', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text('لن تُحمّل النماذج تلقائيًا. ستعرض هذه الشاشة التوافق والحجم والترخيص والمساحة قبل التنزيل.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5)),
          const SizedBox(height: 20),
          for (final model in models)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: CircleAvatar(child: Icon(model.$3)),
                title: Text(model.$1),
                subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text(model.$2)),
                trailing: const Chip(label: Text('قيد الربط')),
              ),
            ),
          const SizedBox(height: 12),
          const _StatusNote(text: 'لم يتم تثبيت أو تنزيل محركات الذكاء الاصطناعي في هذا الإصدار.'),
        ],
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
