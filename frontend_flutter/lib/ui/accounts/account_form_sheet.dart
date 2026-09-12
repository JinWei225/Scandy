import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/account.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../common/sheets.dart';
import '../common/widgets.dart';

/// Account types the database's own check constraint allows.
///
/// These are stored values, not labels: they go into `accounts.type` exactly
/// as written and every existing row already holds one of them, so they stay
/// English however the app is set. [accountTypeLabel] is what a reader sees.
const accountTypes = ['Bank', 'E-Wallet', 'Card', 'Cash'];

/// The reader's word for a stored account type. An unrecognised value — a row
/// written before the constraint, say — is shown as it stands rather than
/// relabelled into something it is not.
String accountTypeLabel(L l, String type) => switch (type.toLowerCase()) {
      'bank' => l.accountTypeBank,
      'card' || 'credit' => l.accountTypeCard,
      'e-wallet' || 'ewallet' || 'wallet' => l.accountTypeEWallet,
      'cash' => l.accountTypeCash,
      _ => type.isEmpty ? l.accountTypeOther : type,
    };

/// The design tiles a bank, a wallet, cash and a card differently; anything
/// unrecognised falls back to the wallet glyph.
IconData accountIcon(String type) => switch (type.toLowerCase()) {
      'bank' => Icons.account_balance,
      'e-wallet' || 'ewallet' || 'wallet' => Icons.account_balance_wallet,
      'cash' => Icons.payments,
      'card' || 'credit' => Icons.credit_card,
      _ => Icons.account_balance_wallet,
    };

/// Add or edit an account. [account] null means add.
Future<void> showAccountFormSheet(
  BuildContext context, {
  Account? account,
}) {
  return showScandySheet<void>(
    context: context,
    title: account == null ? context.l.addAccount : context.l.editAccount,
    child: _AccountForm(account: account),
  );
}

class _AccountForm extends StatefulWidget {
  const _AccountForm({this.account});

  final Account? account;

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  late final _name = TextEditingController(text: widget.account?.name ?? '');
  late final _initial = TextEditingController(
    text: widget.account == null
        ? ''
        : widget.account!.initialBalance.toStringAsFixed(2),
  );
  late String _type = widget.account?.type ?? accountTypes.first;

  String? _nameError;
  String? _balanceError;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _initial.dispose();
    super.dispose();
  }

  bool _validate() {
    final l = context.l;
    final name = _name.text.trim();
    final balance = double.tryParse(_initial.text.trim());
    setState(() {
      _nameError = name.isEmpty ? l.giveTheAccountAName : null;
      _balanceError = _initial.text.trim().isEmpty
          ? l.enterTheStartingBalance
          : balance == null
              ? l.mustBeANumber
              : null;
    });
    return _nameError == null && _balanceError == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _busy = true);

    final state = context.read<AppState>();
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'type': _type,
      'initial_balance': double.parse(_initial.text.trim()),
    };

    try {
      if (widget.account == null) {
        await state.repo.createAccount(body);
      } else {
        await state.repo.updateAccount(widget.account!.id, body);
      }
      await state.refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(context, '$e');
    }
  }

  Future<void> _delete() async {
    final account = widget.account;
    if (account == null) return;

    final l = context.l;
    final confirmed = await confirmDestructive(
      context: context,
      title: l.deleteAccountQ(account.name),
      message: l.deleteAccountBody,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    final state = context.read<AppState>();
    try {
      await state.repo.deleteAccount(account.id);
      await state.refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final l = context.l;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ScandyField(
          label: l.fieldName,
          controller: _name,
          hint: l.hintAccountName,
          autofocus: widget.account == null,
          errorText: _nameError,
        ),
        const SizedBox(height: 14),
        ScandyPickerRow(
          label: l.fieldType,
          value: accountTypeLabel(l, _type),
          placeholder: l.chooseAType,
          onTap: () async {
            final picked = await showScandyPicker<String>(
              context: context,
              title: l.accountType,
              selected: _type,
              options: [
                for (final type in accountTypes)
                  PickerOption(value: type, label: accountTypeLabel(l, type)),
              ],
            );
            if (picked != null) setState(() => _type = picked);
          },
        ),
        const SizedBox(height: 14),
        ScandyField(
          label: l.fieldStartingBalance,
          controller: _initial,
          hint: '0.00',
          prefix: 'RM ',
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true, signed: true),
          errorText: _balanceError,
        ),
        const SizedBox(height: 8),
        Text(
          l.startingBalanceHelp,
          style: ScandyText.sheetItemSubtitle.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: widget.account == null ? l.addAccount : l.actionSaveChanges,
          busy: _busy,
          onPressed: _save,
        ),
        if (widget.account != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : _delete,
            style: TextButton.styleFrom(
              foregroundColor: c.negative,
              minimumSize: const Size.fromHeight(44),
            ),
            child: Text(l.deleteAccount, style: ScandyText.sheetItemTitle),
          ),
        ],
      ],
    );
  }
}

void _toast(BuildContext context, String message) {
  final c = context.scandy;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message,
            style: ScandyText.rowTitle.copyWith(color: c.onAccent)),
        backgroundColor: c.negative,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ScandyRadius.tile),
        ),
      ),
    );
}
