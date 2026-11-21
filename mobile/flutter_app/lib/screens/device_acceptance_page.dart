import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/device_acceptance_service.dart';

class DeviceAcceptancePage extends StatefulWidget {
  const DeviceAcceptancePage({super.key, this.service});

  final DeviceAcceptanceService? service;

  @override
  State<DeviceAcceptancePage> createState() => _DeviceAcceptancePageState();
}

class _DeviceAcceptancePageState extends State<DeviceAcceptancePage> {
  late final DeviceAcceptanceService _service =
      widget.service ?? DeviceAcceptanceService();
  Map<String, Object?>? _report;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await _service.collect();
      if (!mounted) return;
      setState(() => _report = value);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyReport() async {
    final report = _report;
    if (report == null) return;
    await Clipboard.setData(
      ClipboardData(text: const JsonEncoder.withIndent('  ').convert(report)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ سجل تشخيص الجهاز بصيغة JSON')),
    );
  }

  String _memory(Object? bytes) {
    if (bytes is! num || bytes < 0) return 'غير متاح';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _thermal(Object? value) {
    switch (value) {
      case 0:
        return 'طبيعي';
      case 1:
        return 'خفيف';
      case 2:
        return 'متوسط';
      case 3:
        return 'شديد';
      case 4:
        return 'حرج';
      case 5:
        return 'طارئ';
      case 6:
        return 'إيقاف';
      default:
        return 'غير مدعوم / غير متاح';
    }
  }

  String _number(Object? value) => value?.toString() ?? 'غير متاح';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final data = _report;
    final isPhysical = data?['isPhysicalDevice'] == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('تشخيص قبول Android'),
        actions: [
          IconButton(
            tooltip: 'تحديث القياسات',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.phonelink_setup_rounded, color: scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'بوابة المرحلة 10',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (data != null)
                        Chip(
                          label: Text(isPhysical ? 'جهاز فعلي' : 'محاكي / غير مؤكد'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'يجمع هذا الفحص معلومات الأداء الأساسية ويختبر التخزين الآمن. '
                    'لا يُعدّ اجتيازًا نهائيًا؛ ما زالت قياسات Whisper والفيديو '
                    'والاستعادة مطلوبة بملفات اختبار حقيقية.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (_loading) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: scheme.error)),
                  ],
                ],
              ),
            ),
          ),
          if (data != null) ...[
            const SizedBox(height: 14),
            _section(context, 'بيانات الجهاز'),
            _metric(
              context,
              'الشركة والطراز',
              '${data['manufacturer'] ?? '—'} ${data['model'] ?? ''}'.trim(),
            ),
            _metric(
              context,
              'إصدار Android',
              '${data['androidRelease'] ?? '—'} (API ${data['androidSdk'] ?? '—'})',
            ),
            _metric(
              context,
              'إصدار التطبيق',
              '${data['appVersionName'] ?? '—'} (${data['appVersionCode'] ?? '—'})',
            ),
            _metric(context, 'أنوية المعالج', _number(data['cpuCoreCount'])),
            _metric(context, 'بصمة البناء', _number(data['buildSha'])),
            const SizedBox(height: 12),
            _section(context, 'الذاكرة والتخزين'),
            _metric(context, 'إجمالي RAM', _memory(data['totalMemoryBytes'])),
            _metric(context, 'RAM المتاحة', _memory(data['availableMemoryBytes'])),
            _metric(context, 'ذاكرة العملية PSS', '${_number(data['processPssKb'])} KB'),
            _metric(
              context,
              'التخزين المتاح',
              _memory(data['availableStorageBytes']),
            ),
            const SizedBox(height: 12),
            _section(context, 'الطاقة والحرارة'),
            _metric(
              context,
              'مستوى البطارية',
              data['batteryPercent'] is num && (data['batteryPercent'] as num) >= 0
                  ? '${data['batteryPercent']}%'
                  : 'غير متاح',
            ),
            _metric(
              context,
              'حرارة البطارية',
              data['batteryTemperatureTenthsC'] is num &&
                      (data['batteryTemperatureTenthsC'] as num) >= 0
                  ? '${((data['batteryTemperatureTenthsC'] as num) / 10).toStringAsFixed(1)} °C'
                  : 'غير متاح',
            ),
            _metric(context, 'الحالة الحرارية', _thermal(data['thermalStatus'])),
            const SizedBox(height: 12),
            _section(context, 'فحوصات الأمان'),
            _metric(
              context,
              'اختبار التخزين الآمن',
              data['secureStorageRoundTrip'] == 'passed' ? 'نجح' : 'غير مكتمل',
            ),
            _metric(
              context,
              'حذف مفتاح الاختبار المؤقت',
              data['secureStorageCanaryDeleted'] == true ? 'تم التحقق' : 'غير مؤكد',
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _copyReport,
              icon: const Icon(Icons.copy_all_rounded),
              label: const Text('نسخ سجل التشخيص JSON'),
            ),
            const SizedBox(height: 10),
            SelectableText(
              'حالة القبول: ${data['phase10Acceptance'] ?? 'غير متاحة'}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 6),
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      );

  Widget _metric(BuildContext context, String label, String value) => Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: ListTile(
          dense: true,
          title: Text(label),
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
}
