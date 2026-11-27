import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/app_preferences.dart';
import '../../services/app_preferences_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.store,
    required this.onDiagnostics,
    required this.onModels,
    super.key,
  });

  final AppPreferencesStore store;
  final VoidCallback onDiagnostics;
  final VoidCallback onModels;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _save(AppPreferences preferences) async {
    try {
      await widget.store.update(preferences);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّر حفظ التفضيل على هذا الجهاز. لم يتغير الإعداد.'),
        ),
      );
    }
  }

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
              12,
              horizontalPadding,
              30,
            ),
            children: [
              const _SettingsSectionTitle(title: 'أدوات التطبيق'),
              const SizedBox(height: 8),
              _SettingsActionTile(
                tileKey: const ValueKey('settings-device-diagnostics'),
                icon: Icons.monitor_heart_outlined,
                title: 'تشخيص الجهاز',
                onTap: widget.onDiagnostics,
              ),
              const SizedBox(height: 8),
              _SettingsActionTile(
                tileKey: const ValueKey('settings-model-center'),
                icon: Icons.memory_rounded,
                title: 'مركز النماذج',
                onTap: widget.onModels,
              ),
              const SizedBox(height: 20),
              const _SettingsSectionTitle(title: 'المظهر وإمكانية الوصول'),
              const SizedBox(height: 8),
              ValueListenableBuilder<AppPreferences>(
                valueListenable: widget.store.preferences,
                builder: (context, preferences, _) => Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.dark_mode_outlined, color: scheme.primary),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    'وضع الألوان',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  key: const ValueKey('settings-theme-system'),
                                  label: const Text('النظام'),
                                  selected: preferences.themeMode == AppThemeMode.system,
                                  onSelected: (selected) {
                                    if (selected) {
                                      unawaited(_save(
                                        preferences.copyWith(themeMode: AppThemeMode.system),
                                      ));
                                    }
                                  },
                                ),
                                ChoiceChip(
                                  key: const ValueKey('settings-theme-light'),
                                  label: const Text('فاتح'),
                                  selected: preferences.themeMode == AppThemeMode.light,
                                  onSelected: (selected) {
                                    if (selected) {
                                      unawaited(_save(
                                        preferences.copyWith(themeMode: AppThemeMode.light),
                                      ));
                                    }
                                  },
                                ),
                                ChoiceChip(
                                  key: const ValueKey('settings-theme-dark'),
                                  label: const Text('داكن'),
                                  selected: preferences.themeMode == AppThemeMode.dark,
                                  onSelected: (selected) {
                                    if (selected) {
                                      unawaited(_save(
                                        preferences.copyWith(themeMode: AppThemeMode.dark),
                                      ));
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: SwitchListTile(
                        key: const ValueKey('settings-reduce-motion'),
                        value: preferences.reduceMotion,
                        onChanged: (value) => unawaited(
                          _save(preferences.copyWith(reduceMotion: value)),
                        ),
                        secondary: Icon(
                          Icons.motion_photos_off_outlined,
                          color: scheme.primary,
                        ),
                        title: const Text('تقليل الحركة'),
                        subtitle: const Text('تقليل الحركات والانتقالات داخل التطبيق.'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const _SettingsSectionTitle(title: 'الخصوصية والمعالجة'),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Icon(Icons.shield_outlined, color: scheme.secondary),
                  title: const Text(
                    'المعالجة المحلية هي الوضع الافتراضي',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'لا يغادر نص التفريغ الجهاز إلا عند اختيار الوضع السحابي وتفعيل الموافقة.',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const _SettingsSectionTitle(title: 'المعلومات القانونية'),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  minVerticalPadding: 12,
                  leading: Icon(Icons.policy_outlined, color: scheme.primary),
                  title: const Text('التراخيص والإشعارات'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'CUTAWAN',
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
  const _SettingsSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 2),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    this.tileKey,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final Key? tileKey;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: tileKey,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        minVerticalPadding: 12,
        leading: CircleAvatar(
          backgroundColor: scheme.primary.withValues(alpha: 0.12),
          child: Icon(icon, color: scheme.primary),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: onTap,
      ),
    );
  }
}
