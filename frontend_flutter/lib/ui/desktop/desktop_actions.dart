import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/account.dart';
import '../../models/subscription.dart';
import '../../models/transaction.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../common/sheets.dart';

/// The delete half of the desktop tables' "Actions" column.
///
/// The forms already offer delete, but the frames put it on the row too, so
/// these are the same confirmations reached one step earlier. Each refreshes
/// through [AppState] so the sidebar's total balance moves with the table.

Future<void> deleteTransactionFromRow(
  BuildContext context,
  Transaction transaction,
) async {
  final state = context.read<AppState>();
  final confirmed = await confirmDestructive(
    context: context,
    title: 'Delete this transaction?',
    message: transaction.isTransfer
        ? 'Both legs of the transfer are removed, and the account balances go '
            'back to what they were.'
        : 'It is removed for good and the account balance goes back to what '
            'it was.',
  );
  if (!confirmed || !context.mounted) return;

  try {
    await state.deleteTransaction(transaction.id);
  } catch (e) {
    if (context.mounted) showErrorToast(context, '$e');
  }
}

Future<void> deleteAccountFromRow(BuildContext context, Account account) async {
  final state = context.read<AppState>();
  final confirmed = await confirmDestructive(
    context: context,
    title: 'Delete ${account.name}?',
    message:
        'The account is removed from the list. Transactions recorded against '
        'it are kept, but will no longer be attributed to an account.',
  );
  if (!confirmed || !context.mounted) return;

  try {
    await state.api.deleteAccount(account.id);
    await state.refresh();
  } catch (e) {
    if (context.mounted) showErrorToast(context, '$e');
  }
}

Future<void> deleteSubscriptionFromRow(
  BuildContext context,
  Subscription subscription,
) async {
  final state = context.read<AppState>();
  final confirmed = await confirmDestructive(
    context: context,
    title: 'Delete ${subscription.name}?',
    message: 'It stops counting toward your monthly total. Charges already '
        'recorded as transactions are kept.',
  );
  if (!confirmed || !context.mounted) return;

  try {
    await state.api.deleteSubscription(subscription.id);
    await state.refresh();
  } catch (e) {
    if (context.mounted) showErrorToast(context, '$e');
  }
}

/// The red floating snack the forms use, so a failure reads the same wherever
/// it is triggered from.
void showErrorToast(BuildContext context, String message) {
  final c = context.scandy;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message,
          style: ScandyText.rowTitle.copyWith(color: c.onAccent)),
      backgroundColor: c.negative,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ScandyRadius.tile),
      ),
    ));
}
