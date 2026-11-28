import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/app_preferences.dart';
import '../../l10n/app_strings.dart';
import '../../services/app_preferences_store.dart';
import '../../theme/cutawan_theme.dart';

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
        SnackBar(
          content: Text(
            cutawanText(
              context,
              'تعذّر حفظ التفضيل على هذا الجهاز. لم يتغير الإعداد.',
            ),
          ),
        ),
      );
    }
  }

  String _accentName(BuildContext context, AppAccentColor accent) =>
      cutawanText(
        context,
        switch (accent) {
          AppAccentColor.red => 'الأحمر',
          AppAccentColor.blue => 'الأزرق',
          AppAccentColor.orange => 'البرتقالي',
          AppAccentColor.purple => 'البنفسجي',
          AppAccentColor.yellow => 'الأصفر',
        },
      );

  Future<void> _confirmAccent(
    AppPreferences preferences,
    AppAccentColor accent,
  ) async {
    if (accent == preferences.accentColor) return;

    final color = CutawanTheme.colorFor(accent);
    final translatedQuestion = cutawanText(context, 'هل تريد تطبيق اللون');
    final translatedAccent = _accentName(context, accent);
    final questionMark =
        Localizations.localeOf(context).languageCode == 'ar' ? '؟' : '?';
    final prompt = '$translatedQuestion $translatedAccent$questionMark';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(cutawanText(dialogContext, 'تأكيد اللون الأساسي')),
        content: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(dialogContext).colorScheme.outline,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(prompt),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cutawanText(dialogContext, 'إلغاء')),
          ),
          FilledButton(
            key: const ValueKey('settings-accent-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(cutawanText(dialogContext, 'تأكيد')),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;
    await _save(preferences.copyWith(accentColor: accent));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width < 360 ? 14.0 : width < 600 ? 18.0 : 24.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(cutawanText(context, 'إعدادات CUTAWAN')),
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
              _SettingsSectionTitle(
                title: cutawanText(context, 'أدوات التطبيق'),
              ),
              const SizedBox(height: 8),
              _SettingsActionTile(
                tileKey: const ValueKey('settings-device-diagnostics'),
                icon: Icons.monitor_heart_outlined,
                title: cutawanText(context, 'تشخيص الجهاز'),
                onTap: widget.onDiagnostics,
              ),
              const SizedBox(height: 8),
              _SettingsActionTile(
                tileKey: const ValueKey('settings-model-center'),
                icon: Icons.memory_rounded,
                title: cutawanText(context, 'مركز النماذج'),
                onTap: widget.onModels,
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<AppPreferences>(
                valueListenable: widget.store.preferences,
                builder: (context, preferences, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SettingsSectionTitle(
                      title: cutawanText(context, 'اللغة'),
                    ),
                    const SizedBox(height: 8),
                    _SettingsCard(
                      icon: Icons.language_rounded,
                      title: cutawanText(context, 'اللغة'),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SettingsChoice(
                            key: const ValueKey('settings-language-system'),
                            label: cutawanText(context, 'حسب النظام'),
                            selected:
                                preferences.language == AppLanguage.system,
                            onSelected: () => unawaited(
                              _save(
                                preferences.copyWith(
                                  language: AppLanguage.system,
                                ),
                              ),
                            ),
                          ),
                          _SettingsChoice(
                            key: const ValueKey('settings-language-arabic'),
                            label: cutawanText(context, 'العربية'),
                            selected:
                                preferences.language == AppLanguage.arabic,
                            onSelected: () => unawaited(
                              _save(
                                preferences.copyWith(
                                  language: AppLanguage.arabic,
                                ),
                              ),
                            ),
                          ),
                          _SettingsChoice(
                            key: const ValueKey('settings-language-english'),
                            label: cutawanText(context, 'الإنجليزية'),
                            selected:
                                preferences.language == AppLanguage.english,
                            onSelected: () => unawaited(
                              _save(
                                preferences.copyWith(
                                  language: AppLanguage.english,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SettingsSectionTitle(
                      title: cutawanText(context, 'المظهر وإمكانية الوصول'),
                    ),
                    const SizedBox(height: 8),
                    _SettingsCard(
                      icon: Icons.dark_mode_outlined,
                      title: cutawanText(context, 'وضع الألوان'),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SettingsChoice(
                            key: const ValueKey('settings-theme-system'),
                            label: cutawanText(context, 'النظام'),
                            selected:
                                preferences.themeMode == AppThemeMode.system,
                            onSelected: () => unawaited(
                              _save(
                                preferences.copyWith(
                                  themeMode: AppThemeMode.system,
                                ),
                              ),
                            ),
                          ),
                          _SettingsChoice(
                            key: const ValueKey('settings-theme-light'),
                            label: cutawanText(context, 'فاتح'),
                            selected:
                                preferences.themeMode == AppThemeMode.light,
                            onSelected: () => unawaited(
                              _save(
                                preferences.copyWith(
                                  themeMode: AppThemeMode.light,
                                ),
                              ),
                            ),
                          ),
                          _SettingsChoice(
                            key: const ValueKey('settings-theme-dark'),
                            label: cutawanText(context, 'داكن'),
                            selected:
                                preferences.themeMode == AppThemeMode.dark,
                            onSelected: () => unawaited(
                              _save(
                                preferences.copyWith(
                                  themeMode: AppThemeMode.dark,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SettingsCard(
                      icon: Icons.palette_outlined,
                      title: cutawanText(context, 'اللون الأساسي'),
                      child: Wrap(
                        spacing: 14,
                        runSpacing: 12,
                        children: [
                          for (final accent in AppAccentColor.values)
                            _AccentChoice(
                              key: ValueKey(
                                'settings-accent-${accent.name}',
                              ),
                              color: CutawanTheme.colorFor(accent),
                              label: _accentName(context, accent),
                              selected: preferences.accentColor == accent,
                              onTap: () => unawaited(
                                _confirmAccent(preferences, accent),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: SwitchListTile(
                        key: const ValueKey('settings-reduce-motion'),
                        value: preferences.reduceMotion,
                        onChanged: (value) => unawaited(
                          _save(
                            preferences.copyWith(reduceMotion: value),
                          ),
                        ),
                        secondary: Icon(
                          Icons.motion_photos_off_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                        title: Text(
                          cutawanText(context, 'تقليل الحركة'),
                        ),
                        subtitle: Text(
                          cutawanText(
                            context,
                            'تقليل الحركات والانتقالات داخل التطبيق.',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SettingsSectionTitle(
                title: cutawanText(context, 'الخصوصية والمعالجة'),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Icon(
                    Icons.shield_outlined,
                    color: scheme.secondary,
                  ),
                  title: Text(
                    cutawanText(
                      context,
                      'المعالجة المحلية هي الوضع الافتراضي',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    cutawanText(
                      context,
                      'لا يغادر نص التفريغ الجهاز إلا عند اختيار الوضع السحابي وتفعيل الموافقة.',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _SettingsSectionTitle(
                title: cutawanText(context, 'المعلومات القانونية'),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  minVerticalPadding: 12,
                  leading: Icon(
                    Icons.policy_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                  title: Text(
                    cutawanText(context, 'التراخيص والإشعارات'),
                  ),
                  trailing: Icon(
                    Localizations.localeOf(context).languageCode == 'ar'
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                  ),
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 2),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: scheme.onSurfaceVariant),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SettingsChoice extends StatelessWidget {
  const _SettingsChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      );
}

class _AccentChoice extends StatelessWidget {
  const _AccentChoice({
    super.key,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppAccentColor.values.firstWhere(
      (value) => CutawanTheme.colorFor(value) == color,
    );
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 46,
            height: 46,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? scheme.onSurface : scheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: selected
                  ? Icon(
                      Icons.check_rounded,
                      color: CutawanTheme.onColorFor(accent),
                      size: 20,
                    )
                  : null,
            ),
          ),
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
          backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
          child: Icon(icon, color: scheme.onSurfaceVariant),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        trailing: Icon(
          Localizations.localeOf(context).languageCode == 'ar'
              ? Icons.chevron_left_rounded
              : Icons.chevron_right_rounded,
        ),
        onTap: onTap,
      ),
    );
  }
}
