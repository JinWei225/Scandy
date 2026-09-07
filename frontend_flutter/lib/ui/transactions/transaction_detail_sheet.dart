import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
Future<void> showTransactionDetailSheet(
  BuildContext context,
  Transaction transaction,
) {
  return showScandySheet<void>(
    context: context,
    title: 'Transaction',
    child: _TransactionDetail(transaction: transaction),
  );
}

class _TransactionDetail extends StatelessWidget {
  const _TransactionDetail({required this.transaction});

  final Transaction transaction;

  String _accountName(AppState state, String? id) {
    if (id == null) return 'No account';
    for (final a in state.accounts) {
      if (a.id == id) return a.name;
    }
    return 'Unknown account';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
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
                        ? 'Untitled'
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
        _Row(label: 'Category', value: transaction.category.isEmpty
            ? 'Uncategorised'
            : transaction.category),
        _Row(
          label: 'Date',
          value: transaction.date == null
              ? '—'
              : DateFormat('EEEE, d MMMM yyyy').format(transaction.date!),
        ),
        _Row(label: 'Time', value: transaction.shortTime),
        if (transaction.isTransfer) ...[
          _Row(label: 'From', value: _accountName(state, transaction.fromAccountId)),
          _Row(label: 'To', value: _accountName(state, transaction.toAccountId)),
        ] else
          _Row(label: 'Account', value: _accountName(state, transaction.accountId)),
        _Row(
          label: 'Type',
          value: switch (transaction.type) {
            TransactionType.income => 'Income',
            TransactionType.expense => 'Expense',
            TransactionType.transfer => 'Transfer',
          },
        ),
        if (transaction.isTransfer) ...[
          const SizedBox(height: 6),
          Text(
            'A transfer is stored as two linked rows. Editing or deleting one '
            'updates both.',
            style:
                ScandyText.sheetItemSubtitle.copyWith(color: c.textSecondary),
          ),
        ],
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Edit',
          onPressed: () async {
            Navigator.of(context).pop();
            await showAddTransactionSheet(context, transaction: transaction);
          },
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _delete(context, transaction),
          style: TextButton.styleFrom(
            foregroundColor: c.negative,
            minimumSize: const Size.fromHeight(44),
          ),
          child: Text('Delete', style: ScandyText.sheetItemTitle),
        ),
      ],
    );
  }
}

Future<void> _delete(BuildContext context, Transaction transaction) async {
  final state = context.read<AppState>();
  final navigator = Navigator.of(context);

  final confirmed = await confirmDestructive(
    context: context,
    title: 'Delete this transaction?',
    message: transaction.isTransfer
        ? 'Both legs of the transfer are removed, and the account balances go '
            'back to what they were.'
        : 'It is removed for good and the account balance goes back to what '
            'it was.',
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
