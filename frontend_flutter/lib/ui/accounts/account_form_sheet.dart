import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/account.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../common/sheets.dart';
import '../common/widgets.dart';

/// Account types the backend's own data uses (`backend/accounts.json`).
const accountTypes = ['Bank', 'E-Wallet', 'Card', 'Cash'];

/// Add or edit an account. [account] null means add.
Future<void> showAccountFormSheet(
  BuildContext context, {
  Account? account,
}) {
  return showScandySheet<void>(
    context: context,
    title: account == null ? 'Add account' : 'Edit account',
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
    final name = _name.text.trim();
    final balance = double.tryParse(_initial.text.trim());
    setState(() {
      _nameError = name.isEmpty ? 'Give the account a name' : null;
      _balanceError = _initial.text.trim().isEmpty
          ? 'Enter the starting balance'
          : balance == null
              ? 'Must be a number'
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
        await state.api.createAccount(body);
      } else {
        await state.api.updateAccount(widget.account!.id, body);
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

    final confirmed = await confirmDestructive(
      context: context,
      title: 'Delete ${account.name}?',
      message:
          'The account is removed from the list. Transactions recorded against '
          'it are kept, but will no longer be attributed to an account.',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    final state = context.read<AppState>();
    try {
      await state.api.deleteAccount(account.id);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ScandyField(
          label: 'Name',
          controller: _name,
          hint: 'Maybank',
          autofocus: widget.account == null,
          errorText: _nameError,
        ),
        const SizedBox(height: 14),
        ScandyPickerRow(
          label: 'Type',
          value: _type,
          placeholder: 'Choose a type',
          onTap: () async {
            final picked = await showScandyPicker<String>(
              context: context,
              title: 'Account type',
              selected: _type,
              options: [
                for (final type in accountTypes)
                  PickerOption(value: type, label: type),
              ],
            );
            if (picked != null) setState(() => _type = picked);
          },
        ),
        const SizedBox(height: 14),
        ScandyField(
          label: 'Starting balance',
          controller: _initial,
          hint: '0.00',
          prefix: 'RM ',
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true, signed: true),
          errorText: _balanceError,
        ),
        const SizedBox(height: 8),
        Text(
          'The balance shown on the Accounts screen is this figure plus every '
          'transaction recorded against the account.',
          style: ScandyText.sheetItemSubtitle.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: widget.account == null ? 'Add account' : 'Save changes',
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
            child: Text('Delete account', style: ScandyText.sheetItemTitle),
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
