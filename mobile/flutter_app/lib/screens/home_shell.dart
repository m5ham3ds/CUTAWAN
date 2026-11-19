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
    JobsPage(),
    ReviewPage(),
    CaptionStudioPage(),
  ];

  void _openModels() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ModelsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          IconButton(tooltip: 'مركز النماذج', onPressed: _openModels, icon: const Icon(Icons.memory_outlined)),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: IndexedStack(index: _selectedIndex, children: _pages)),
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
  const CreatePage({super.key});

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

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _showUnavailable(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature غير متصل بمحرك Android حتى الآن. لم تبدأ أي معالجة.')),
    );
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
        Text('فيديو طويل يدخل.\nمقاطع أقوى تخرج.',
            style: theme.textTheme.headlineMedium?.copyWith(height: 1.08, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
        const SizedBox(height: 10),
        Text('اختر المصدر، ثم اضبط عدد المقاطع والمدة والتكوين قبل التحليل.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.55)),
        const SizedBox(height: 28),
        const _Eyebrow('01  /  مصدر الفيديو'),
        const SizedBox(height: 8),
        TextField(
          controller: _urlController,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: 'ألصق رابط الفيديو هنا', prefixIcon: Icon(Icons.link)),
          onSubmitted: (_) => _showUnavailable('تحليل الرابط'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: FilledButton.icon(onPressed: () => _showUnavailable('تحليل الرابط'), icon: const Icon(Icons.play_arrow_rounded), label: const Text('بدء التحليل'))),
            const SizedBox(width: 10),
            OutlinedButton.icon(onPressed: () => _showUnavailable('استيراد الملف'), icon: const Icon(Icons.upload_file_outlined), label: const Text('ملف')),
          ],
        ),
        const SizedBox(height: 9),
        Text('استورد ملفًا تملك حق معالجته، أو أدخل رابطًا مدعومًا.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
          children: [5, 10, 15, 20].map((value) => ChoiceChip(
            label: Text('$value'),
            selected: _clipCount == value,
            onSelected: (_) => setState(() => _clipCount = value),
          )).toList(),
        ),
        const SizedBox(height: 22),
        Text('المدة المستهدفة', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<ClipDurationMode>(
          initialValue: _duration,
          isExpanded: true,
          items: ClipDurationMode.values.map((mode) => DropdownMenuItem(
            value: mode,
            child: Text(switch (mode) {
              ClipDurationMode.automatic => 'تلقائي حسب اكتمال اللحظة',
              ClipDurationMode.seconds15To30 => '15–30 ثانية',
              ClipDurationMode.seconds30To45 => '30–45 ثانية',
              ClipDurationMode.seconds30To60 => '30–60 ثانية',
              ClipDurationMode.seconds60To90 => '60–90 ثانية',
              ClipDurationMode.custom => 'مدة مخصصة',
            }),
          )).toList(),
          onChanged: (value) { if (value != null) setState(() => _duration = value); },
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
            return ChoiceChip(label: Text(label), selected: _ratio == ratio, onSelected: (_) => setState(() => _ratio = ratio));
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
          subtitle: const Text('إعداد مبدئي؛ يحتاج محرك الرؤية'),
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
                subtitle: Text('ستضاف حدود المدة المخصصة وترتيب المقاطع ومستوى إزالة التكرار في مرحلة إعداد المحرك.'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
        _SummaryLine(label: 'عدد المقاطع', value: '$_clipCount'),
        _SummaryLine(label: 'المدة', value: _durationLabel),
        _SummaryLine(label: 'التكوين', value: switch (_ratio) {
          ClipAspectRatio.portrait916 => '9:16',
          ClipAspectRatio.square11 => '1:1',
          ClipAspectRatio.landscape169 => '16:9',
          ClipAspectRatio.original => 'الأصلية',
        }),
        _SummaryLine(label: 'الكابشن', value: _captions ? 'مفعّل' : 'متوقف'),
        _SummaryLine(label: 'تتبع المتحدث', value: _speakerTracking ? 'محدد' : 'متوقف'),
        const SizedBox(height: 18),
        const _StatusNote(text: 'هذه شاشة إعداد وتجهيز فقط. استيراد الوسائط وتنزيل الروابط والتحليل لم تُربط بمحركات Android بعد.'),
      ],
    );
  }
}

class JobsPage extends StatelessWidget {
  const JobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        const _Eyebrow('مساحة العمل  /  سجل المعالجة'),
        const SizedBox(height: 14),
        Text('المهام والمشاريع', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('تابع حالة كل مشروع ومراحل المعالجة وإمكانية الاستئناف.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 28),
        const _StatusNote(text: 'سجل المهام الدائم والاستئناف بعد إغلاق التطبيق ضمن مرحلة تخزين المشاريع ومحرك الوظائف.'),
        const SizedBox(height: 28),
        const _EmptyState(
          icon: Icons.pending_actions_outlined,
          title: 'لا توجد مهام بعد',
          description: 'عند ربط الاستيراد والتحليل ستظهر هنا مراحل التنزيل والتفريغ الصوتي واكتشاف اللحظات والتصدير.',
        ),
      ],
    );
  }
}

class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        const _Eyebrow('مساحة العمل  /  اختيار النتائج'),
        const SizedBox(height: 14),
        Text('مراجعة المقاطع', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('شاهد المرشحين، قارن أسباب التقييم، ثم احتفظ بالمقاطع التي تريد تصديرها.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5)),
        const SizedBox(height: 28),
        Container(
          height: 190,
          decoration: BoxDecoration(
            color: const Color(0xFF211E19),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: const Center(child: Icon(Icons.movie_filter_outlined, size: 46)),
        ),
        const SizedBox(height: 18),
        const _EmptyState(
          icon: Icons.video_collection_outlined,
          title: 'لا توجد مقاطع للمراجعة',
          description: 'ستظهر بطاقات المقاطع هنا مع المدة والدرجة وسبب الاختيار والتحكم في الترتيب والقص الفردي.',
        ),
      ],
    );
  }
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
