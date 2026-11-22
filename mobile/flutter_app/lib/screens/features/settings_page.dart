import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    required this.onDiagnostics,
    required this.onModels,
    super.key,
  });

  final VoidCallback onDiagnostics;
  final VoidCallback onModels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width < 360 ? 14.0 : width < 600 ? 18.0 : 24.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات CUTAWAN'),
        centerTitle: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            key: const ValueKey('cutawan-settings-list'),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              14,
              horizontalPadding,
              30,
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.075),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.tune_rounded, color: scheme.primary, size: 25),
                    const SizedBox(height: 10),
                    Text(
                      'تحكم في بيئة CUTAWAN',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'إدارة الجهاز والنماذج والخصوصية من مكان واحد.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _SettingsSectionTitle(
                title: 'التطبيق والجهاز',
                subtitle: 'حالة الهاتف ومصادر الذكاء الاصطناعي',
              ),
              const SizedBox(height: 9),
              _SettingsActionTile(
                icon: Icons.monitor_heart_outlined,
                title: 'تشخيص وقبول Android',
                subtitle:
                    'الذاكرة والبطارية والحرارة والتخزين وأدلة الاختبارات الميدانية',
                onTap: onDiagnostics,
              ),
              const SizedBox(height: 8),
              _SettingsActionTile(
                icon: Icons.memory_rounded,
                title: 'مركز النماذج والاتصالات',
                subtitle:
                    'النماذج المحلية والمزوّدون والمفاتيح وموافقة الإرسال السحابي',
                onTap: onModels,
              ),
              const SizedBox(height: 22),
              const _SettingsSectionTitle(
                title: 'المظهر وإمكانية الوصول',
                subtitle: 'خيارات يتبعها التطبيق من إعدادات Android',
              ),
              const SizedBox(height: 9),
              Card(
                child: ListTile(
                  minVerticalPadding: 12,
                  leading: Icon(Icons.dark_mode_outlined, color: scheme.primary),
                  title: const Text('وضع الألوان'),
                  subtitle: const Text(
                    'يتبع CUTAWAN وضع المظهر الفاتح أو الداكن الذي يحدده النظام.',
                  ),
                  trailing: const Chip(label: Text('حسب النظام')),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  minVerticalPadding: 12,
                  leading: Icon(
                    Icons.motion_photos_off_outlined,
                    color: scheme.primary,
                  ),
                  title: const Text('تقليل الحركة'),
                  subtitle: const Text(
                    'يُحترم إعداد تقليل الحركة وإمكانية الوصول من نظام Android.',
                  ),
                  trailing: const Icon(Icons.settings_suggest_outlined),
                ),
              ),
              const SizedBox(height: 22),
              const _SettingsSectionTitle(
                title: 'الخصوصية والمعالجة',
                subtitle: 'ما الذي يبقى على الجهاز وما الذي قد يغادره',
              ),
              const SizedBox(height: 9),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shield_outlined, color: scheme.secondary),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'المعالجة المحلية هي المسار الافتراضي',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'لا تُرسل مقتطفات نص التفريغ إلى مزوّد خارجي إلا بعد اختيار النمط البعيد وتفعيل موافقة صريحة.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'يمكن إدارة مفاتيح المزوّدين من مركز النماذج. لا تُدرج المفاتيح أو محتوى الفيديو في تقرير التشخيص.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const _SettingsSectionTitle(
                title: 'المعلومات القانونية',
                subtitle: 'التراخيص والمكوّنات الخارجية',
              ),
              const SizedBox(height: 9),
              Card(
                child: ListTile(
                  minVerticalPadding: 12,
                  leading: Icon(Icons.policy_outlined, color: scheme.primary),
                  title: const Text('التراخيص والإشعارات'),
                  subtitle: const Text(
                    'راجع LICENSE و THIRD_PARTY_NOTICES.md في مستودع CUTAWAN.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
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
        leading: CircleAvatar(
          backgroundColor: scheme.primary.withValues(alpha: 0.12),
          child: Icon(icon, color: scheme.primary),
        ),
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: onTap,
      ),
    );
  }
}
