import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
    final state = context.watch<AppState>();
    final now = clock ?? DateTime.now();
    final stats = RecurringStats.from(state.subscriptions, now: now);

    final total = stats.stillToCome.length + stats.alreadyCharged.length;
    final next = stats.stillToCome.isEmpty ? null : stats.stillToCome.first;
    final rows = [...stats.stillToCome, ...stats.alreadyCharged];

    return DesktopPage(
      children: [
        DesktopFigureHeader(
          title: 'Recurring',
          label: 'Every month',
          figure: formatRinggit(stats.monthlyTotalCents / 100),
          titleTrailing: DesktopIconButton(
            icon: Icons.search,
            tooltip: 'Search transactions',
            onPressed: () => showSearchSheet(context),
          ),
          trailing: DesktopAccentButton(
            icon: Icons.add,
            label: 'Add recurring charge',
            height: 44,
            onPressed: () => showSubscriptionFormSheet(context),
          ),
        ),
        const SizedBox(height: desktopGap),
        DesktopCardRow(children: [
          DesktopStatCard(
            label: 'Already charged',
            value: formatRinggit(stats.chargedCents / 100),
            valueColor: c.negative,
            meta: '${stats.alreadyCharged.length} of $total this month',
          ),
          DesktopStatCard(
            label: 'Still to come',
            value: formatRinggit(stats.toComeCents / 100),
            meta: stats.stillToCome.length == 1
                ? '1 charge before month end'
                : '${stats.stillToCome.length} charges before month end',
          ),
          DesktopStatCard(
            label: 'Next charge',
            accent: true,
            value: next?.name ?? 'Nothing due',
            meta: next == null
                ? 'Everything has been charged'
                : '${formatRinggit(next.amount)} on day ${next.dayOfMonth}',
          ),
        ]),
        const SizedBox(height: desktopGap),
        DesktopPanel(
          child: rows.isEmpty
              ? const DesktopEmpty(
                  icon: Icons.event_repeat,
                  title: 'No recurring charges',
                  message:
                      'Add the ones that repeat and they stop surprising you.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const DesktopTableHeader(
                      columns: columns,
                      labels: [
                        'Service',
                        'Category',
                        'Charges on',
                        'Amount',
                        'Actions'
                      ],
                      alignRight: {3, 4},
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
          ? 'Charged this month'
          : 'Charged ${DateFormat('d MMM').format(recorded)}';
    } else {
      metaColor = imminent ? c.onAccentSoft : c.textSecondary;
      meta = _relative(daysAway);
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
          child: DesktopChip(
              label: s.category.isEmpty ? 'Uncategorised' : s.category),
        ),
        Text('Day ${s.dayOfMonth}',
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

  static String _relative(int days) {
    if (days < 0) return 'Due next month';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'Due in $days days';
  }
}
