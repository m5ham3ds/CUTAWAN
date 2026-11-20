part of '../home_shell.dart';

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
