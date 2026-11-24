import 'package:flutter/material.dart';

/// The crop viewport shared by the production Clip Editor and pixel-parity tests.
///
/// Keep this as the single FittedBox implementation for preview crop geometry:
/// native export applies the corresponding normalized crop rectangle in Media3.
class ClipPreviewViewport extends StatelessWidget {
  const ClipPreviewViewport({
    required this.fit,
    required this.alignment,
    required this.child,
    super.key,
  });

  final BoxFit fit;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: fit,
        alignment: alignment,
        child: child,
      );
}
