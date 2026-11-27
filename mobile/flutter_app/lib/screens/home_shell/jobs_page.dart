import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/project_contract.dart';
import '../../services/android_video_picker.dart';
import '../../services/direct_video_downloader.dart';
import '../../services/local_project_repository.dart';
import '../../services/processing_job_service.dart';
import 'shared_ui_primitives.dart';
enum _JobsFilter { all, active, completed, attention }

class JobsPage extends StatefulWidget {
  const JobsPage({
    required this.projects,
    required this.repository,
    required this.onProjectsChanged,
    required this.onOpenReview,
    required this.onOpenCreate,
    this.storageUsageBytes,
    super.key,
  });

  final ValueListenable<List<CutawanProject>> projects;
  final LocalProjectRepository repository;
  final Future<void> Function() onProjectsChanged;
  final VoidCallback onOpenReview;
  final VoidCallback onOpenCreate;
  final Future<int> Function()? storageUsageBytes;

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _busyProjectIds = {};
  late Future<int> _storageFuture;
  _JobsFilter _filter = _JobsFilter.all;

  DirectVideoDownloader _downloader() => DirectVideoDownloader(
        availableStorageBytes: AndroidVideoPicker.availableStorageBytes,
        inspectLocalFile: AndroidVideoPicker.inspectLocalFile,
      );

  Future<int> _readStorageUsage() =>
      (widget.storageUsageBytes ?? _downloader().storageUsageBytes)();

  @override
  void initState() {
    super.initState();
    _storageFuture = _readStorageUsage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _storageFuture = _readStorageUsage());
    await widget.onProjectsChanged();
  }

  List<CutawanProject> _visibleProjects(List<CutawanProject> projects) {
    final query = _searchController.text.trim().toLowerCase();
    return projects.where((project) {
      final status = project.job.status;
      final matchesFilter = switch (_filter) {
        _JobsFilter.all => true,
        _JobsFilter.active =>
          status == ProjectJobStatus.prepared ||
              status == ProjectJobStatus.running,
        _JobsFilter.completed => status == ProjectJobStatus.completed,
        _JobsFilter.attention =>
          status == ProjectJobStatus.failed ||
              status == ProjectJobStatus.cancelled,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return project.title.toLowerCase().contains(query) ||
          project.source.displayName.toLowerCase().contains(query) ||
          project.job.stage.toLowerCase().contains(query) ||
          project.job.id.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  int _countForFilter(List<CutawanProject> projects, _JobsFilter filter) {
    return switch (filter) {
      _JobsFilter.all => projects.length,
      _JobsFilter.active => projects
          .where((item) =>
              item.job.status == ProjectJobStatus.prepared ||
              item.job.status == ProjectJobStatus.running)
          .length,
      _JobsFilter.completed => projects
          .where((item) => item.job.status == ProjectJobStatus.completed)
          .length,
      _JobsFilter.attention => projects
          .where((item) =>
              item.job.status == ProjectJobStatus.failed ||
              item.job.status == ProjectJobStatus.cancelled)
          .length,
    };
  }

  String _filterLabel(_JobsFilter filter) => switch (filter) {
        _JobsFilter.all => 'الكل',
        _JobsFilter.active => 'النشطة',
        _JobsFilter.completed => 'المكتملة',
        _JobsFilter.attention => 'تحتاج متابعة',
      };

  String _statusLabel(ProjectJobStatus status) => cutawanJobStatusLabel(status);

  String _stageLabel(String stage) {
    if (stage.startsWith('interrupted_after_process_death:')) {
      return 'توقف بعد إغلاق التطبيق';
    }
    if (stage.startsWith('failed_')) {
      return 'تعذّر في ${_stageLabel(stage.substring(7))}';
    }
    if (stage.startsWith('rendering_')) return 'إخراج المقاطع';
    return switch (stage) {
      'source_imported' => 'المصدر مستورد',
      'prepared' => 'جاهز',
      'queued' => 'في قائمة الانتظار',
      'inspecting' => 'فحص مصدر الفيديو',
      'transcribing' => 'تفريغ الكلام',
      'discovering' => 'اكتشاف المقاطع',
      'reframing' => 'تحليل التأطير',
      'captioning' => 'إعداد الترجمة',
      'rendering' => 'إخراج الفيديو',
      'validating' => 'التحقق من الملفات',
      'complete' => 'اكتملت المعالجة',
      'cancelled' || 'cancelled_by_user' => 'أوقفها المستخدم',
      'migrated' => 'مشروع محفوظ سابقاً',
      _ => stage.replaceAll('_', ' '),
    };
  }

  String _actionLabel(ProjectJobStatus status) => switch (status) {
        ProjectJobStatus.prepared => 'فتح المراجعة لبدء المعالجة',
        ProjectJobStatus.running => 'عرض المراجعة وحالة التنفيذ',
        ProjectJobStatus.completed => 'عرض النتائج',
        ProjectJobStatus.cancelled || ProjectJobStatus.failed =>
          'فتح المراجعة للاستئناف',
      };

  String _updatedLabel(DateTime dateTime) {
    final value = dateTime.toLocal();
    final date = '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    final time = '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
    return 'آخر تحديث $date · $time';
  }

  Future<void> _cancel(BuildContext context, CutawanProject project) async {
    if (_busyProjectIds.contains(project.id)) return;
    setState(() => _busyProjectIds.add(project.id));
    try {
      await widget.repository.cancelJob(project.id);
      final backgroundCancellationRequested =
          await ProcessingJobService.cancelBackgroundRenderForProject(project.id);
      await widget.onProjectsChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              backgroundCancellationRequested
                  ? 'تم حفظ الإيقاف وإرسال أمر إلغاء عامل الخلفية لهذا المشروع.'
                  : 'تم حفظ طلب الإيقاف؛ لم يتأكد الاتصال بعامل الخلفية، وستُراجع حالة المهمة عند العودة إلى التطبيق.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر إيقاف المهمة: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyProjectIds.remove(project.id));
    }
  }

  Future<void> _deleteProject(
    BuildContext context,
    CutawanProject project,
  ) async {
    if (_busyProjectIds.contains(project.id)) return;
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
    if (confirmed != true || !mounted) return;

    setState(() => _busyProjectIds.add(project.id));
    try {
      if (isDownloadedFile) {
        await _downloader().deleteDownloadedVideo(project.source.uri);
      }
      if (Uri.tryParse(project.source.uri)?.scheme == 'content') {
        final sourceIsStillUsed = widget.projects.value.any(
          (item) => item.id != project.id && item.source.uri == project.source.uri,
        );
        if (!sourceIsStillUsed) {
          await AndroidVideoPicker.releasePersistedPermission(project.source.uri);
        }
      }
      await widget.repository.delete(project.id);
      await widget.onProjectsChanged();
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
    } finally {
      if (mounted) setState(() => _busyProjectIds.remove(project.id));
    }
  }

  Widget _buildOverview(List<CutawanProject> items, BuildContext context) {
    final theme = Theme.of(context);
    final running = items
        .where((item) => item.job.status == ProjectJobStatus.running)
        .length;
    final ready = items
        .where((item) => item.job.status == ProjectJobStatus.prepared)
        .length;
    final completed = items
        .where((item) => item.job.status == ProjectJobStatus.completed)
        .length;
    final attention = items
        .where((item) =>
            item.job.status == ProjectJobStatus.failed ||
            item.job.status == ProjectJobStatus.cancelled)
        .length;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final columns = constraints.maxWidth < 390 ? 2 : 4;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: width,
              child: CutawanMetricCard(
                label: 'قيد التنفيذ',
                value: '$running',
                icon: Icons.play_circle_outline_rounded,
                tint: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(
              width: width,
              child: CutawanMetricCard(
                label: 'جاهزة',
                value: '$ready',
                icon: Icons.hourglass_empty_rounded,
                tint: theme.colorScheme.tertiary,
              ),
            ),
            SizedBox(
              width: width,
              child: CutawanMetricCard(
                label: 'مكتملة',
                value: '$completed',
                icon: Icons.check_circle_outline_rounded,
                tint: theme.colorScheme.secondary,
              ),
            ),
            SizedBox(
              width: width,
              child: CutawanMetricCard(
                label: 'تحتاج متابعة',
                value: '$attention',
                icon: Icons.error_outline_rounded,
                tint: theme.colorScheme.error,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilters(List<CutawanProject> items) {
    const filters = _JobsFilter.values;
    return Wrap(
      key: const ValueKey('jobs-status-filters'),
      spacing: 8,
      runSpacing: 8,
      children: filters.map((filter) {
        final selected = _filter == filter;
        return ChoiceChip(
          key: ValueKey('jobs-filter-${filter.name}'),
          selected: selected,
          onSelected: (_) => setState(() => _filter = filter),
          label: Text('${_filterLabel(filter)} · ${_countForFilter(items, filter)}'),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildStorageCard(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<int>(
      future: _storageFuture,
      builder: (context, snapshot) => Card(
        child: ListTile(
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.storage_outlined, color: theme.colorScheme.onSurfaceVariant),
          ),
          title: const Text('مساحة تنزيلات Cutawan'),
          subtitle: Text(
            snapshot.hasData
                ? formatCutawanBytes(snapshot.data!)
                : snapshot.hasError
                    ? 'تعذّر قراءة مساحة التخزين'
                    : 'جارٍ حساب المساحة…',
          ),
          trailing: IconButton(
            key: const ValueKey('jobs-refresh'),
            tooltip: 'تحديث المشاريع والمساحة',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, CutawanProject project) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busy = _busyProjectIds.contains(project.id);
    final progress = switch (project.job.status) {
      ProjectJobStatus.prepared => 0.0,
      ProjectJobStatus.completed => 1.0,
      _ => project.job.progress.clamp(0.0, 1.0).toDouble(),
    };
    final status = project.job.status;
    final progressLabel = status == ProjectJobStatus.prepared
        ? 'لم تبدأ المعالجة بعد'
        : '${(progress * 100).round()}% مكتمل';
    final running = status == ProjectJobStatus.running;
    final actionIcon = switch (status) {
      ProjectJobStatus.prepared => Icons.play_arrow_rounded,
      ProjectJobStatus.running => Icons.open_in_new_rounded,
      ProjectJobStatus.completed => Icons.video_library_outlined,
      ProjectJobStatus.cancelled || ProjectJobStatus.failed =>
        Icons.restart_alt_rounded,
    };

    return Card(
      key: ValueKey('job-card-${project.id}'),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        project.source.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                CutawanStatusBadge(
                  label: _statusLabel(status),
                  status: status,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        running
                            ? Icons.sync_rounded
                            : status == ProjectJobStatus.completed
                                ? Icons.check_circle_outline_rounded
                                : status == ProjectJobStatus.failed
                                    ? Icons.error_outline_rounded
                                    : status == ProjectJobStatus.cancelled
                                        ? Icons.pause_circle_outline_rounded
                                        : Icons.play_circle_outline_rounded,
                        size: 17,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          _stageLabel(project.job.stage),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        progressLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Semantics(
                    label: 'تقدم ${project.title}',
                    value: progressLabel,
                    child: LinearProgressIndicator(
                      borderRadius: BorderRadius.circular(99),
                      backgroundColor: scheme.surfaceContainerHighest,
                      value: progress,
                      color: scheme.onSurfaceVariant,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    status == ProjectJobStatus.running
                        ? 'يتم تحديث الحالة مع تقدم المعالجة.'
                        : status == ProjectJobStatus.failed
                            ? 'احتفظ التطبيق بالمرحلة السابقة؛ افتح المراجعة لمحاولة الاستئناف.'
                            : status == ProjectJobStatus.cancelled
                                ? 'يمكن العودة إلى المراجعة وتشغيل خط المعالجة مجدداً.'
                                : status == ProjectJobStatus.completed
                                    ? 'اكتملت المعالجة؛ افتح المراجعة لمشاهدة المقاطع المُخرجة.'
                                    : 'المشروع محفوظ وجاهز لبدء خط المعالجة من صفحة المراجعة.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (project.job.canCancel)
                  FilledButton.tonalIcon(
                    key: ValueKey('cancel-job-${project.id}'),
                    onPressed: busy ? null : () => _cancel(context, project),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(
                      busy
                          ? 'جارٍ الإيقاف…'
                          : running
                              ? 'إيقاف المعالجة'
                              : 'إلغاء المهمة',
                    ),
                  ),
                OutlinedButton.icon(
                  key: ValueKey('open-review-${project.id}'),
                  onPressed: busy ? null : widget.onOpenReview,
                  icon: Icon(actionIcon),
                  label: Text(_actionLabel(status)),
                ),
                IconButton.outlined(
                  key: ValueKey('delete-project-${project.id}'),
                  tooltip: 'حذف المشروع',
                  onPressed: busy || running ? null : () => _deleteProject(context, project),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const Divider(height: 22),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _JobMeta(
                  icon: Icons.timer_outlined,
                  label: formatCutawanDuration(project.source.durationMs),
                ),
                _JobMeta(
                  icon: Icons.high_quality_outlined,
                  label: '${project.source.width} × ${project.source.height}',
                ),
                _JobMeta(
                  icon: Icons.storage_outlined,
                  label: formatCutawanBytes(project.source.sizeBytes),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _updatedLabel(project.job.updatedAtUtc),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Tooltip(
                  message: 'معرّف المهمة: ${project.job.id}',
                  child: const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    semanticLabel: 'تفاصيل معرّف المهمة',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CutawanProject>>(
      valueListenable: widget.projects,
      builder: (context, items, _) {
        final visible = _visibleProjects(items);
        final theme = Theme.of(context);
        return ListView(
          key: const ValueKey('jobs-workspace-list'),
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 124),
          children: [
            const CutawanEyebrow(
              'مركز المهام',
              icon: Icons.grid_view_rounded,
            ),
            const SizedBox(height: 10),
            Text(
              'متابعة المعالجة',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'راقب كل مشروع، وافهم المرحلة الحالية، ثم افتح المراجعة للبدء أو الاستئناف.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _buildOverview(items, context),
            const SizedBox(height: 16),
            _buildStorageCard(context),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('jobs-search'),
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'ابحث باسم المشروع أو ملف الفيديو',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح البحث',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            _buildFilters(items),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'المشاريع ${visible.length} من ${items.length}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('تحديث'),
                ),
              ],
            ),
            if (items.isEmpty)
              CutawanEmptyState(
                icon: Icons.video_collection_outlined,
                title: 'لا توجد مهام بعد',
                description:
                    'أنشئ مشروعاً من صفحة الإنشاء؛ سيظهر هنا وتتابع حالته وخطوات معالجته.',
                action: 'إنشاء مشروع',
                onAction: widget.onOpenCreate,
              )
            else if (visible.isEmpty)
              CutawanPanel(
                child: Column(
                  children: [
                    const Icon(Icons.search_off_rounded, size: 30),
                    const SizedBox(height: 8),
                    const Text(
                      'لا توجد مشاريع تطابق عوامل التصفية الحالية.',
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _filter = _JobsFilter.all);
                      },
                      child: const Text('مسح البحث والتصفية'),
                    ),
                  ],
                ),
              )
            else
              for (final project in visible)
                _buildProjectCard(context, project),
          ],
        );
      },
    );
  }
}

class _JobMeta extends StatelessWidget {
  const _JobMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
