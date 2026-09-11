import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/transaction.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../util/category_icons.dart';
import '../../util/formatting.dart';
import '../common/sheets.dart';
import '../common/widgets.dart';
import 'add_transaction_sheet.dart';

/// Everything recorded about one transaction, with edit and delete.
///
/// Undesigned, so it reuses the sheet shell and the same tile/label vocabulary
/// as the lists it is opened from — the amount leads, exactly as it does in a
/// row, and the rest is a labelled table.
/// What the sheet asked its caller to do once it has closed.
enum _DetailRequest { edit }

Future<void> showTransactionDetailSheet(
  BuildContext context,
  Transaction transaction,
) async {
  // The sheet asks, and this caller acts once the sheet is gone. Opening the
  // edit sheet from inside it meant passing a context whose own route was
  // being popped — a widget on its way out, which happens to work only while
  // the dismissal is still animating.
  final request = await showScandySheet<_DetailRequest>(
    context: context,
    title: context.l.transaction,
    child: _TransactionDetail(transaction: transaction),
  );
  if (request == _DetailRequest.edit && context.mounted) {
    await showAddTransactionSheet(context, transaction: transaction);
  }
}

class _TransactionDetail extends StatelessWidget {
  const _TransactionDetail({required this.transaction});

  final Transaction transaction;

  String _accountName(L l, AppState state, String? id) {
    if (id == null) return l.noAccount;
    for (final a in state.accounts) {
      if (a.id == id) return a.name;
    }
    return l.unknownAccount;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final l = context.l;
    final state = context.watch<AppState>();

    final isIncome = transaction.isIncome;
    final amountColor = isIncome ? c.positive : c.negative;
    final tileColor = isIncome ? c.positiveSoft : c.surfaceMuted;
    final glyphColor = isIncome ? c.positive : c.textTertiary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: BorderRadius.circular(ScandyRadius.tileLarge),
              ),
              child: Icon(
                iconForCategory(transaction.category,
                    isTransfer: transaction.isTransfer),
                size: 22,
                color: glyphColor,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    transaction.description.isEmpty
                        ? l.untitled
                        : transaction.description,
                    style: ScandyText.rowTitleLarge
                        .copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatSignedCents(transaction.amountCents),
                    style: ScandyText.bigBalance
                        .copyWith(color: amountColor, fontSize: 26),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _Row(
            label: l.fieldCategory,
            value: displayCategory(l, transaction.category)),
        _Row(
          label: l.fieldDate,
          value: transaction.date == null
              ? l.emDash
              : context.dates.full(transaction.date!),
        ),
        _Row(label: l.fieldTime, value: transaction.shortTime),
        if (transaction.isTransfer) ...[
          _Row(
              label: l.fieldFrom,
              value: _accountName(l, state, transaction.fromAccountId)),
          _Row(
              label: l.fieldTo,
              value: _accountName(l, state, transaction.toAccountId)),
        ] else
          _Row(
              label: l.fieldAccount,
              value: _accountName(l, state, transaction.accountId)),
        _Row(
          label: l.fieldType,
          // A transfer leg is stored as an expense or an income row -- the
          // pairing lives in transfer_group_id -- so `type` alone would call
          // it whichever half was tapped.
          value: transaction.isTransfer
              ? l.kindTransfer
              : transaction.isIncome
                  ? l.kindIncome
                  : l.kindExpense,
        ),
        if (transaction.isTransfer) ...[
          const SizedBox(height: 6),
          Text(
            l.transferTwoRowsNote,
            style:
                ScandyText.sheetItemSubtitle.copyWith(color: c.textSecondary),
          ),
        ],
        const SizedBox(height: 20),
        PrimaryButton(
          label: l.actionEdit,
          onPressed: () => Navigator.of(context).pop(_DetailRequest.edit),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _delete(context, transaction),
          style: TextButton.styleFrom(
            foregroundColor: c.negative,
            minimumSize: const Size.fromHeight(44),
          ),
          child: Text(l.actionDelete, style: ScandyText.sheetItemTitle),
        ),
      ],
    );
  }
}

Future<void> _delete(BuildContext context, Transaction transaction) async {
  final state = context.read<AppState>();
  final navigator = Navigator.of(context);
  final l = context.l;

  final confirmed = await confirmDestructive(
    context: context,
    title: l.deleteThisTransactionQ,
    message: transaction.isTransfer
        ? l.deleteTransferBody
        : l.deleteTransactionBody,
  );
  if (!confirmed) return;

  try {
    await state.deleteTransaction(transaction.id);
    navigator.pop();
  } catch (e) {
    if (!context.mounted) return;
    final c = context.scandy;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$e',
            style: ScandyText.rowTitle.copyWith(color: c.onAccent)),
        backgroundColor: c.negative,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ScandyRadius.tile),
        ),
      ));
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label.toUpperCase(),
                style: ScandyText.statLabel.copyWith(color: c.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: ScandyText.rowTitle.copyWith(color: c.textPrimary)),
          ),
        ],
      ),
    );
  }
}
