import 'package:flutter/material.dart';

import '../domain/caption_catalog.dart';
import '../domain/clip_preferences.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  static const _pages = <Widget>[
    CreatePage(),
    ProjectsPage(),
    CaptionStudioPage(),
    ModelsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CUTAWAN', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            Text('AI CLIPPING STUDIO', style: TextStyle(fontSize: 10, letterSpacing: 1.8)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings information',
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'Cutawan Mobile',
              applicationVersion: '0.1.0',
              children: const [
                Text('Flutter Android shell. Video engines and model execution are added in later phases.'),
              ],
            ),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: SafeArea(child: _pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.add_link), label: 'إنشاء'),
          NavigationDestination(icon: Icon(Icons.video_library_outlined), label: 'مشاريعي'),
          NavigationDestination(icon: Icon(Icons.subtitles_outlined), label: 'الكابشن'),
          NavigationDestination(icon: Icon(Icons.memory_outlined), label: 'النماذج'),
        ],
      ),
    );
  }
}

class CreatePage extends StatefulWidget {
  const CreatePage({super.key});

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  final _urlController = TextEditingController();
  int _clipCount = 20;
  ClipDurationMode _duration = ClipDurationMode.automatic;
  ClipAspectRatio _ratio = ClipAspectRatio.portrait916;
  bool _captions = true;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  String get _durationLabel => switch (_duration) {
        ClipDurationMode.automatic => 'تلقائي حسب اكتمال اللحظة',
        ClipDurationMode.seconds15To30 => '15–30 ثانية',
        ClipDurationMode.seconds30To45 => '30–45 ثانية',
        ClipDurationMode.seconds30To60 => '30–60 ثانية',
        ClipDurationMode.seconds60To90 => '60–90 ثانية',
        ClipDurationMode.custom => 'مدة مخصصة',
      };

  String get _ratioLabel => switch (_ratio) {
        ClipAspectRatio.portrait916 => '9:16',
        ClipAspectRatio.square11 => '1:1',
        ClipAspectRatio.landscape169 => '16:9',
        ClipAspectRatio.original => 'الأصلية',
      };

  void _showNotConnected() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تجهيز الواجهة. ربط تنزيل الفيديو ومحركات التحليل يأتي في المرحلة التالية.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text('حوّل الفيديو الطويل إلى مقاطع قصيرة', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'أدخل رابطًا أو اختر ملفًا، ثم دع محرك القص يكتشف اللحظات القوية ويجهزها للمراجعة.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('مصدر الفيديو', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    hintText: 'https://youtube.com/watch?v=...',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _showNotConnected,
                        icon: const Icon(Icons.search),
                        label: const Text('تحليل الفيديو'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _showNotConnected,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('ملف'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('إعدادات المقاطع', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                const Text('عدد المقاطع'),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 5, label: Text('5')),
                    ButtonSegment(value: 10, label: Text('10')),
                    ButtonSegment(value: 15, label: Text('15')),
                    ButtonSegment(value: 20, label: Text('20')),
                  ],
                  selected: {_clipCount},
                  onSelectionChanged: (value) => setState(() => _clipCount = value.first),
                ),
                const SizedBox(height: 18),
                const Text('المدة المستهدفة لكل مقطع'),
                const SizedBox(height: 8),
                DropdownButtonFormField<ClipDurationMode>(
                  initialValue: _duration,
                  items: ClipDurationMode.values
                      .map((mode) => DropdownMenuItem(
                            value: mode,
                            child: Text(switch (mode) {
                              ClipDurationMode.automatic => 'تلقائي',
                              ClipDurationMode.seconds15To30 => '15–30 ثانية',
                              ClipDurationMode.seconds30To45 => '30–45 ثانية',
                              ClipDurationMode.seconds30To60 => '30–60 ثانية',
                              ClipDurationMode.seconds60To90 => '60–90 ثانية',
                              ClipDurationMode.custom => 'مخصصة',
                            }),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _duration = value);
                  },
                ),
                const SizedBox(height: 18),
                const Text('أبعاد الفيديو'),
                const SizedBox(height: 8),
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
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('إضافة الكابشن'),
                  subtitle: const Text('يمكن إيقافه أو تخصيصه لكل مقطع لاحقًا'),
                  value: _captions,
                  onChanged: (value) => setState(() => _captions = value),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'الإعداد الحالي: $_clipCount مقطع · $_durationLabel · $_ratioLabel · الكابشن ${_captions ? "مفعّل" : "متوقف"}',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context) => const _EmptyPage(
        icon: Icons.video_library_outlined,
        title: 'لا توجد مشاريع بعد',
        description: 'ستظهر هنا مشاريعك، نتائج التحليل، والمقاطع التي حفظتها للمراجعة.',
      );
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
    final selectedStyle = captionStylePresets.firstWhere((style) => style.id == _styleId);
    final selectedAnimation = captionAnimationPresets.firstWhere((item) => item.id == _animationId);

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text('Caption Studio', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('اختر المظهر والحركة كلًّا على حدة. هذه مكتبة الإعدادات الأولية؛ ربط المعاينة بمحرك التصدير يأتي بعد اختيار محرك الوسائط.'),
        const SizedBox(height: 16),
        Container(
          height: 210,
          decoration: BoxDecoration(
            color: const Color(0xFF242631),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF414352)),
          ),
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: selectedStyle.highlightBoxColor == null
                  ? Colors.transparent
                  : _colorFromHex(selectedStyle.highlightBoxColor!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'هذه لحظة تستحق أن تتحول إلى مقطع قصير',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _colorFromHex(selectedStyle.textColor),
                fontSize: 21,
                fontWeight: selectedStyle.bold ? FontWeight.bold : FontWeight.w600,
                shadows: [
                  Shadow(
                    color: _colorFromHex(selectedStyle.outlineColor),
                    blurRadius: selectedStyle.outlineWidth * 2,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('معاينة شكلية للإعدادات فقط؛ ليست معاينة حركة أو تصدير فعليًا.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 18),
        const Text('التصميم البصري', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: captionStylePresets.map((style) {
            return ChoiceChip(
              label: Text(style.name),
              selected: _styleId == style.id,
              onSelected: (_) => setState(() => _styleId = style.id),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        const Text('حركة النص', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _animationId,
          items: captionAnimationPresets
              .map((item) => DropdownMenuItem(value: item.id, child: Text(item.name)))
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _animationId = value);
          },
        ),
        const SizedBox(height: 10),
        Text(
          '${selectedStyle.name} · ${selectedAnimation.name}: ${selectedAnimation.description}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        const Text('الألوان والخطوط والسرعة والموضع ستصبح قابلة للتحرير الكامل في مرحلة Caption Studio.'),
      ],
    );
  }
}

class ModelsPage extends StatelessWidget {
  const ModelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final models = [
      ('Whisper.cpp', 'تحويل الكلام إلى نص وتحديد توقيت الكلمات', Icons.graphic_eq),
      ('llama.cpp + GGUF', 'تحليل النص واختيار أفضل اللحظات', Icons.psychology_alt_outlined),
      ('ONNX Runtime', 'كشف الوجوه والمتحدث النشط وVAD', Icons.face_retouching_natural),
    ];

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text('AI Model Center', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('إدارة النماذج المحلية ستضاف بعد تثبيت توافق Android وترخيص كل نموذج. لا توجد نماذج محمّلة في هذه النسخة الأولية.'),
        const SizedBox(height: 16),
        for (final model in models)
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Icon(model.$3)),
              title: Text(model.$1),
              subtitle: Text(model.$2),
              trailing: const Chip(label: Text('قيد الإعداد')),
            ),
          ),
      ],
    );
  }
}

class _EmptyPage extends StatelessWidget {
  const _EmptyPage({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

Color _colorFromHex(String hex) {
  final value = hex.replaceFirst('#', '');
  final parsed = int.tryParse(value, radix: 16) ?? 0xFFFFFF;
  return Color(0xFF000000 | parsed);
}
