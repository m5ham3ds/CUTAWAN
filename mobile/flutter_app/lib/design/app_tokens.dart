import 'package:flutter/widgets.dart';

/// RAVEN23 spacing, radii and type scale, adapted to bundled Poppins.
abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  static double gutter(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet ? 24 : 16;

  static const rowGap = 24.0;
  static const headerGap = 8.0;
}

abstract final class AppRadii {
  static const card = 6.0;
  static const button = 6.0;
  static const hero = 10.0;
  static const chip = 18.0;
  static const sheet = 16.0;
}

abstract final class AppBreakpoints {
  static const tablet = 700.0;
  static const wide = 1000.0;
  static const tabletShortestSide = 600.0;

  static bool isTablet(BuildContext context) {
    final view = View.maybeOf(context);
    if (view == null) return false;
    final size = view.physicalSize / view.devicePixelRatio;
    return size.shortestSide >= tabletShortestSide;
  }
}

abstract final class AppType {
  static const bold = 'Poppins';
  static const semiBold = 'Poppins';
  static const regular = 'Poppins';

  static const heroTitle = TextStyle(
    fontFamily: bold,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 34 / 30,
    letterSpacing: -0.6,
  );
  static const pageTitle = TextStyle(
    fontFamily: bold,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 32 / 28,
    letterSpacing: -0.5,
  );
  static const sectionHeader = TextStyle(
    fontFamily: semiBold,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 24 / 18,
    letterSpacing: -0.1,
  );
  static const cardTitle = TextStyle(
    fontFamily: semiBold,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 18 / 14,
  );
  static const metadata = TextStyle(
    fontFamily: regular,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
  );
  static const kicker = TextStyle(
    fontFamily: semiBold,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
  );
  static const body = TextStyle(
    fontFamily: regular,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
  );
  static const button = TextStyle(
    fontFamily: semiBold,
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );

  static TextStyle scaled(BuildContext context, TextStyle style) =>
      MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet
          ? style.copyWith(fontSize: (style.fontSize ?? 14) * 1.1)
          : style;
}
