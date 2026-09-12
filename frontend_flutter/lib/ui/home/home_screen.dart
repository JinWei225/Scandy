import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../util/formatting.dart';
import '../common/widgets.dart';
import '../transactions/search_sheet.dart';
import '../transactions/transaction_detail_sheet.dart';
import '../shell/bottom_nav.dart';
import 'date_range_chip.dart';
import 'safe_to_spend_card.dart';
import 'transaction_tile.dart';

/// The redesigned Home screen, following the "Android · Light/Dark" frames of
/// the handoff: 18px side padding, 16px between blocks, hero card, then the
/// recent transactions — the last three days by default, or whatever range
/// the chip beside the title is set to.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.clock});

  /// Pinned by tests so the greeting, the date line and "N days left" are
  /// stable; null in the app, which reads the real clock.
  final DateTime? clock;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Screen-local, like Summary's month: switching tabs and coming back
  /// starts from the default again, which is the range worth seeing first.
  DateTimeRange? _range;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = widget.clock ?? DateTime.now();
    final range = _range ?? defaultRecentRange(now);

    return RefreshIndicator(
      onRefresh: state.refresh,
      color: context.scandy.accent,
      backgroundColor: context.scandy.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            18, 14, 18, ScandyBottomNav.heightFor(context) + 16),
        children: [
          _Header(now: now),
          const SizedBox(height: 16),
          if (state.status == LoadStatus.failed)
            _ErrorCard(message: state.error ?? context.l.somethingWentWrong)
          else if (state.status == LoadStatus.loading)
            const _LoadingCard()
          else ...[
            SafeToSpendCard(summary: state.summaryFor(now), now: now),
            const SizedBox(height: 16),
            _RecentSection(
              now: now,
              range: range,
              onRangeChanged: (r) => setState(() => _range = r),
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                // The design reads "Good evening, Aiman", but there is no
                // profile feature yet, so the greeting stands on its own and
                // simply tracks the time of day.
                greetingFor(context.l, now),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ScandyText.greeting.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                context.dates.greeting(now),
                style: ScandyText.greetingMeta.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        HeaderActions(onSearch: () => showSearchSheet(context)),
      ],
    );
  }
}

class _RecentSection extends StatelessWidget {
  const _RecentSection({
    required this.now,
    required this.range,
    required this.onRangeChanged,
  });

  final DateTime now;
  final DateTimeRange range;
  final ValueChanged<DateTimeRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final state = context.watch<AppState>();
    final recent = state.transactionsBetween(range);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l.recent,
                style: ScandyText.sectionTitle.copyWith(color: c.textPrimary),
              ),
            ),
            DateRangeChip(range: range, now: now, onChanged: onRangeChanged),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(ScandyRadius.list),
          ),
          child: recent.isEmpty
              // Two different silences: a ledger with nothing in it at all,
              // and a quiet few days in a ledger that has plenty.
              ? (state.transactions.isEmpty
                  ? _EmptyRecent()
                  : EmptyState(
                      icon: Icons.event_busy,
                      title: context.l.nothingInTheseDays,
                      message: context.l.nothingInTheseDaysBody,
                    ))
              : Column(
                  children: [
                    for (var i = 0; i < recent.length; i++)
                      TransactionTile(
                        transaction: recent[i],
                        now: now,
                        showDivider: i != recent.length - 1,
                        onTap: () =>
                            showTransactionDetailSheet(context, recent[i]),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        children: [
          Icon(Icons.receipt_long, size: 28, color: c.iconMuted),
          const SizedBox(height: 10),
          Text(
            context.l.nothingLoggedYet,
            style: ScandyText.rowTitle.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            context.l.nothingLoggedYetBody,
            textAlign: TextAlign.center,
            style: ScandyText.rowMeta.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Container(
      height: 220,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(ScandyRadius.card),
      ),
      child: CircularProgressIndicator(color: c.accent, strokeWidth: 2.5),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
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
          Icon(Icons.cloud_off, size: 26, color: c.negative),
          const SizedBox(height: 12),
          Text(
            context.l.cantLoadYourData,
            style: ScandyText.sectionTitle.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: ScandyText.rowMeta.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton(
                onPressed: () => context.read<AppState>().loadAll(),
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: c.onAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ScandyRadius.tile),
                  ),
                ),
                child: Text(context.l.actionTryAgain, style: ScandyText.link),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/settings'),
                style: TextButton.styleFrom(foregroundColor: c.textSecondary),
                child: Text(context.l.settings, style: ScandyText.link),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
