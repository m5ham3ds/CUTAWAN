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
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final report = await _service.collect();
      if (!mounted) return;
      setState(() => _report = report);
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

    try {
      await Clipboard.setData(
        ClipboardData(text: const JsonEncoder.withIndent('  ').convert(report)),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نُسخ تقرير التشخيص')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر نسخ التقرير: $error')),
      );
    }
  }

  String _memory(Object? bytes) {
    if (bytes is! num || !bytes.isFinite || bytes < 0) return 'غير متاح';
    final gib = bytes / (1024 * 1024 * 1024);
    return gib >= 1
        ? '${gib.toStringAsFixed(2)} GB'
        : '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }

  String _thermal(Object? value) {
    return switch (value) {
      0 => 'طبيعي',
      1 => 'خفيف',
      2 => 'متوسط',
      3 => 'مرتفع',
      4 => 'حرج',
      5 => 'طارئ',
      6 => 'إيقاف حراري',
      _ => 'غير متاح',
    };
  }

  String _battery(Object? value) {
    if (value is! num || value < 0 || value > 100) return 'غير متاح';
    return '${value.round()}%';
  }

  String _temperature(Object? value) {
    if (value is! num || value < 0) return 'غير متاح';
    return '${(value / 10).toStringAsFixed(1)} °C';
  }

  String _value(Object? value) {
    if (value == null || value.toString().trim().isEmpty) return 'غير متاح';
    return value.toString();
  }

  String _statusLabel(Object? value) {
    if (value == true || value == 'passed') return 'ناجح';
    return switch (value) {
      'not-collected' => 'لم يُجمع بعد',
      'not-collected-on-physical-device' => 'لم يُختبر على جهاز فعلي',
      'not-collected-by-device-baseline' => 'بانتظار ملف الوسائط',
      'not-verified-on-physical-device' => 'بانتظار التحقق الميداني',
      'not-verified-across-force-stop' => 'لم يُختبر بعد الإيقاف القسري',
      'single-install-round-trip-only' => 'اختبار تثبيت واحد فقط',
      'failed' => 'فشل',
      'blocked' => 'محظور',
      _ => 'غير مكتمل',
    };
  }

  _EvidenceTone _statusTone(Object? value) {
    if (value == true || value == 'passed') return _EvidenceTone.success;
    if (value == 'failed' || value == 'blocked') return _EvidenceTone.failure;
    return _EvidenceTone.pending;
  }

  String _missingFields(Object? value) {
    if (value is! List || value.isEmpty) return 'لا توجد';
    const labels = <String, String>{
      'physicalDeviceMarkerCheck': 'مؤشر الجهاز',
      'manufacturer': 'الشركة المصنّعة',
      'model': 'الطراز',
      'androidRelease': 'إصدار Android',
      'androidSdk': 'مستوى API',
      'cpuCoreCount': 'أنوية المعالج',
      'totalMemoryBytes': 'إجمالي الذاكرة',
      'availableMemoryBytes': 'الذاكرة المتاحة',
      'processPssKb': 'ذاكرة التطبيق',
      'availableStorageBytes': 'التخزين المتاح',
      'appVersionName': 'إصدار التطبيق',
      'appVersionCode': 'رقم البناء',
    };
    return value.map((item) => labels[item] ?? item.toString()).join('، ');
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final baselineReady =
        report?['diagnosticBaselineStatus'] == 'ready-for-physical-media-tests';

    return Scaffold(
      appBar: AppBar(
        title: const Text('تشخيص الجهاز'),
        actions: [
          IconButton(
            tooltip: 'إعادة الفحص',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 28),
          children: [
            _buildOverview(context, report, baselineReady),
            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              _buildError(context),
            ],
            if (report != null) ...[
              const SizedBox(height: 16),
              _buildQuickMetrics(context, report),
              const SizedBox(height: 18),
              _sectionTitle(context, 'معلومات الجهاز'),
              _buildDeviceDetails(context, report),
              const SizedBox(height: 18),
              _sectionTitle(context, 'اختبارات الوسائط والجودة'),
              _EvidenceCard(
                rows: [
                  _EvidenceData(
                    'مجموعة فيديوهات العربية والإنجليزية',
                    report['mediaCorpusStatus'],
                  ),
                  _EvidenceData(
                    'دقة التفريغ وتوقيت الكلمات',
                    report['speechQualityStatus'],
                  ),
                  _EvidenceData(
                    'دقة المقاطع والتكرار وتتبع الوجه',
                    report['candidateQualityStatus'],
                  ),
                  _EvidenceData(
                    'فك الفيديو والصوت حتى نهاية الملف',
                    report['videoFullDecodeStatus'],
                  ),
                ],
                statusLabel: _statusLabel,
                statusTone: _statusTone,
              ),
              const SizedBox(height: 14),
              _sectionTitle(context, 'الأداء والاستقرار'),
              _EvidenceCard(
                rows: [
                  _EvidenceData(
                    'الأداء المستمر والحرارة والبطارية',
                    report['sustainedPerformanceStatus'],
                  ),
                  _EvidenceData(
                    'استعادة المهمة بعد موت العملية',
                    report['processDeathResumeStatus'],
                  ),
                  _EvidenceData(
                    'بقاء إذن الملفات بعد الإيقاف وإعادة الفتح',
                    report['safLifecycleStatus'],
                  ),
                ],
                statusLabel: _statusLabel,
                statusTone: _statusTone,
              ),
              const SizedBox(height: 14),
              _sectionTitle(context, 'الأمان والخصوصية'),
              _EvidenceCard(
                rows: [
                  _EvidenceData(
                    'اختبار التخزين الآمن المؤقت',
                    report['secureStorageRoundTrip'],
                  ),
                  _EvidenceData(
                    'حذف بيانات الاختبار المؤقتة',
                    report['secureStorageCanaryDeleted'],
                  ),
                  _EvidenceData(
                    'استعادة المفاتيح بعد النسخ أو إعادة التثبيت',
                    report['keystoreLifecycleStatus'],
                  ),
                  _EvidenceData(
                    'حظر الاتصال السحابي دون موافقة',
                    report['networkConsentEndToEndStatus'],
                  ),
                ],
                statusLabel: _statusLabel,
                statusTone: _statusTone,
              ),
              const SizedBox(height: 14),
              _buildTechnicalDetails(context, report),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _copyReport,
                icon: const Icon(Icons.copy_all_rounded),
                label: const Text('نسخ تقرير التشخيص JSON'),
              ),
              const SizedBox(height: 8),
              Text(
                'التقرير لا يتضمن ملفات الوسائط أو مفاتيح الحسابات.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOverview(
    BuildContext context,
    Map<String, Object?>? report,
    bool baselineReady,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isCandidate = report?['deviceClass'] == 'physical-candidate';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.fact_check_outlined, color: scheme.primary),
                Text(
                  'بوابة القبول الميداني',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                _StatePill(
                  label: report == null
                      ? 'بانتظار الفحص'
                      : baselineReady
                          ? 'الأساس جاهز'
                          : 'الأساس غير مكتمل',
                  tone: baselineReady
                      ? _EvidenceTone.success
                      : _EvidenceTone.pending,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              report == null
                  ? 'اجمع قياسات الجهاز لبدء التحقق.'
                  : isCandidate
                      ? 'الجهاز مرشح فعليًا وفق مؤشر النظام؛ التأكيد اليدوي ما زال مطلوبًا.'
                      : 'لم يثبت الفحص أن هذا جهاز فعلي.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'اعتماد المرحلة 10: غير مكتمل حتى تسجيل نتائج الوسائط والجهاز الفعلي.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تعذر جمع بيانات الجهاز',
                    style: TextStyle(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _error!,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: _loading ? null : _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMetrics(
    BuildContext context,
    Map<String, Object?> report,
  ) {
    final metrics = <_MetricData>[
      _MetricData(
        'RAM المتاحة',
        _memory(report['availableMemoryBytes']),
        Icons.memory_rounded,
      ),
      _MetricData(
        'ذاكرة التطبيق',
        report['processPssKb'] is num
            ? '${report['processPssKb']} KB'
            : 'غير متاح',
        Icons.data_usage_rounded,
      ),
      _MetricData(
        'مساحة التطبيق',
        _memory(report['availableStorageBytes']),
        Icons.storage_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560
            ? 3
            : constraints.maxWidth >= 340
                ? 2
                : 1;
        const gap = 10.0;
        final width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: _MetricCard(metric: metric),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDeviceDetails(
    BuildContext context,
    Map<String, Object?> report,
  ) {
    final missing = report['diagnosticMissingFields'];
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 14, 6),
        child: Column(
          children: [
            _DetailRow(
              label: 'الشركة والطراز',
              value:
                  '${_value(report['manufacturer'])} ${_value(report['model'])}',
            ),
            _DetailRow(
              label: 'إصدار Android',
              value:
                  '${_value(report['androidRelease'])} · API ${_value(report['androidSdk'])}',
            ),
            _DetailRow(
              label: 'أنوية المعالج',
              value: _value(report['cpuCoreCount']),
            ),
            _DetailRow(
              label: 'إصدار التطبيق',
              value:
                  '${_value(report['appVersionName'])} (${_value(report['appVersionCode'])})',
            ),
            _DetailRow(
              label: 'التحقق اليدوي من الجهاز',
              value:
                  report['physicalDeviceManualConfirmationStatus'] == 'verified'
                      ? 'تم التحقق'
                      : 'مطلوب',
              valueTone:
                  report['physicalDeviceManualConfirmationStatus'] == 'verified'
                      ? _EvidenceTone.success
                      : _EvidenceTone.pending,
            ),
            _DetailRow(
              label: 'ربط البناء بمصدره',
              value: report['buildIdentityPinned'] == true
                  ? 'SHA مثبت'
                  : 'بناء محلي أو غير محدد',
              valueTone: report['buildIdentityPinned'] == true
                  ? _EvidenceTone.success
                  : _EvidenceTone.pending,
            ),
            _DetailRow(
              label: 'SHA المصدر',
              value: _value(report['buildSha']),
              selectable: true,
            ),
            if (missing is List && missing.isNotEmpty)
              _DetailRow(
                label: 'بيانات أساسية ناقصة',
                value: _missingFields(missing),
                valueTone: _EvidenceTone.pending,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicalDetails(
    BuildContext context,
    Map<String, Object?> report,
  ) {
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 0),
          childrenPadding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 12),
          title: const Text('القياسات التقنية التفصيلية'),
          subtitle: const Text('افتحها عند الحاجة إلى مراجعة القيم الخام'),
          children: [
            _DetailRow(
              label: 'إجمالي RAM',
              value: _memory(report['totalMemoryBytes']),
            ),
            _DetailRow(
              label: 'حرارة البطارية',
              value: _temperature(report['batteryTemperatureTenthsC']),
            ),
            _DetailRow(
              label: 'مستوى البطارية',
              value: _battery(report['batteryPercent']),
            ),
            _DetailRow(
              label: 'الحالة الحرارية',
              value: _thermal(report['thermalStatus']),
            ),
            _DetailRow(
              label: 'الذاكرة الخاصة للعملية',
              value: report['processPrivateDirtyKb'] is num
                  ? '${report['processPrivateDirtyKb']} KB'
                  : 'غير متاح',
            ),
            _DetailRow(
              label: 'حالة الذاكرة المنخفضة',
              value: report['lowMemory'] == true ? 'نعم' : 'لا / غير متاح',
            ),
            _DetailRow(
              label: 'وقت جمع القياسات',
              value: _value(report['collectedAtUtc']),
              selectable: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(metric.icon, size: 19, color: scheme.primary),
            const SizedBox(height: 8),
            Text(
              metric.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              metric.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueTone,
    this.selectable = false,
  });

  final String label;
  final String value;
  final _EvidenceTone? valueTone;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final valueColor = switch (valueTone) {
      _EvidenceTone.success => scheme.secondary,
      _EvidenceTone.pending => scheme.tertiary,
      _EvidenceTone.failure => scheme.error,
      null => scheme.onSurface,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 6,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: selectable
                  ? SelectableText(
                      value,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: valueColor,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Text(
                      value,
                      textAlign: TextAlign.end,
                      softWrap: true,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: valueColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceData {
  const _EvidenceData(this.label, this.rawStatus);

  final String label;
  final Object? rawStatus;
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({
    required this.rows,
    required this.statusLabel,
    required this.statusTone,
  });

  final List<_EvidenceData> rows;
  final String Function(Object?) statusLabel;
  final _EvidenceTone Function(Object?) statusTone;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 14, 4),
        child: Column(
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0)
                Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Text(
                        rows[index].label,
                        softWrap: true,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 5,
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: _StatePill(
                          label: statusLabel(rows[index].rawStatus),
                          tone: statusTone(rows[index].rawStatus),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _EvidenceTone { success, pending, failure }

class _StatePill extends StatelessWidget {
  const _StatePill({required this.label, required this.tone});

  final String label;
  final _EvidenceTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (tone) {
      _EvidenceTone.success => scheme.secondary,
      _EvidenceTone.pending => scheme.tertiary,
      _EvidenceTone.failure => scheme.error,
    };

    return Container(
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        softWrap: true,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
