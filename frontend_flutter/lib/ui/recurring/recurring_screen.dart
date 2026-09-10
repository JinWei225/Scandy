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
import '../common/widgets.dart';
import '../shell/bottom_nav.dart';
import 'subscription_form_sheet.dart';
import '../transactions/search_sheet.dart';

/// "Recurring" — the monthly commitment, split into what is still coming and
/// what has already been charged this month.
class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key, this.clock});

  final DateTime? clock;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = context.scandy;
    final l = context.l;
    final now = clock ?? DateTime.now();
    final stats = RecurringStats.from(state.subscriptions, now: now);

    final navHeight = ScandyBottomNav.heightFor(context);

    return FabScaffold(
      navHeight: navHeight,
      tooltip: l.addRecurringCharge,
      onPressed: () => showSubscriptionFormSheet(context),
      child: RefreshIndicator(
      onRefresh: state.refresh,
      color: c.accent,
      backgroundColor: c.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Extra bottom room so the floating + never sits on the last card.
        padding: EdgeInsets.fromLTRB(18, 14, 18, navHeight + 88),
        children: [
          ScreenHeader(
            title: l.recurring,
            trailing: HeaderActions(onSearch: () => showSearchSheet(context)),
          ),
          const SizedBox(height: 14),
          _TotalCard(stats: stats),
          const SizedBox(height: 14),
          SectionHeader(
            title: l.stillToCome,
            actionLabel: stats.stillToCome.isEmpty
                ? null
                : l.allN(stats.stillToCome.length),
          ),
          const SizedBox(height: 9),
          _SubscriptionList(
            subscriptions: stats.stillToCome,
            now: now,
            charged: false,
            emptyMessage: l.everythingRecordedThisMonth,
          ),
          const SizedBox(height: 15),
          SectionHeader(
            title: l.alreadyCharged,
            actionLabel: stats.alreadyCharged.isEmpty
                ? null
                : l.allN(stats.alreadyCharged.length),
          ),
          const SizedBox(height: 9),
          _SubscriptionList(
            subscriptions: stats.alreadyCharged,
            now: now,
            charged: true,
            emptyMessage: l.nothingChargedYetThisMonth,
          ),
        ],
      ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.stats});

  final RecurringStats stats;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final l = context.l;
    return ScandyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.everyMonth.toUpperCase(),
              style: ScandyText.cardEyebrow.copyWith(color: c.textSecondary)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(formatRinggit(stats.monthlyTotalCents / 100),
                style: ScandyText.bigBalance.copyWith(color: c.textPrimary)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.dividerStrong)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MiniStat(
                    label: l.chargedLabel,
                    value: formatBare(stats.chargedCents / 100),
                    color: c.negative,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniStat(
                    label: l.toComeLabel,
                    value: formatBare(stats.toComeCents / 100),
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(),
            style: ScandyText.breakdownLabel.copyWith(color: c.textSecondary)),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: ScandyText.accountAmount.copyWith(color: color)),
        ),
      ],
    );
  }
}

class _SubscriptionList extends StatelessWidget {
  const _SubscriptionList({
    required this.subscriptions,
    required this.now,
    required this.charged,
    required this.emptyMessage,
  });

  final List<Subscription> subscriptions;
  final DateTime now;

  /// Charged rows show a green "Charged 4 Sep"; upcoming rows show
  /// "Day 12 · in 6 days", tinted amber when the charge is imminent.
  final bool charged;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return ScandyCard(
      radius: ScandyRadius.list,
      clip: true,
      child: subscriptions.isEmpty
          ? EmptyState(
              icon: Icons.event_repeat,
              title: charged
                  ? context.l.nothingChargedYet
                  : context.l.nothingDue,
              message: emptyMessage,
            )
          : Column(
              children: [
                for (var i = 0; i < subscriptions.length; i++)
                  _SubscriptionRow(
                    subscription: subscriptions[i],
                    now: now,
                    charged: charged,
                    showDivider: i != subscriptions.length - 1,
                  ),
              ],
            ),
    );
  }
}

class _SubscriptionRow extends StatelessWidget {
  const _SubscriptionRow({
    required this.subscription,
    required this.now,
    required this.charged,
    required this.showDivider,
  });

  final Subscription subscription;
  final DateTime now;
  final bool charged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final l = context.l;
    // The clamped day, so a day-31 charge reads "Day 30" in a 30-day month
    // rather than counting down to a date that never arrives.
    final dueDay = subscription.dueDayIn(now);
    final daysAway = dueDay - now.day;

    // The design highlights the nearest upcoming charge in the accent tint and
    // leaves the rest neutral; charged rows read green. Overdue rows are their
    // own case: unrecorded with the day already gone by.
    final overdue = !charged && daysAway < 0;
    final imminent = !charged && !overdue && daysAway <= 7;
    final tile = imminent ? c.accentSoft : c.surfaceMuted;
    final glyph = imminent ? c.onAccentSoft : c.textTertiary;

    final Color metaColor;
    final String meta;
    if (charged) {
      final recorded = subscription.lastRecordedDate;
      metaColor = c.positive;
      meta = recorded == null
          ? l.chargedThisMonth
          : l.chargedOn(context.dates.dayMonth(recorded));
    } else if (overdue) {
      // Not an alarm: the renewal day moves with when the bill is actually
      // paid, so a passed day means "log what you paid", not "you are late".
      metaColor = c.negative;
      meta = l.dayNotRecordedYet(dueDay);
    } else {
      metaColor = imminent ? c.onAccentSoft : c.textSecondary;
      meta = l.dayWithRelative(dueDay, _relative(l, daysAway));
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            showSubscriptionFormSheet(context, subscription: subscription),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
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
                  color: tile,
                  borderRadius: BorderRadius.circular(ScandyRadius.tile),
                ),
                child: Icon(iconForCategory(subscription.category),
                    size: 20, color: glyph),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(subscription.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ScandyText.rowTitle
                            .copyWith(color: c.textPrimary)),
                    const SizedBox(height: 2),
                    Text(meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ScandyText.rowMetaStrong
                            .copyWith(color: metaColor)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(formatBare(subscription.amount),
                  style:
                      ScandyText.rowAmount.copyWith(color: c.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  static String _relative(L l, int days) {
    if (days <= 0) return l.relToday;
    if (days == 1) return l.relTomorrow;
    return l.relInNDays(days);
  }
}
