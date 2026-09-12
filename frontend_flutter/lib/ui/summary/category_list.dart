import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/summary_stats.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../util/formatting.dart';
import '../common/widgets.dart';

/// "Where it went" / "Where it came from": one row per category with its
/// share of the month as a bar. Used by Summary, its "All N" sheet, and the
/// Account page.
///
/// Rows are tappable when [onTap] is given — the drill-down into the
/// transactions behind the figure. The caller decides what a tap does, since
/// a row inside a sheet has to close the sheet before it can push a page.
class CategoryList extends StatelessWidget {
  const CategoryList({
    super.key,
    required this.categories,
    required this.color,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.emptyIcon,
    this.onTap,
  });

  final List<CategorySpend> categories;

  /// Bar and figure colour — spending reads red, income green.
  final Color color;

  final String emptyTitle;
  final String emptyMessage;
  final IconData emptyIcon;

  final ValueChanged<CategorySpend>? onTap;

  @override
  Widget build(BuildContext context) {
    return ScandyCard(
      radius: ScandyRadius.list,
      clip: true,
      child: categories.isEmpty
          ? EmptyState(
              icon: emptyIcon,
              title: emptyTitle,
              message: emptyMessage,
            )
          : Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  for (var i = 0; i < categories.length; i++)
                    _CategoryRow(
                      category: categories[i],
                      color: color,
                      showDivider: i != categories.length - 1,
                      onTap: onTap == null ? null : () => onTap!(categories[i]),
                    ),
                ],
              ),
            ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.color,
    required this.showDivider,
    required this.onTap,
  });

  final CategorySpend category;
  final Color color;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: showDivider
            ? BoxDecoration(
                border: Border(bottom: BorderSide(color: c.divider)),
              )
            : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                            displayCategory(context.l, category.category),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ScandyText.rowTitle
                                .copyWith(color: c.textPrimary)),
                      ),
                      const SizedBox(width: 8),
                      // Beside the name rather than after the bar, so the bar
                      // can run the full column width.
                      Text(
                        '${(category.fractionOfSpend * 100).round()}%',
                        style: ScandyText.percentLabel
                            .copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ProportionBar(
                    fraction: category.fractionOfSpend,
                    color: color,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Fixed width, so the bar column is identical on every row
            // regardless of how many digits the figure has — otherwise a
            // 4-figure amount visibly shortens its bar. Wide enough for
            // "12,345.67"; anything longer scales.
            SizedBox(
              width: 96,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  formatBare(category.cents / 100),
                  style: ScandyText.rowAmount.copyWith(color: color),
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: c.iconMuted),
            ],
          ],
        ),
      ),
    );
  }
}
