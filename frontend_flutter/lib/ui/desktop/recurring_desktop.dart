import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/subscription.dart';
import '../../models/summary_stats.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../util/category_icons.dart';
import '../../util/formatting.dart';
import '../recurring/subscription_form_sheet.dart';
import '../transactions/search_sheet.dart';
import 'desktop_actions.dart';
import 'desktop_widgets.dart';

/// Recurring, desktop composition: monthly total in the header, three figures
/// across the top, then every charge in one table — upcoming first, rather
/// than the phone's two separate lists.
class RecurringDesktop extends StatelessWidget {
  const RecurringDesktop({super.key, this.clock});

  final DateTime? clock;

  /// The frame's `1fr 168px 108px 128px 84px` grid.
  static const TableColumns columns = [null, 168, 108, 128, 84];

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final l = context.l;
    final state = context.watch<AppState>();
    final now = clock ?? DateTime.now();
    final stats = RecurringStats.from(state.subscriptions, now: now);

    final total = stats.stillToCome.length + stats.alreadyCharged.length;
    final next = stats.stillToCome.isEmpty ? null : stats.stillToCome.first;
    final rows = [...stats.stillToCome, ...stats.alreadyCharged];

    return DesktopPage(
      children: [
        DesktopFigureHeader(
          title: l.recurring,
          label: l.everyMonth,
          figure: formatRinggit(stats.monthlyTotalCents / 100),
          titleTrailing: DesktopIconButton(
            icon: Icons.search,
            tooltip: l.searchTransactions,
            onPressed: () => showSearchSheet(context),
          ),
          trailing: DesktopAccentButton(
            icon: Icons.add,
            label: l.addRecurringCharge,
            height: 44,
            onPressed: () => showSubscriptionFormSheet(context),
          ),
        ),
        const SizedBox(height: desktopGap),
        DesktopCardRow(children: [
          DesktopStatCard(
            label: l.alreadyCharged,
            value: formatRinggit(stats.chargedCents / 100),
            valueColor: c.negative,
            meta: l.nOfMThisMonth(stats.alreadyCharged.length, total),
          ),
          DesktopStatCard(
            label: l.stillToCome,
            value: formatRinggit(stats.toComeCents / 100),
            meta: l.nChargesBeforeMonthEnd(stats.stillToCome.length),
          ),
          DesktopStatCard(
            label: l.nextCharge,
            accent: true,
            value: next?.name ?? l.nothingDue,
            meta: next == null
                ? l.everythingHasBeenCharged
                : l.amountOnDay(formatRinggit(next.amount), next.dayOfMonth),
          ),
        ]),
        const SizedBox(height: desktopGap),
        DesktopPanel(
          child: rows.isEmpty
              ? DesktopEmpty(
                  icon: Icons.event_repeat,
                  title: l.noRecurringCharges,
                  message: l.noRecurringChargesBody,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DesktopTableHeader(
                      columns: columns,
                      labels: [
                        l.tableService,
                        l.tableCategory,
                        l.tableChargesOn,
                        l.tableAmount,
                        l.tableActions,
                      ],
                      alignRight: const {3, 4},
                    ),
                    for (var i = 0; i < rows.length; i++)
                      _row(
                        context,
                        c,
                        rows[i],
                        now,
                        charged: i >= stats.stillToCome.length,
                        last: i == rows.length - 1,
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    ScandyColors c,
    Subscription s,
    DateTime now, {
    required bool charged,
    required bool last,
  }) {
    final l = context.l;
    final daysAway = s.dayOfMonth - now.day;
    // The nearest upcoming charge is the one worth flagging; charged rows read
    // green, exactly as on the phone.
    final imminent = !charged && daysAway <= 7;

    final String meta;
    final Color metaColor;
    if (charged) {
      final recorded = s.lastRecordedDate;
      metaColor = c.positive;
      meta = recorded == null
          ? l.chargedThisMonth
          : l.chargedOn(context.dates.dayMonth(recorded));
    } else {
      metaColor = imminent ? c.onAccentSoft : c.textSecondary;
      meta = _relative(l, daysAway);
    }

    return DesktopTableRow(
      columns: columns,
      showDivider: !last,
      onTap: () => showSubscriptionFormSheet(context, subscription: s),
      cells: [
        DesktopRowIdentity(
          icon: iconForCategory(s.category),
          title: s.name,
          meta: meta,
          metaColor: metaColor,
          tileColor: imminent ? c.accentSoft : c.surfaceMuted,
          glyphColor: imminent ? c.onAccentSoft : c.textTertiary,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: DesktopChip(label: displayCategory(l, s.category)),
        ),
        Text(l.dayOfMonth(s.dayOfMonth),
            style:
                ScandyDesktopText.cellPlain.copyWith(color: c.textTertiary)),
        DesktopAmountCell(
          text: formatRinggit(s.amount),
          color: c.textPrimary,
        ),
        RowActions(
          onEdit: () => showSubscriptionFormSheet(context, subscription: s),
          onDelete: () => deleteSubscriptionFromRow(context, s),
        ),
      ],
    );
  }

  static String _relative(L l, int days) {
    if (days < 0) return l.dueNextMonth;
    if (days == 0) return l.dueToday;
    if (days == 1) return l.dueTomorrow;
    return l.dueInNDays(days);
  }
}
