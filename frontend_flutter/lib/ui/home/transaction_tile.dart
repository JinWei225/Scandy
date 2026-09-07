import 'package:flutter/material.dart';

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
  });

  final Transaction transaction;
  final DateTime now;
  final VoidCallback? onTap;

  /// The last row in the card has no rule under it.
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
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
                        ? 'Untitled'
                        : transaction.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ScandyText.rowTitle.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    transactionMeta(
                      category: transaction.category,
                      date: transaction.date,
                      shortTime: transaction.shortTime,
                      now: now,
                    ),
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
}
