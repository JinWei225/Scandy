import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/account.dart';
import '../../models/subscription.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../util/formatting.dart';
import '../common/sheets.dart';
import '../common/widgets.dart';

/// Add or edit a recurring charge. [subscription] null means add.
Future<void> showSubscriptionFormSheet(
  BuildContext context, {
  Subscription? subscription,
}) {
  return showScandySheet<void>(
    context: context,
    title: subscription == null
        ? context.l.addRecurringCharge
        : context.l.editRecurringCharge,
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
    final l = context.l;
    final amount = double.tryParse(_amount.text.trim());
    final day = int.tryParse(_day.text.trim());
    setState(() {
      _nameError = _name.text.trim().isEmpty ? l.giveItAName : null;
      // Same ladder as the transaction form, and as the backend's
      // _validate_subscription — all three should agree on what an amount is.
      _amountError = _amount.text.trim().isEmpty
          ? l.enterAnAmount
          : amount == null
              ? l.mustBeANumber
              : amount <= 0
                  ? l.mustBeMoreThanZero
                  : null;
      // Matches the backend's own check in _validate_subscription.
      _dayError =
          day == null || day < 1 || day > 31 ? l.pickADayBetween1And31 : null;
    });
    return _nameError == null && _amountError == null && _dayError == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _busy = true);

    final state = context.read<AppState>();
    final existing = widget.subscription;
    // Falling back to a hard-coded 'Bills & Utilities' filed the charge under
    // a category the account might not have -- which is every Chinese account,
    // whose starter list has no row by that name. The person's own first
    // expense category is a real one, whatever it is called.
    final expenseCategories = state.categories['expense'] ?? const <String>[];
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'amount': double.parse(_amount.text.trim()),
      'category': _category ??
          (expenseCategories.isEmpty ? 'Other' : expenseCategories.first),
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
        await state.repo.createSubscription(body);
      } else {
        await state.repo.updateSubscription(existing.id, body);
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

    final l = context.l;
    final confirmed = await confirmDestructive(
      context: context,
      title: l.deleteChargeQ(existing.name),
      message: l.deleteChargeBody,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    final state = context.read<AppState>();
    try {
      await state.repo.deleteSubscription(existing.id);
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
    final l = context.l;
    final state = context.watch<AppState>();
    final expenseCategories = state.categories['expense'] ?? const <String>[];
    final categoryLabel =
        _category == null ? null : displayCategory(l, _category!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ScandyField(
          label: l.fieldName,
          controller: _name,
          hint: l.hintSubscriptionName,
          autofocus: widget.subscription == null,
          errorText: _nameError,
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ScandyField(
                label: l.fieldAmount,
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
                label: l.fieldDay,
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
            label: l.fieldCategory,
            value: categoryLabel,
            placeholder: l.chooseACategory,
            onTap: () async {
              final picked = await showScandyPicker<String>(
                context: context,
                title: l.fieldCategory,
                selected: _category,
                options: [
                  for (final category in expenseCategories)
                    PickerOption(
                        value: category, label: displayCategory(l, category)),
                ],
              );
              if (picked != null) setState(() => _category = picked);
            },
          ),
        ],
        if (state.accounts.isNotEmpty) ...[
          const SizedBox(height: 14),
          ScandyPickerRow(
            label: l.fieldChargedTo,
            value: _accountName(state.accounts, _accountId),
            placeholder: l.chooseAnAccount,
            onTap: () async {
              final picked = await showScandyPicker<String>(
                context: context,
                title: l.fieldChargedTo,
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
          label: widget.subscription == null
              ? l.addCharge
              : l.actionSaveChanges,
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
            child: Text(l.deleteCharge, style: ScandyText.sheetItemTitle),
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
