import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/account.dart';
import '../../models/subscription.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../common/sheets.dart';
import '../common/widgets.dart';

/// Add or edit a recurring charge. [subscription] null means add.
Future<void> showSubscriptionFormSheet(
  BuildContext context, {
  Subscription? subscription,
}) {
  return showScandySheet<void>(
    context: context,
    title: subscription == null ? 'Add recurring charge' : 'Edit recurring charge',
    child: _SubscriptionForm(subscription: subscription),
  );
}

class _SubscriptionForm extends StatefulWidget {
  const _SubscriptionForm({this.subscription});

  final Subscription? subscription;

  @override
  State<_SubscriptionForm> createState() => _SubscriptionFormState();
}

class _SubscriptionFormState extends State<_SubscriptionForm> {
  late final _name =
      TextEditingController(text: widget.subscription?.name ?? '');
  late final _amount = TextEditingController(
    text: widget.subscription == null
        ? ''
        : widget.subscription!.amount.toStringAsFixed(2),
  );
  late final _day = TextEditingController(
    text: (widget.subscription?.dayOfMonth ?? 1).toString(),
  );
  late String? _category = widget.subscription?.category;
  late String? _accountId = widget.subscription?.accountId;

  String? _nameError;
  String? _amountError;
  String? _dayError;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _day.dispose();
    super.dispose();
  }

  bool _validate() {
    final amount = double.tryParse(_amount.text.trim());
    final day = int.tryParse(_day.text.trim());
    setState(() {
      _nameError = _name.text.trim().isEmpty ? 'Give it a name' : null;
      _amountError = amount == null ? 'Must be a number' : null;
      // Matches the backend's own check in _validate_subscription.
      _dayError = day == null || day < 1 || day > 31
          ? 'Pick a day between 1 and 31'
          : null;
    });
    return _nameError == null && _amountError == null && _dayError == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _busy = true);

    final state = context.read<AppState>();
    final existing = widget.subscription;
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'amount': double.parse(_amount.text.trim()),
      'category': _category ?? 'Bills & Utilities',
      'day_of_month': int.parse(_day.text.trim()),
      'account_id': _accountId,
      // Preserved so editing does not make an already-charged month look due
      // again — the backend replaces the whole record.
      if (existing?.lastRecordedDate != null)
        'last_recorded_date':
            existing!.lastRecordedDate!.toIso8601String().split('T').first,
    };

    try {
      if (existing == null) {
        await state.api.createSubscription(body);
      } else {
        await state.api.updateSubscription(existing.id, body);
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
    final existing = widget.subscription;
    if (existing == null) return;

    final confirmed = await confirmDestructive(
      context: context,
      title: 'Delete ${existing.name}?',
      message: 'It stops counting towards your monthly commitment. '
          'Charges already recorded stay in your transactions.',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    final state = context.read<AppState>();
    try {
      await state.api.deleteSubscription(existing.id);
      await state.refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(context, '$e');
    }
  }

  static String? _accountName(List<Account> accounts, String? id) {
    if (id == null) return null;
    for (final a in accounts) {
      if (a.id == id) return a.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final state = context.watch<AppState>();
    final expenseCategories = state.categories['expense'] ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ScandyField(
          label: 'Name',
          controller: _name,
          hint: 'Spotify Family',
          autofocus: widget.subscription == null,
          errorText: _nameError,
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ScandyField(
                label: 'Amount',
                controller: _amount,
                hint: '0.00',
                prefix: 'RM ',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                errorText: _amountError,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              child: ScandyField(
                label: 'Day',
                controller: _day,
                hint: '1',
                keyboardType: TextInputType.number,
                errorText: _dayError,
              ),
            ),
          ],
        ),
        if (expenseCategories.isNotEmpty) ...[
          const SizedBox(height: 14),
          ScandyPickerRow(
            label: 'Category',
            value: _category,
            placeholder: 'Choose a category',
            onTap: () async {
              final picked = await showScandyPicker<String>(
                context: context,
                title: 'Category',
                selected: _category,
                options: [
                  for (final category in expenseCategories)
                    PickerOption(value: category, label: category),
                ],
              );
              if (picked != null) setState(() => _category = picked);
            },
          ),
        ],
        if (state.accounts.isNotEmpty) ...[
          const SizedBox(height: 14),
          ScandyPickerRow(
            label: 'Charged to',
            value: _accountName(state.accounts, _accountId),
            placeholder: 'Choose an account',
            onTap: () async {
              final picked = await showScandyPicker<String>(
                context: context,
                title: 'Charged to',
                selected: _accountId,
                options: [
                  for (final account in state.accounts)
                    PickerOption(value: account.id, label: account.name),
                ],
              );
              if (picked != null) setState(() => _accountId = picked);
            },
          ),
        ],
        const SizedBox(height: 20),
        PrimaryButton(
          label: widget.subscription == null ? 'Add charge' : 'Save changes',
          busy: _busy,
          onPressed: _save,
        ),
        if (widget.subscription != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : _delete,
            style: TextButton.styleFrom(
              foregroundColor: c.negative,
              minimumSize: const Size.fromHeight(44),
            ),
            child: Text('Delete charge', style: ScandyText.sheetItemTitle),
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
