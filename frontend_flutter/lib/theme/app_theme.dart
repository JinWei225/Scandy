import 'package:flutter/material.dart';

import 'tokens.dart';

/// Bundled in `assets/fonts` and declared in pubspec.yaml, so the app renders
/// identically offline. Referenced by name rather than through google_fonts,
/// which fetches at runtime and falls back to the system face when there is no
/// network — silently changing every metric the design specifies.
const scandyFontFamily = 'PlusJakartaSans';

/// The design sets `font-variant-numeric: tabular-nums` on every figure
/// (`.num`). Without it the big safe-to-spend number jitters as it animates or
/// refreshes, because proportional digits have different widths.
const tabularFigures = <FontFeature>[FontFeature.tabularFigures()];

/// Text styles lifted from the mobile frames of the handoff. `letter-spacing`
/// there is in `em`, so each value below is `em * fontSize` in logical pixels.
abstract final class ScandyText {
  static TextStyle _base({
    required double size,
    required FontWeight weight,
    double? letterSpacing,
    double? height,
    bool tabular = false,
  }) {
    return TextStyle(
      fontFamily: scandyFontFamily,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: tabular ? tabularFigures : null,
    );
  }

  /// "Good evening" — 20px/800, -0.03em.
  static final greeting = _base(size: 20, weight: FontWeight.w800, letterSpacing: -0.6);

  /// "Saturday, 6 September" — 13px/400.
  static final greetingMeta = _base(size: 13, weight: FontWeight.w400);

  /// "SAFE TO SPEND · SEP" — 11.5px/700, 0.12em, uppercased by the caller.
  static final cardEyebrow =
      _base(size: 11.5, weight: FontWeight.w700, letterSpacing: 1.38);

  /// "24 days left" pill.
  static final pill = _base(size: 11.5, weight: FontWeight.w700);

  /// "RM 1,666.70" — 42px/800, -0.045em, line-height 1.
  static final heroAmount = _base(
    size: 42,
    weight: FontWeight.w800,
    letterSpacing: -1.89,
    height: 1,
    tabular: true,
  );

  /// "RM 69.44 a day for the rest of the month".
  static final heroCaption = _base(size: 13, weight: FontWeight.w400);
  static final heroCaptionStrong = _base(size: 13, weight: FontWeight.w700);

  /// "IN" / "SPENT" / "DUE" — 10.5px/700, 0.08em.
  static final breakdownLabel =
      _base(size: 10.5, weight: FontWeight.w700, letterSpacing: 0.84);

  /// The figure under each of those labels.
  static final breakdownValue =
      _base(size: 14.5, weight: FontWeight.w800, tabular: true);

  /// "Recent" — 16px/800, -0.02em.
  static final sectionTitle =
      _base(size: 16, weight: FontWeight.w800, letterSpacing: -0.32);

  /// "See all".
  static final link = _base(size: 13, weight: FontWeight.w700);

  /// Transaction description — 14.5px/700.
  static final rowTitle = _base(size: 14.5, weight: FontWeight.w700);

  /// "Groceries · 14:22" — 12px/400.
  static final rowMeta = _base(size: 12, weight: FontWeight.w400, tabular: true);

  /// "−86.40" — 15.5px/800, -0.02em.
  static final rowAmount = _base(
    size: 15.5,
    weight: FontWeight.w800,
    letterSpacing: -0.31,
    tabular: true,
  );

  /// Bottom-nav label. The active tab is 700, the rest 600.
  static final navLabelActive = _base(size: 10.5, weight: FontWeight.w700);
  static final navLabel = _base(size: 10.5, weight: FontWeight.w600);

  /// The "ADD" wordmark under the plus glyph — 8.5px/800, 0.06em.
  static final fabLabel =
      _base(size: 8.5, weight: FontWeight.w800, letterSpacing: 0.51);

  /// "ADD A TRANSACTION" sheet header — 11px/700, 0.12em.
  static final sheetEyebrow =
      _base(size: 11, weight: FontWeight.w700, letterSpacing: 1.32);

  /// "Scan a receipt" — 15.5px/700.
  static final sheetItemTitle = _base(size: 15.5, weight: FontWeight.w700);

  /// "Snap it and we'll fill in the details" — 12.5px/400.
  static final sheetItemSubtitle = _base(size: 12.5, weight: FontWeight.w400);

  // ---- Sections (`Scandy Sections.dc.html`) ----

  /// "MONEY IN" / "SPENT" on the Summary stat cards — 10.5px/700, 0.1em.
  static final statLabel =
      _base(size: 10.5, weight: FontWeight.w700, letterSpacing: 1.05);

  /// The figure on a Summary stat card — 19px/800, -0.035em.
  static final statValue = _base(
    size: 19,
    weight: FontWeight.w800,
    letterSpacing: -0.665,
    tabular: true,
  );

  /// "September 2026" in the month stepper — 14.5px/700.
  static final monthLabel = _base(size: 14.5, weight: FontWeight.w700);

  /// "RM 8,412.55" total-balance hero — 34px/800, -0.045em, line-height 1.
  static final bigBalance = _base(
    size: 34,
    weight: FontWeight.w800,
    letterSpacing: -1.53,
    height: 1,
    tabular: true,
  );

  /// Account name / settings row label — 15px/700.
  static final rowTitleLarge = _base(size: 15, weight: FontWeight.w700);

  /// "Bank · 32 transactions" — 12px/400.
  static final rowMetaSmall = _base(size: 12, weight: FontWeight.w400);

  /// "Day 12 · in 6 days" — 12px/600, coloured by urgency.
  static final rowMetaStrong = _base(size: 12, weight: FontWeight.w600);

  /// Account balance — 16px/800, -0.025em.
  static final accountAmount = _base(
    size: 16,
    weight: FontWeight.w800,
    letterSpacing: -0.4,
    tabular: true,
  );

  /// "30%" beside a category bar — 11.5px/700.
  static final percentLabel =
      _base(size: 11.5, weight: FontWeight.w700, tabular: true);

  /// Count chip in Settings ("6" expense categories) — 12.5px/700.
  static final countPill =
      _base(size: 12.5, weight: FontWeight.w700, tabular: true);

  /// Theme segmented control — 12.5px, 700 when selected, 600 otherwise.
  static final segmentLabelActive = _base(size: 12.5, weight: FontWeight.w700);
  static final segmentLabel = _base(size: 12.5, weight: FontWeight.w600);
}

/// The desktop frames run a size larger than the phone ones — a 25px page
/// title where mobile has 20px, 58px on the hero, and a table voice that has
/// no mobile counterpart at all. They are a separate scale rather than
/// overrides so [ScandyText] keeps meaning "the mobile frames", which is what
/// the goldens assert against.
abstract final class ScandyDesktopText {
  static TextStyle _base({
    required double size,
    required FontWeight weight,
    double? letterSpacing,
    double? height,
    bool tabular = false,
  }) =>
      TextStyle(
        fontFamily: scandyFontFamily,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: height,
        fontFeatures: tabular ? tabularFigures : null,
      );

  /// "Scandy" in the sidebar — 19px/800, -0.03em.
  static final brand =
      _base(size: 19, weight: FontWeight.w800, letterSpacing: -0.57);

  /// Sidebar destination, 14.5px; 700 on the active one, 600 otherwise.
  static final navItemActive = _base(size: 14.5, weight: FontWeight.w700);
  static final navItem = _base(size: 14.5, weight: FontWeight.w600);

  /// "Good evening" / "Monthly summary" — 25px/800, -0.03em.
  static final pageTitle =
      _base(size: 25, weight: FontWeight.w800, letterSpacing: -0.75);

  /// "Where your money went" under the title — 14px/400.
  static final pageSubtitle = _base(size: 14, weight: FontWeight.w400);

  /// "Scan receipt" / "Add account" — 14.5px/700.
  static final buttonLabel = _base(size: 14.5, weight: FontWeight.w700);

  /// Card heading inside a panel — 17px/800, -0.02em.
  static final cardTitle =
      _base(size: 17, weight: FontWeight.w800, letterSpacing: -0.34);

  /// "DESCRIPTION" / "MONEY IN" — 11px/700, 0.1em, uppercased by the caller.
  static final tableHeader =
      _base(size: 11, weight: FontWeight.w700, letterSpacing: 1.1);

  /// Slightly larger eyebrow — "TOTAL BALANCE" over the big figure.
  static final eyebrow =
      _base(size: 12, weight: FontWeight.w700, letterSpacing: 1.44);

  /// "Jaya Grocer" in a table row — 15px/700.
  static final cellTitle = _base(size: 15, weight: FontWeight.w700);

  /// Account rows run a half-point larger than transaction rows.
  static final cellTitleLarge = _base(size: 15.5, weight: FontWeight.w700);

  /// "6 Sep · 14:22 · Maybank" — 12.5px/400.
  static final cellMeta = _base(size: 12.5, weight: FontWeight.w400, tabular: true);
  static final cellMetaStrong =
      _base(size: 12.5, weight: FontWeight.w600, tabular: true);

  /// "−86.40" in a table row — 16px/800, -0.02em.
  static final cellAmount = _base(
    size: 16,
    weight: FontWeight.w800,
    letterSpacing: -0.32,
    tabular: true,
  );

  /// "RM 6,210.40" on the Accounts table — 19px/800, -0.03em.
  static final cellAmountLarge = _base(
    size: 19,
    weight: FontWeight.w800,
    letterSpacing: -0.57,
    tabular: true,
  );

  /// "Groceries" pill inside a row — 12.5px/600.
  static final chip = _base(size: 12.5, weight: FontWeight.w600);

  /// "Day 12" — a plain figure cell.
  static final cellPlain = _base(size: 14, weight: FontWeight.w600, tabular: true);

  /// Stat card: "RM 4,850.00" at 24px/800 over an 11px label and a 12.5px note.
  static final statValue = _base(
    size: 24,
    weight: FontWeight.w800,
    letterSpacing: -0.84,
    tabular: true,
  );
  static final statMeta = _base(size: 12.5, weight: FontWeight.w400);

  /// "RM 8,412.55" in the sidebar card — 21px/800.
  static final sidebarBalance = _base(
    size: 21,
    weight: FontWeight.w800,
    letterSpacing: -0.63,
    tabular: true,
  );

  /// The Accounts / Recurring header figure — 40px/800, -0.045em.
  static final bigFigure = _base(
    size: 40,
    weight: FontWeight.w800,
    letterSpacing: -1.8,
    height: 1,
    tabular: true,
  );

  /// The safe-to-spend hero — 58px/800, -0.045em, line-height 1.
  static final hero = _base(
    size: 58,
    weight: FontWeight.w800,
    letterSpacing: -2.61,
    height: 1,
    tabular: true,
  );

  /// "That's RM 69.44 a day…" under the hero.
  static final heroCaption = _base(size: 14, weight: FontWeight.w400);
  static final heroCaptionStrong = _base(size: 14, weight: FontWeight.w700);

  /// Legend under the hero bar — "Spent 60%".
  static final legend = _base(size: 12.5, weight: FontWeight.w400);

  /// The action cards beside the hero — 17px/800 title, 13px subtitle.
  static final actionTitle =
      _base(size: 17, weight: FontWeight.w800, letterSpacing: -0.34);
  static final actionSubtitle = _base(size: 13, weight: FontWeight.w400);

  /// "24 days left" / "6 categories" pills.
  static final pill = _base(size: 12, weight: FontWeight.w700);

  /// The month stepper label — 14.5px/700.
  static final monthLabel = _base(size: 14.5, weight: FontWeight.w700);
}

ThemeData buildScandyTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? ScandyColors.dark : ScandyColors.light;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: c.page,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
    ).copyWith(
      primary: c.accent,
      onPrimary: c.onAccent,
      surface: c.surface,
      onSurface: c.textPrimary,
      error: c.negative,
    ),
    fontFamily: scandyFontFamily,
    textTheme: ThemeData(brightness: brightness)
        .textTheme
        .apply(
          fontFamily: scandyFontFamily,
          bodyColor: c.textPrimary,
          displayColor: c.textPrimary,
        ),
    extensions: [c],
    splashFactory: InkSparkle.splashFactory,
  );
}
