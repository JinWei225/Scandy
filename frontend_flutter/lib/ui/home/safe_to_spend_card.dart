import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/month_summary.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../util/formatting.dart';

/// The hero card: "Safe to spend · Sep".
///
/// Geometry is taken from the mobile frame of the handoff — 20px radius, 20px
/// padding, 16px between blocks, a 9px bar.
class SafeToSpendCard extends StatelessWidget {
  const SafeToSpendCard({
    super.key,
    required this.summary,
    required this.now,
    this.showBreakdown = true,
  });

  final MonthSummary summary;
  final DateTime now;

  /// `showBreakdown` prop from the design (default true).
  final bool showBreakdown;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final perDay = summary.perDay;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(ScandyRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context),
          const SizedBox(height: 16),
          Text(
            formatRinggit(summary.safeToSpendCents / 100),
            // Red once it goes negative, matching the desktop hero. In the
            // accent colour a "RM −5.05" reads at a glance like any other
            // figure on the card, minus sign and all.
            style: ScandyText.heroAmount
                .copyWith(color: summary.isOverspent ? c.negative : c.accent),
          ),
          if (perDay != null) ...[
            const SizedBox(height: 8),
            _perDayCaption(context, perDay),
          ] else if (summary.isOverspent) ...[
            const SizedBox(height: 8),
            _overspentCaption(context),
          ],
          const SizedBox(height: 16),
          _bar(context),
          if (showBreakdown) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.dividerStrong)),
              ),
              child: _breakdown(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final c = context.scandy;
    final l = context.l;
    return Row(
      children: [
        Expanded(
          child: Text(
            // toUpperCase is a no-op on Chinese, so the eyebrow simply reads
            // as written there.
            '${l.safeToSpend} · ${context.dates.shortMonth(now)}'.toUpperCase(),
            style: ScandyText.cardEyebrow.copyWith(color: c.textSecondary),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: c.accentSoft,
            borderRadius: BorderRadius.circular(ScandyRadius.pill),
          ),
          child: Text(
            l.daysLeft(summary.daysLeft),
            style: ScandyText.pill.copyWith(color: c.onAccentSoft),
          ),
        ),
      ],
    );
  }

  /// The figure is bold and the sentence around it is not, which is why this
  /// is three spans rather than one string: English hangs the caption off the
  /// end of the amount, Chinese puts the whole clause in front of it, so the
  /// translation supplies both halves and either may be empty.
  Widget _perDayCaption(BuildContext context, double perDay) {
    final c = context.scandy;
    final l = context.l;
    return Text.rich(
      TextSpan(
        style: ScandyText.heroCaption.copyWith(color: c.textSecondary),
        children: [
          TextSpan(text: l.perDayPrefix),
          TextSpan(
            text: formatRinggit(perDay),
            style: ScandyText.heroCaptionStrong.copyWith(
              color: c.textPrimary,
              fontFeatures: tabularFigures,
            ),
          ),
          TextSpan(text: l.perDaySuffix),
        ],
      ),
    );
  }

  /// Replaces the daily line when there is no allowance left to divide up.
  ///
  /// States what happened and leaves the judgement out: a month with no income
  /// at all — a semester break — reads the same to this card as overspending,
  /// and it has no way to tell which one it is looking at.
  Widget _overspentCaption(BuildContext context) {
    final c = context.scandy;
    return Text(
      context.l.overspentCaption,
      style: ScandyText.heroCaption.copyWith(color: c.textSecondary),
    );
  }

  /// Identifies the progress track, and its first segment, for the regression
  /// tests that guard their size — see the notes inside [_bar].
  static const barKey = Key('safe-to-spend-bar');
  static const barSpentSegmentKey = Key('safe-to-spend-bar-spent');

  /// Three-segment progress track: spent, recurring-due, remainder.
  Widget _bar(BuildContext context) {
    final c = context.scandy;
    final spent = summary.spentFraction;
    final recurring = summary.recurringFraction;
    final rest = (1 - spent - recurring).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(ScandyRadius.pill),
      // `width: double.infinity` is load-bearing: the parent Column is
      // crossAxisAlignment.start, so children get *loose* constraints and a
      // SizedBox with no width would collapse to zero — taking the whole bar
      // with it, since its segments are all Expanded.
      child: SizedBox(
        key: barKey,
        width: double.infinity,
        height: 9,
        child: Row(
          // Also load-bearing. A childless ColoredBox is a RenderProxyBox with
          // nothing to measure, so under the default centre alignment it takes
          // the *smallest* height the loose constraints allow — zero — and the
          // bar disappears while still reporting a 9px box around it. Stretch
          // makes the vertical constraint tight.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // flex needs integers, so the fractions are expressed in
            // ten-thousandths — finer than a pixel at any phone width.
            Expanded(
              flex: (spent * 10000).round(),
              child: ColoredBox(key: barSpentSegmentKey, color: c.negative),
            ),
            Expanded(
                flex: (recurring * 10000).round(),
                child: ColoredBox(color: c.trackRecurring)),
            Expanded(flex: (rest * 10000).round(), child: ColoredBox(color: c.track)),
          ],
        ),
      ),
    );
  }

  Widget _breakdown(BuildContext context) {
    final c = context.scandy;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _stat(
              context, context.l.statIn, summary.moneyInCents / 100, c.positive),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _stat(context, context.l.statSpent, summary.spentCents / 100,
              c.negative),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _stat(context, context.l.statDue,
              summary.recurringDueCents / 100, c.textPrimary),
        ),
      ],
    );
  }

  Widget _stat(BuildContext context, String label, double value, Color color) {
    final c = context.scandy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: ScandyText.breakdownLabel.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatBare(value),
            style: ScandyText.breakdownValue.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
