import 'package:flutter/material.dart';

/// Colour tokens transcribed from the Claude Design handoff
/// (`Scandy Redesign.dc.html`). Every value here appears literally in that
/// file — when the design changes, change these and nothing else.
@immutable
class ScandyColors extends ThemeExtension<ScandyColors> {
  const ScandyColors({
    required this.page,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.divider,
    required this.dividerStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.iconMuted,
    required this.accent,
    required this.accentPressed,
    required this.accentSoft,
    required this.onAccentSoft,
    required this.onAccent,
    required this.positive,
    required this.positiveSoft,
    required this.onPositiveSoft,
    required this.negative,
    required this.negativeSoft,
    required this.disabled,
    required this.segmentTrack,
    required this.segmentSelected,
    required this.track,
    required this.trackRecurring,
  });

  /// App background behind the cards.
  final Color page;

  /// Cards, bottom nav, sheets.
  final Color surface;

  /// Icon tiles and neutral chips sitting on [surface].
  final Color surfaceMuted;

  /// 1px card outline.
  final Color border;

  /// Hairline between rows inside a card.
  final Color divider;

  /// Slightly heavier rule used above the in/spent/due breakdown.
  final Color dividerStrong;

  final Color textPrimary;
  final Color textSecondary;

  /// Icon glyphs inside neutral tiles.
  final Color textTertiary;

  final Color iconMuted;

  final Color accent;
  final Color accentPressed;

  /// Pill background behind "24 days left".
  final Color accentSoft;
  final Color onAccentSoft;

  /// Foreground on a filled accent surface (white in light, near-black in dark).
  final Color onAccent;

  final Color positive;
  final Color positiveSoft;
  final Color onPositiveSoft;
  final Color negative;

  /// Tile behind a negative figure — a credit card in the accounts list.
  /// The sections design is light-only, so the dark value is derived to sit
  /// against [negative] the way [positiveSoft] sits against [positive].
  final Color negativeSoft;

  /// A control that cannot be used, e.g. the "next month" chevron on the
  /// current month.
  final Color disabled;

  /// Segmented control (Settings > Theme): the inset track, and the raised
  /// pill marking the current choice. Light raises with white on warm grey;
  /// dark inverts that, since a lighter chip reads as raised there.
  final Color segmentTrack;
  final Color segmentSelected;

  /// Unspent remainder of the safe-to-spend bar.
  final Color track;

  /// "Recurring due" segment of that bar.
  final Color trackRecurring;

  static const light = ScandyColors(
    page: Color(0xFFF4F1EC),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF4F1EC),
    border: Color(0xFFE4DED5),
    divider: Color(0xFFF3EEE8),
    dividerStrong: Color(0xFFEFE9E1),
    textPrimary: Color(0xFF24201C),
    textSecondary: Color(0xFF7A716A),
    textTertiary: Color(0xFF5C544E),
    iconMuted: Color(0xFF9A918A),
    accent: Color(0xFFFF6B00),
    accentPressed: Color(0xFFE45F00),
    accentSoft: Color(0xFFFFF0E3),
    onAccentSoft: Color(0xFFC25200),
    onAccent: Color(0xFFFFFFFF),
    positive: Color(0xFF0F8A5F),
    positiveSoft: Color(0xFFE7F5EF),
    onPositiveSoft: Color(0xFF0F6B4B),
    negative: Color(0xFFC4442C),
    negativeSoft: Color(0xFFFBEBE7),
    disabled: Color(0xFFC9C1B9),
    segmentTrack: Color(0xFFF4F1EC),
    segmentSelected: Color(0xFFFFFFFF),
    track: Color(0xFFEFE9E1),
    trackRecurring: Color(0xFFFFC49B),
  );

  static const dark = ScandyColors(
    page: Color(0xFF141210),
    surface: Color(0xFF1E1B19),
    surfaceMuted: Color(0xFF272320),
    border: Color(0xFF2E2A26),
    divider: Color(0xFF262220),
    dividerStrong: Color(0xFF2E2A26),
    textPrimary: Color(0xFFF0EBE5),
    textSecondary: Color(0xFF9A918A),
    textTertiary: Color(0xFFB5ADA5),
    iconMuted: Color(0xFF9A918A),
    accent: Color(0xFFFF7A1A),
    accentPressed: Color(0xFFE45F00),
    accentSoft: Color(0xFF3A2110),
    onAccentSoft: Color(0xFFFFB077),
    onAccent: Color(0xFF241505),
    positive: Color(0xFF34D399),
    positiveSoft: Color(0xFF12291F),
    onPositiveSoft: Color(0xFF34D399),
    negative: Color(0xFFFF8B72),
    negativeSoft: Color(0xFF2E1712),
    disabled: Color(0xFF4E4740),
    segmentTrack: Color(0xFF141210),
    segmentSelected: Color(0xFF272320),
    track: Color(0xFF2E2A26),
    trackRecurring: Color(0xFF8A4A18),
  );

  @override
  ScandyColors copyWith({
    Color? page,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? divider,
    Color? dividerStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? iconMuted,
    Color? accent,
    Color? accentPressed,
    Color? accentSoft,
    Color? onAccentSoft,
    Color? onAccent,
    Color? positive,
    Color? positiveSoft,
    Color? onPositiveSoft,
    Color? negative,
    Color? negativeSoft,
    Color? disabled,
    Color? segmentTrack,
    Color? segmentSelected,
    Color? track,
    Color? trackRecurring,
  }) {
    return ScandyColors(
      page: page ?? this.page,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      dividerStrong: dividerStrong ?? this.dividerStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      iconMuted: iconMuted ?? this.iconMuted,
      accent: accent ?? this.accent,
      accentPressed: accentPressed ?? this.accentPressed,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccentSoft: onAccentSoft ?? this.onAccentSoft,
      onAccent: onAccent ?? this.onAccent,
      positive: positive ?? this.positive,
      positiveSoft: positiveSoft ?? this.positiveSoft,
      onPositiveSoft: onPositiveSoft ?? this.onPositiveSoft,
      negative: negative ?? this.negative,
      negativeSoft: negativeSoft ?? this.negativeSoft,
      disabled: disabled ?? this.disabled,
      segmentTrack: segmentTrack ?? this.segmentTrack,
      segmentSelected: segmentSelected ?? this.segmentSelected,
      track: track ?? this.track,
      trackRecurring: trackRecurring ?? this.trackRecurring,
    );
  }

  @override
  ScandyColors lerp(ThemeExtension<ScandyColors>? other, double t) {
    if (other is! ScandyColors) return this;
    return ScandyColors(
      page: Color.lerp(page, other.page, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      dividerStrong: Color.lerp(dividerStrong, other.dividerStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      iconMuted: Color.lerp(iconMuted, other.iconMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentPressed: Color.lerp(accentPressed, other.accentPressed, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccentSoft: Color.lerp(onAccentSoft, other.onAccentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      positiveSoft: Color.lerp(positiveSoft, other.positiveSoft, t)!,
      onPositiveSoft: Color.lerp(onPositiveSoft, other.onPositiveSoft, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      negativeSoft: Color.lerp(negativeSoft, other.negativeSoft, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      segmentTrack: Color.lerp(segmentTrack, other.segmentTrack, t)!,
      segmentSelected: Color.lerp(segmentSelected, other.segmentSelected, t)!,
      track: Color.lerp(track, other.track, t)!,
      trackRecurring: Color.lerp(trackRecurring, other.trackRecurring, t)!,
    );
  }
}

/// Corner radii used by the design, keyed by the element they belong to.
abstract final class ScandyRadius {
  static const card = 20.0; // Safe-to-spend card (mobile)
  static const list = 18.0; // Recent-transactions container
  static const sheet = 22.0; // Add sheet, and the FAB's squircle
  static const tile = 12.0; // 38px category icon tile
  static const tileLarge = 14.0; // 44px sheet icon tile / search button
  static const row = 16.0; // Tappable row inside the add sheet
  static const pill = 999.0;
}

/// Convenience accessor so widgets read `context.scandy.accent`.
extension ScandyColorsX on BuildContext {
  ScandyColors get scandy => Theme.of(this).extension<ScandyColors>()!;
}
