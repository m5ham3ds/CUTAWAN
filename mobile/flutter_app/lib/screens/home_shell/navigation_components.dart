import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef CutawanNavigationDestination = ({
  String label,
  IconData icon,
  IconData selected,
  String hint,
});

class CutawanTopBar extends StatelessWidget {
  const CutawanTopBar({
    super.key,
    required this.onModels,
    required this.onRefresh,
    required this.onDiagnostics,
    required this.onSettings,
  });
  final VoidCallback onModels;
  final Future<void> Function() onRefresh;
  final VoidCallback onDiagnostics;
  final VoidCallback onSettings;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 390;
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 8 : 20, 10, compact ? 8 : 20, 10),
      child: Row(children: [
        Container(width: compact ? 34 : 40, height: compact ? 34 : 40, decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(13), boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 6))]), child: Icon(Icons.auto_awesome_rounded, color: scheme.onPrimary, size: 21)),
        SizedBox(width: compact ? 8 : 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('CUTAWAN', maxLines: 1, style: theme.textTheme.titleMedium?.copyWith(letterSpacing: 0.4, fontWeight: FontWeight.w900, fontSize: compact ? 12 : 17)),
          if (!compact)
            Text('AI CREATOR STUDIO', maxLines: 1, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0.7, fontSize: 8)),
        ])),
        if (!compact) ...[
          _TopBarAction(icon: Icons.refresh_rounded, tooltip: 'تحديث المشاريع', onTap: onRefresh),
          const SizedBox(width: 8),
        ],
        _TopBarAction(icon: Icons.settings_outlined, tooltip: 'الإعدادات', onTap: onSettings),
        _TopBarAction(icon: Icons.monitor_heart_outlined, tooltip: 'تشخيص الجهاز', onTap: onDiagnostics),
        _TopBarAction(icon: Icons.memory_rounded, tooltip: 'مركز النماذج', onTap: onModels, accent: true),
      ]),
    );
  }
}

class _TopBarAction extends StatelessWidget {
  const _TopBarAction({required this.icon, required this.tooltip, required this.onTap, this.accent = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool accent;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(message: tooltip, child: Material(
      color: accent ? scheme.primary.withValues(alpha: 0.12) : scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: accent ? scheme.primary.withValues(alpha: 0.28) : scheme.outlineVariant)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        child: SizedBox(width: 48, height: 48, child: Icon(icon, size: 19, color: accent ? scheme.primary : scheme.onSurface)),
      ),
    ));
  }
}

class CutawanNavigationBar extends StatelessWidget {
  const CutawanNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
    required this.animation,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<CutawanNavigationDestination> destinations;
  final Animation<double> animation;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safePadding = MediaQuery.paddingOf(context);
    final bottom = safePadding.bottom;
    final compact = MediaQuery.sizeOf(context).width < 390;
    final horizontalMargin = compact ? 4.0 : 14.0;
    return Container(
      margin: EdgeInsets.fromLTRB(
        horizontalMargin + safePadding.left,
        0,
        horizontalMargin + safePadding.right,
        bottom > 0 ? bottom + 8 : 13,
      ),
      padding: EdgeInsets.fromLTRB(compact ? 1 : 7, 6, compact ? 1 : 7, 6),
      decoration: BoxDecoration(color: scheme.surfaceContainer.withValues(alpha: 0.96), borderRadius: BorderRadius.circular(24), border: Border.all(color: scheme.outlineVariant), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.24), blurRadius: 28, offset: const Offset(0, 10))]),
      child: ClipRect(child: Row(children: List.generate(destinations.length, (index) {
        final item = destinations[index];
        final selected = index == selectedIndex;
        return Expanded(child: Semantics(button: true, selected: selected, label: item.hint, child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(color: selected ? scheme.primary.withValues(alpha: 0.13) : Colors.transparent, borderRadius: BorderRadius.circular(18)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedScale(scale: selected ? 1.08 : 1, duration: const Duration(milliseconds: 220), curve: Curves.easeOutBack, child: Icon(selected ? item.selected : item.icon, size: 22, color: selected ? scheme.primary : scheme.onSurfaceVariant)),
              const SizedBox(height: 5),
              AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 180), style: TextStyle(fontSize: compact ? 9 : 10, fontWeight: selected ? FontWeight.w900 : FontWeight.w600, color: selected ? scheme.primary : scheme.onSurfaceVariant), child: Text(item.label)),
            ]),
          ),
        )));
      }))),
    );
  }
}
