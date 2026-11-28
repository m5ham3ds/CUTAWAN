import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../l10n/app_strings.dart';

typedef CutawanNavigationDestination = ({
  String label,
  IconData icon,
  IconData selected,
  String hint,
});

class CutawanTopBar extends StatelessWidget {
  const CutawanTopBar({
    super.key,
    required this.onRefresh,
    this.onMenu,
  });

  final Future<void> Function() onRefresh;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final compact = MediaQuery.sizeOf(context).width < 390;
    final gutter = AppSpace.gutter(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 8),
      child: Row(
        children: [
          if (onMenu != null)
            IconButton(
              key: const ValueKey('cutawan-open-drawer'),
              tooltip: cutawanText(context, 'القائمة'),
              onPressed: onMenu,
              icon: const Icon(Icons.menu_rounded),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CUTAWAN',
                  maxLines: 1,
                  style: AppType.sectionHeader.copyWith(
                    color: palette.foreground,
                    letterSpacing: 0.3,
                  ),
                ),
                if (!compact)
                  Text(
                    'AI CREATOR STUDIO',
                    maxLines: 1,
                    style: AppType.kicker.copyWith(
                      color: palette.mutedText,
                      fontSize: 9,
                      letterSpacing: 1.0,
                    ),
                  ),
              ],
            ),
          ),
          if (!compact)
            IconButton(
              tooltip: cutawanText(context, 'تحديث المشاريع'),
              onPressed: () => onRefresh(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          Image.asset(
            'assets/cutawan_logo.jpg',
            key: const ValueKey('cutawan-topbar-logo'),
            width: compact ? 30 : 34,
            height: compact ? 30 : 34,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
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

  static const double height = 60;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations;
    final bottom = media.padding.bottom;

    final bar = DecoratedBox(
      decoration: BoxDecoration(
        color: reduceMotion ? palette.page : palette.scrim(0.94),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: media.padding.left,
          right: media.padding.right,
          bottom: bottom,
        ),
        child: SizedBox(
          height: height,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Row(
              children: [
                for (var index = 0; index < destinations.length; index++)
                  Expanded(
                    child: _NavigationItem(
                      destination: destinations[index],
                      selected: index == selectedIndex,
                      onTap: () => onSelected(index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (reduceMotion) return bar;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: bar,
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final CutawanNavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = selected ? palette.foreground : palette.mutedText;
    void activate() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: destination.hint,
      onTap: activate,
      excludeSemantics: true,
      child: InkWell(
        onTap: activate,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? destination.selected : destination.icon,
                  size: 24,
                  color: color,
                ),
                const SizedBox(height: 3),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.metadata.copyWith(
                    fontSize: 11,
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class CutawanNavigationDrawer extends StatelessWidget {
  const CutawanNavigationDrawer({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.onSelect,
    required this.onSettings,
    required this.onDiagnostics,
    required this.onModels,
  });

  final int selectedIndex;
  final List<CutawanNavigationDestination> destinations;
  final ValueChanged<int> onSelect;
  final VoidCallback onSettings;
  final VoidCallback onDiagnostics;
  final VoidCallback onModels;

  void _closeAndRun(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    final width = MediaQuery.sizeOf(context).width;
    return Drawer(
      width: width < 360 ? width - 36 : 320,
      backgroundColor: scheme.surface,
      elevation: 0,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/cutawan_logo.jpg',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CUTAWAN', style: AppType.sectionHeader.copyWith(color: palette.foreground)),
                          const SizedBox(height: 3),
                          Text(
                            cutawanText(context, 'AI CREATOR STUDIO'),
                            style: AppType.kicker.copyWith(color: palette.mutedText, letterSpacing: 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 20, end: 20, bottom: 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  cutawanText(context, 'مساحة العمل'),
                  style: AppType.kicker.copyWith(color: palette.mutedText, letterSpacing: 1.1),
                ),
              ),
            ),
            for (var index = 0; index < destinations.length; index++)
              _CutawanDrawerItem(
                icon: destinations[index].selected,
                label: destinations[index].label,
                selected: selectedIndex == index,
                onTap: () => _closeAndRun(context, () => onSelect(index)),
