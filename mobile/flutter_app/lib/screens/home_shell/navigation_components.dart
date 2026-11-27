import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';

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
    required this.onSettings,
  });

  final Future<void> Function() onRefresh;
  final VoidCallback onSettings;

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
          Icon(
            Icons.auto_awesome_rounded,
            color: theme.colorScheme.primary,
            size: compact ? 24 : 28,
          ),
          const SizedBox(width: 10),
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
              tooltip: 'تحديث المشاريع',
              onPressed: () => onRefresh(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          IconButton(
            tooltip: 'الإعدادات',
            onPressed: () {
              HapticFeedback.selectionClick();
              onSettings();
            },
            icon: const Icon(Icons.settings_outlined),
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
    return Semantics(
      button: true,
      selected: selected,
      label: destination.hint,
      excludeSemantics: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
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
