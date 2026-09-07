import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../util/formatting.dart';
import '../common/sheets.dart';
import '../common/widgets.dart';
import '../home/transaction_tile.dart';
import 'transaction_detail_sheet.dart';

/// Search across every transaction.
///
/// Undesigned, so it borrows the sheet shell and reuses [TransactionTile] —
/// results look exactly like the rows on Home, which is the point: you should
/// recognise what you found.
Future<void> showSearchSheet(BuildContext context) {
  return showScandySheet<void>(
    context: context,
    title: 'Search transactions',
    fullHeight: true,
    child: const _SearchBody(),
  );
}

class _SearchBody extends StatefulWidget {
  const _SearchBody();

  @override
  State<_SearchBody> createState() => _SearchBodyState();
}

class _SearchBodyState extends State<_SearchBody> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Matches description, category and account name, plus the amount typed
  /// either as "12.34" or "1234". Every term must match somewhere, so
  /// "grab may" narrows rather than widens.
  List<Transaction> _results(AppState state) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return const [];

    final accountNames = {for (final a in state.accounts) a.id: a.name.toLowerCase()};
    final terms = query.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);

    return state.transactions.where((t) {
      final haystack = StringBuffer()
        ..write(t.description.toLowerCase())
        ..write(' ')
        ..write(t.category.toLowerCase())
        ..write(' ')
        ..write(accountNames[t.accountId] ?? '')
        ..write(' ')
        ..write((t.amountCents.abs() / 100).toStringAsFixed(2))
        ..write(' ')
        ..write(t.date == null ? '' : formatGreetingDate(t.date!).toLowerCase());
      final text = haystack.toString();
      return terms.every(text.contains);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final state = context.watch<AppState>();
    final results = _results(state);
    final now = DateTime.now();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          autocorrect: false,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _query = v),
          style: ScandyText.rowTitleLarge.copyWith(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: 'Description, category, account or amount',
            hintStyle: ScandyText.rowTitle.copyWith(color: c.iconMuted),
            prefixIcon: Icon(Icons.search, size: 20, color: c.iconMuted),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close, size: 18, color: c.iconMuted),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                  ),
            filled: true,
            fillColor: c.surfaceMuted,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ScandyRadius.tile),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ScandyRadius.tile),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ScandyRadius.tile),
              borderSide: BorderSide(color: c.accent, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_query.trim().isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Text(
              'Start typing to search all ${state.transactions.length} '
              'transactions.',
              textAlign: TextAlign.center,
              style: ScandyText.rowMeta.copyWith(color: c.textSecondary),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              results.isEmpty
                  ? 'No matches'
                  : '${results.length} '
                      '${results.length == 1 ? 'match' : 'matches'}'
                      '${_totalLine(results)}',
              style: ScandyText.statLabel.copyWith(color: c.textSecondary),
            ),
          ),
          if (results.isEmpty)
            const EmptyState(
              icon: Icons.search_off,
              title: 'Nothing found',
              message: 'Try a shorter word, or part of the amount.',
            )
          else
            ScandyCard(
              radius: ScandyRadius.list,
              clip: true,
              child: Column(
                children: [
                  // Capped so a broad query cannot build a thousand rows at
                  // once; narrowing the query is the way to the rest.
                  for (var i = 0; i < results.length && i < 50; i++)
                    TransactionTile(
                      transaction: results[i],
                      now: now,
                      showDivider:
                          i != results.length - 1 && i != 49,
                      onTap: () async {
                        Navigator.of(context).pop();
                        await showTransactionDetailSheet(context, results[i]);
                      },
                    ),
                ],
              ),
            ),
          if (results.length > 50)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Showing the first 50. Narrow the search to see the rest.',
                style: ScandyText.sheetItemSubtitle
                    .copyWith(color: c.textSecondary),
              ),
            ),
        ],
      ],
    );
  }

  /// " · RM 412.30 out, RM 90.00 in" — a quick sense of what the query covers.
  String _totalLine(List<Transaction> results) {
    var out = 0;
    var income = 0;
    for (final t in results) {
      if (t.isIncome) {
        income += t.amountCents.abs();
      } else {
        out += t.amountCents.abs();
      }
    }
    final parts = <String>[
      if (out > 0) '${formatRinggit(out / 100)} out',
      if (income > 0) '${formatRinggit(income / 100)} in',
    ];
    return parts.isEmpty ? '' : ' · ${parts.join(', ')}';
  }
}
