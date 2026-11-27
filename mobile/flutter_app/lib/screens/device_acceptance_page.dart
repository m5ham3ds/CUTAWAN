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

  static const _supportReportFields = <String>[
    'collectedAtUtc',
    'manufacturer',
    'model',
    'androidRelease',
    'androidSdk',
    'cpuCoreCount',
    'totalMemoryBytes',
    'availableMemoryBytes',
    'processPssKb',
    'availableStorageBytes',
    'batteryPercent',
    'batteryTemperatureTenthsC',
    'thermalStatus',
    'lowMemory',
    'appVersionName',
    'appVersionCode',
  ];

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

    final supportReport = <String, Object?>{
      'schema': 'org.cutawan.device-support-report',
      'schemaVersion': 1,
      for (final field in _supportReportFields)
        if (report.containsKey(field)) field: report[field],
    };

    try {
      await Clipboard.setData(
        ClipboardData(
          text: const JsonEncoder.withIndent('  ').convert(supportReport),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نُسخ تقرير الجهاز')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر نسخ التقرير: ' + error.toString())),
      );
    }
  }

  String _memory(Object? bytes) {
    if (bytes is! num || !bytes.isFinite || bytes < 0) return 'غير متاح';
    final gib = bytes / (1024 * 1024 * 1024);
    return gib >= 1
        ? gib.toStringAsFixed(2) + ' GB'
        : (bytes / (1024 * 1024)).toStringAsFixed(0) + ' MB';
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
    return value.round().toString() + '%';
  }

  String _temperature(Object? value) {
    if (value is! num || value < 0) return 'غير متاح';
    return (value / 10).toStringAsFixed(1) + ' °C';
  }

  String _value(Object? value) {
    if (value == null || value.toString().trim().isEmpty) return 'غير متاح';
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 28),
          children: [
            if (_loading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 14),
            ],
            if (_error != null) ...[
              _buildError(context),
              const SizedBox(height: 12),
            ],
            if (report != null) ...[
              _buildQuickMetrics(context, report),
              const SizedBox(height: 18),
              _sectionTitle(context, 'معلومات الجهاز'),
              _buildDeviceDetails(report),
              const SizedBox(height: 18),
              _sectionTitle(context, 'البطارية والذاكرة'),
              _buildResourceDetails(report),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _copyReport,
                icon: const Icon(Icons.copy_all_rounded),
                label: const Text('نسخ تقرير الدعم'),
              ),
              const SizedBox(height: 8),
              Text(
                'لا يتضمن التقرير ملفات الفيديو أو مفاتيح الحسابات.',
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
                    'تعذّر جمع بيانات الجهاز',
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
            ? report['processPssKb'].toString() + ' KB'
            : 'غير متاح',
        Icons.data_usage_rounded,
      ),
      _MetricData(
        'التخزين المتاح',
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

  Widget _buildDeviceDetails(Map<String, Object?> report) {
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 14, 6),
        child: Column(
          children: [
            _DetailRow(
              label: 'الشركة والطراز',
              value:
                  _value(report['manufacturer']) + ' ' + _value(report['model']),
            ),
            _DetailRow(
              label: 'إصدار Android',
              value: _value(report['androidRelease']) +
                  ' · API ' +
                  _value(report['androidSdk']),
            ),
            _DetailRow(
              label: 'أنوية المعالج',
              value: _value(report['cpuCoreCount']),
            ),
            _DetailRow(
              label: 'إصدار التطبيق',
              value: _value(report['appVersionName']) +
                  ' (' +
                  _value(report['appVersionCode']) +
                  ')',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceDetails(Map<String, Object?> report) {
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 14, 6),
        child: Column(
          children: [
            _DetailRow(
              label: 'إجمالي RAM',
              value: _memory(report['totalMemoryBytes']),
            ),
            _DetailRow(
              label: 'مستوى البطارية',
              value: _battery(report['batteryPercent']),
            ),
            _DetailRow(
              label: 'حرارة البطارية',
              value: _temperature(report['batteryTemperatureTenthsC']),
            ),
            _DetailRow(
              label: 'الحالة الحرارية',
              value: _thermal(report['thermalStatus']),
            ),
            _DetailRow(
              label: 'حالة الذاكرة المنخفضة',
              value: report['lowMemory'] == null
                  ? 'غير متاح'
                  : report['lowMemory'] == true
                      ? 'نعم'
                      : 'لا',
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
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 350) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    softWrap: true,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          }
          return Row(
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
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    softWrap: true,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
