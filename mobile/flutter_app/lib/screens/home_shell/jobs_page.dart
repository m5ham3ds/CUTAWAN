part of '../home_shell.dart';

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
