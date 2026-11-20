part of '../home_shell.dart';

class JobsPage extends StatelessWidget {
  const JobsPage({
    required this.projects,
    required this.repository,
    required this.onProjectsChanged,
    required this.onOpenReview,
    this.storageUsageBytes,
    super.key,
  });

  final ValueListenable<List<CutawanProject>> projects;
  final LocalProjectRepository repository;
  final Future<void> Function() onProjectsChanged;
  final VoidCallback onOpenReview;
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
            const _Eyebrow('مساحة العمل  /  سجل المعالجة', icon: Icons.grid_view_rounded),
            const SizedBox(height: 14),
            Text(
              'مساحة مشاريعك',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'تابع حالة كل مشروع، مساحة الملفات، وما يحتاج إلى خطوة تالية.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: _MetricCard(label: 'كل المشاريع', value: '${items.length}', icon: Icons.video_library_outlined)),
              const SizedBox(width: 9),
              Expanded(child: _MetricCard(label: 'مكتملة', value: '${items.where((p) => p.job.status == ProjectJobStatus.completed).length}', icon: Icons.check_circle_outline_rounded, tint: Theme.of(context).colorScheme.secondary)),
              const SizedBox(width: 9),
              Expanded(child: _MetricCard(label: 'قيد العمل', value: '${items.where((p) => p.job.status == ProjectJobStatus.running).length}', icon: Icons.pending_outlined)),
            ]),
            const SizedBox(height: 20),
            FutureBuilder<int>(
              future: storageFuture,
              builder: (context, snapshot) => Card(
                child: ListTile(
                  leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)), child: Icon(Icons.storage_outlined, color: Theme.of(context).colorScheme.primary)),
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
              _EmptyState(
                icon: Icons.video_collection_outlined,
                title: 'مساحة العمل فارغة حالياً',
                description: 'ابدأ باستيراد فيديو من شاشة الإنشاء. سيظهر كل مشروع هنا مع حالة المعالجة ومساحة التخزين.',
                action: 'إنشاء مشروع',
                onAction: onOpenReview,
              )
            else
              for (final project in items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(17),
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
                        Text(project.source.displayName, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _StatusBadge(label: _jobStatusLabel(project.job.status), status: project.job.status),
                            Chip(label: Text(project.job.stage)),
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
                        const SizedBox(height: 8),
                        const SizedBox(height: 7),
                        LinearProgressIndicator(
                          borderRadius: BorderRadius.circular(99),
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          value: project.job.status == ProjectJobStatus.prepared ? 0 : project.job.progress,
                          minHeight: 5,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(project.job.progress * 100).round()}% مكتمل · ${project.job.stage}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            onPressed: onOpenReview,
                            icon: const Icon(Icons.video_library_outlined),
                            label: const Text('فتح المراجعة والتشغيل أو الاستئناف'),
                          ),
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
