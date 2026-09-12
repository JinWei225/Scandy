import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/summary_stats.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../util/formatting.dart';
import '../common/widgets.dart';

/// Money in / Spent / Net / Daily avg, two per row — Summary's figures.
///
/// [compact] drops the daily average and puts the remaining three on one
/// row: the Account page has no use for an average of one account's spending,
/// and a lone fourth tile would leave a hole in the grid.
class MonthStatGrid extends StatelessWidget {
  const MonthStatGrid({super.key, required this.stats, this.compact = false});

  final MonthStats stats;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final l = context.l;
    final avg = stats.dailyAverage;

    final moneyIn = _Stat(
        label: l.moneyIn,
        value: formatBare(stats.moneyInCents / 100),
        color: c.positive);
    final spent = _Stat(
        label: l.spentLabel,
        value: formatBare(stats.spentCents / 100),
        color: c.negative);
    final net = _Stat(
        label: l.netLabel,
        value: formatBare(stats.netCents / 100),
        // A negative month should read as a loss, not as neutral.
        color: stats.netCents < 0 ? c.negative : c.textPrimary);

    if (compact) {
      return Row(
        children: [
          Expanded(child: moneyIn),
          const SizedBox(width: 10),
          Expanded(child: spent),
          const SizedBox(width: 10),
          Expanded(child: net),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: moneyIn),
            const SizedBox(width: 10),
            Expanded(child: spent),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: net),
            const SizedBox(width: 10),
            Expanded(
                child: _Stat(
                    label: l.dailyAvg,
                    value: avg == null ? l.emDash : formatBare(avg),
                    color: c.textPrimary)),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return ScandyCard(
      radius: ScandyRadius.row,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ScandyText.statLabel.copyWith(color: c.textSecondary)),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child:
                Text(value, style: ScandyText.statValue.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}
