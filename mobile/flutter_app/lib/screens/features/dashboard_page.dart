import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

import '../../domain/project_contract.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    required this.projects,
    required this.onCreate,
    required this.onOpenJobs,
    required this.onOpenReview,
    required this.onOpenSettings,
    required this.onOpenProject,
    required this.storageUsageBytes,
    super.key,
  });

  final ValueListenable<List<CutawanProject>> projects;
  final VoidCallback onCreate;
  final VoidCallback onOpenJobs;
  final VoidCallback onOpenReview;
  final VoidCallback onOpenSettings;
  final ValueChanged<CutawanProject> onOpenProject;
  final Future<int> Function() storageUsageBytes;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width < 360 ? 14.0 : width < 600 ? 18.0 : 24.0;
    return ValueListenableBuilder<List<CutawanProject>>(
      valueListenable: projects,
      builder: (context, items, _) {
        final completed = items
            .where((p) => p.job.status == ProjectJobStatus.completed)
            .length;
        final running = items
            .where((p) => p.job.status == ProjectJobStatus.running)
            .length;
        final attention = items
            .where((p) =>
                p.job.status == ProjectJobStatus.failed ||
                p.job.status == ProjectJobStatus.cancelled)
            .length;
        final recent = items.take(3).toList(growable: false);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: ListView(
              key: const ValueKey('cutawan-dashboard-list'),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                30,
              ),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cutawanText(context, 'مساحة عملك')),
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(cutawanText(context, 'مرحباً بك في CUTAWAN')),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      key: const ValueKey('dashboard-settings'),
                      tooltip: 'الإعدادات',
                      onPressed: onOpenSettings,
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _DashboardHero(onCreate: onCreate),
                const SizedBox(height: 22),
                _DashboardSectionHeading(title: 'نظرة عامة'),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth < 350
                        ? 2
                        : constraints.maxWidth < 620
                            ? 3
                            : 4;
                    const gap = 9.0;
                    final cardWidth =
                        (constraints.maxWidth - gap * (columns - 1)) /
                            columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _DashboardMetric(
                            label: 'المشاريع',
                            value: items.length,
                            icon: Icons.video_library_outlined,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _DashboardMetric(
                            label: 'مكتملة',
                            value: completed,
                            icon: Icons.check_circle_outline_rounded,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _DashboardMetric(
                            label: 'قيد العمل',
                            value: running,
                            icon: Icons.pending_outlined,
                          ),
                        ),
                        if (attention > 0)
                          SizedBox(
                            width: cardWidth,
                            child: _DashboardMetric(
                              label: 'تحتاج مراجعة',
                              value: attention,
                              icon: Icons.error_outline_rounded,
                              warning: true,
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                _DashboardStorageCard(loadUsage: storageUsageBytes),
                const SizedBox(height: 22),
                _DashboardSectionHeading(title: 'مسارات العمل'),
                const SizedBox(height: 9),
                _DashboardAction(
                  icon: Icons.grid_view_rounded,
                  title: 'المهام والمشاريع',
                  subtitle: 'تابع التقدم والأخطاء والمساحة المستخدمة',
                  onTap: onOpenJobs,
                ),
                const SizedBox(height: 8),
                _DashboardAction(
                  icon: Icons.movie_filter_outlined,
                  title: 'المراجعة والتحرير',
                  subtitle: 'راجع التفريغ والاقتراحات وحرّر حدود المقاطع',
                  onTap: onOpenReview,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _DashboardSectionHeading(
                        title: 'المشاريع الأخيرة',
                      ),
                    ),
                    TextButton(
                      onPressed: onOpenJobs,
                      child: Text(cutawanText(context, 'عرض الكل'))),
                    ),
                  ],
                ),
                if (recent.isEmpty)
                  const _DashboardEmptyState()
                else
                  for (final project in recent)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        key: ValueKey('dashboard-project-${project.id}'),
                        minVerticalPadding: 12,
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.12),
                          child: Icon(
                            Icons.video_file_outlined,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        title: Text(
                          project.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${project.source.width} × ${project.source.height} · ${project.job.stage}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_left_rounded),
                        onTap: () => onOpenProject(project),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DashboardStorageCard extends StatefulWidget {
  const _DashboardStorageCard({required this.loadUsage});

  final Future<int> Function() loadUsage;

  @override
  State<_DashboardStorageCard> createState() => _DashboardStorageCardState();
}

class _DashboardStorageCardState extends State<_DashboardStorageCard> {
  late Future<int> _usage;

  @override
  void initState() {
    super.initState();
    _usage = Future<int>.sync(widget.loadUsage);
  }

  void _refresh() {
    setState(() {
      _usage = Future<int>.sync(widget.loadUsage);
    });
  }

  String _formatUsage(int bytes) {
    if (bytes <= 0) return '0 KB';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<int>(
      future: _usage,
      builder: (context, snapshot) {
        final description = snapshot.hasData
            ? _formatUsage(snapshot.data!)
            : snapshot.hasError
                ? 'تعذّر قراءة مساحة التنزيلات'
                : 'جارٍ حساب مساحة التنزيلات…';
        return Card(
          key: const ValueKey('dashboard-storage-card'),
          child: ListTile(
            minVerticalPadding: 12,
            leading: CircleAvatar(
              backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
              child: Icon(Icons.storage_outlined, color: scheme.onSurfaceVariant),
            ),
            title: Text(cutawanText(context, 'مساحة تنزيلات CUTAWAN'))),
            subtitle: Text(description),
            trailing: IconButton(
              key: const ValueKey('dashboard-refresh-storage'),
              tooltip: 'تحديث مساحة التخزين',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            scheme.onSurface.withValues(alpha: 0.06),
            scheme.surfaceContainer,
          ],
        ),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.movie_filter_rounded, size: 28, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(cutawanText(context, 'حوّل الفيديو إلى قصة قصيرة متماسكة.')),
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(cutawanText(context, 'استورد ملفك، ثم راجع التفريغ واللحظات المقترحة وعدّل المقاطع قبل التصدير.')),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('dashboard-create-project'),
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: Text(cutawanText(context, 'إنشاء مشروع جديد'))),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSectionHeading extends StatelessWidget {
  const _DashboardSectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w900),
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.warning = false,
  });

  final String label;
  final int value;
  final IconData icon;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: warning ? scheme.error : scheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardAction extends StatelessWidget {
  const _DashboardAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        minVerticalPadding: 12,
        leading: Icon(icon, color: scheme.onSurfaceVariant),
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _DashboardEmptyState extends StatelessWidget {
  const _DashboardEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(
              Icons.video_collection_outlined,
              size: 32,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(cutawanText(context, 'لا توجد مشاريع محفوظة بعد'))),
            const SizedBox(height: 4),
            Text(cutawanText(context, 'سيظهر سجل الفيديوهات هنا بعد استيراد أول مشروع.')),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
