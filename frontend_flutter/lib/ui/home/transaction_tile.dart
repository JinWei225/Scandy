import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/transaction.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../util/category_icons.dart';
import '../../util/formatting.dart';

/// One row of the "Recent" card: 38px icon tile, description over category ·
/// time, signed amount hard right. 60px minimum height per the design.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.now,
    this.onTap,
    this.showDivider = true,
    this.showCategory = true,
  });

  final Transaction transaction;
  final DateTime now;
  final VoidCallback? onTap;

  /// The last row in the card has no rule under it.
  final bool showDivider;

  /// Off on a page that is already one category, where repeating the name on
  /// every row says nothing; the meta line carries date and time instead.
  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final l = context.l;
    final isIncome = transaction.isIncome;

    // Income gets the green tile and green figure; everything else is neutral.
    final tileColor = isIncome ? c.positiveSoft : c.surfaceMuted;
    final glyphColor = isIncome ? c.positive : c.textTertiary;
    final amountColor = isIncome ? c.positive : c.negative;

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: showDivider
            ? BoxDecoration(
                border: Border(bottom: BorderSide(color: c.divider)),
              )
            : null,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: BorderRadius.circular(ScandyRadius.tile),
              ),
              child: Icon(
                iconForCategory(transaction.category,
                    isTransfer: transaction.isTransfer),
                size: 20,
                color: glyphColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    transaction.description.isEmpty
                        ? l.untitled
                        : transaction.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ScandyText.rowTitle.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    showCategory
                        ? transactionMeta(
                            l: l,
                            dates: context.dates,
                            category: transaction.category,
                            date: transaction.date,
                            shortTime: transaction.shortTime,
                            now: now,
                          )
                        : _whenOnly(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ScandyText.rowMeta.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatSignedCents(transaction.amountCents),
              style: ScandyText.rowAmount.copyWith(color: amountColor),
            ),
          ],
        ),
      ),
    );
  }

  /// "6 Sep · 14:22" — both, since a month of one category needs the day to
  /// tell rows apart and the time to order the ones on the same day.
  String _whenOnly(BuildContext context) {
    final parts = <String>[];
    final date = transaction.date;
    if (date != null) parts.add(context.dates.dayMonth(date));
    if (transaction.shortTime.isNotEmpty) parts.add(transaction.shortTime);
    return parts.join(' · ');
  }
}
