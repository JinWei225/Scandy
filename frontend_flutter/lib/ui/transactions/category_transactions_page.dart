import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/summary_stats.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../util/formatting.dart';
import '../common/widgets.dart';
import '../home/transaction_tile.dart';
import 'transaction_detail_sheet.dart';

/// Every transaction behind one row of "Where it went" / "Where it came from":
/// one category, one month, and optionally one account.
///
/// A pushed page rather than a sheet. A busy category runs to hundreds of
/// rows, and a bottom sheet fights its own drag-to-dismiss on a long scroll;
/// here the list is a lazily built sliver, so rows are only laid out as they
/// come into view. The page watches [AppState], so editing or deleting a row
/// from the detail sheet updates the list in place.
class CategoryTransactionsPage extends StatelessWidget {
  const CategoryTransactionsPage({
    super.key,
    required this.month,
    required this.category,
    required this.income,
    this.accountId,
    this.clock,
  });

  /// First day of the month, as [MonthStats.month] carries it.
  final DateTime month;

  /// The stored category key — [MonthStats.categoryKey], not the display
  /// name — so "Uncategorised" rows are found under the bucket they were
  /// counted in.
  final String category;

  /// Income rows or spending rows: the same name can head both lists.
  final bool income;

  /// Set when opened from an Account page; null covers every account.
  final String? accountId;

  final DateTime? clock;

  static Future<void> open(
    BuildContext context, {
    required DateTime month,
    required String category,
    required bool income,
    String? accountId,
  }) {
    return Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CategoryTransactionsPage(
        month: month,
        category: category,
        income: income,
        accountId: accountId,
      ),
    ));
  }

  /// Wide windows get the phone column, centred: the rows are the same as
  /// Home's and do not gain anything from stretching across a desktop.
  static const double maxWidth = 720;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final l = context.l;
    final state = context.watch<AppState>();
    final now = clock ?? DateTime.now();

    final rows = MonthStats.transactionsFor(
      state.transactions,
      month: month,
      category: category,
      income: income,
      accountId: accountId,
    );
    final total = rows.fold<int>(0, (sum, t) => sum + t.amountCents.abs());
    final color = income ? c.positive : c.negative;

    final account =
        accountId == null ? null : state.accountById(accountId!)?.name;
    final subtitle = [
      context.dates.monthYear(month),
      ?account,
    ].join(' · ');

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: RefreshIndicator(
              onRefresh: state.refresh,
              color: c.accent,
              backgroundColor: c.surface,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PageBackHeader(
                            title: displayCategory(l, category),
                            subtitle: subtitle,
                          ),
                          const SizedBox(height: 16),
                          Text.rich(
                            TextSpan(
                              style: ScandyText.statLabel
                                  .copyWith(color: c.textSecondary),
                              children: [
                                TextSpan(text: l.nTransactions(rows.length)),
                                if (rows.isNotEmpty) ...[
                                  const TextSpan(text: ' · '),
                                  TextSpan(
                                    text: formatBare(total / 100),
                                    style: ScandyText.statLabel
                                        .copyWith(color: color),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                    sliver: rows.isEmpty
                        ? SliverToBoxAdapter(
                            child: ScandyCard(
                              radius: ScandyRadius.list,
                              clip: true,
                              child: EmptyState(
                                icon: income ? Icons.payments : Icons.bar_chart,
                                title: l.nothingInThisCategory,
                                message: l.nothingInThisCategoryBody,
                              ),
                            ),
                          )
                        // The card's border and clip wrap the sliver, so the
                        // list looks like every other card while still only
                        // building the rows on screen.
                        : DecoratedSliver(
                            decoration: BoxDecoration(
                              color: c.surface,
                              border: Border.all(color: c.border),
                              borderRadius:
                                  BorderRadius.circular(ScandyRadius.list),
                            ),
                            sliver: SliverPadding(
                              // One pixel in from the card's own stroke, so
                              // the rows never paint over it.
                              padding: const EdgeInsets.all(1),
                              sliver: SliverList.builder(
                                itemCount: rows.length,
                                itemBuilder: (context, i) => _Row(
                                  first: i == 0,
                                  last: i == rows.length - 1,
                                  child: TransactionTile(
                                    transaction: rows[i],
                                    now: now,
                                    showCategory: false,
                                    showDivider: i != rows.length - 1,
                                    onTap: () => showTransactionDetailSheet(
                                        context, rows[i]),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One row of the list, with somewhere for its ink to go.
///
/// A [DecoratedSliver] paints its fill above the Scaffold's Material, which
/// is where an InkWell's ripple would otherwise land — under the card, unseen.
/// Each row gets a transparent Material of its own, and the first and last
/// are clipped to the card's corners so a long press does not paint a square
/// ripple past the rounded edge.
class _Row extends StatelessWidget {
  const _Row({required this.first, required this.last, required this.child});

  final bool first;
  final bool last;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const corner = Radius.circular(ScandyRadius.list - 1);
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: first ? corner : Radius.zero,
        bottom: last ? corner : Radius.zero,
      ),
      child: Material(color: Colors.transparent, child: child),
    );
  }
}

/// Back arrow, then the title over a subtitle, with an optional action hard
/// right — the header of every pushed page.
class PageBackHeader extends StatelessWidget {
  const PageBackHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Row(
      children: [
        SquareIconButton(
          icon: Icons.arrow_back,
          tooltip: context.l.actionBack,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ScandyText.greeting.copyWith(color: c.textPrimary)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ScandyText.greetingMeta
                        .copyWith(color: c.textSecondary)),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}
