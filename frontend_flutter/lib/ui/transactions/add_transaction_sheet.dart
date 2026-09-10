import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../common/sheets.dart';
import '../common/widgets.dart';

/// What the form is creating. Expense and income both post to
/// `/api/transactions/manual`; a transfer posts to `/api/transactions/transfer`,
/// which writes two linked rows.
enum EntryKind { expense, income, transfer }

/// "Log it by hand" — the manual entry form.
///
/// Not drawn in either handoff file, so it is assembled from the pieces that
/// are: the Add sheet's shell, the Settings segmented control for the type
/// switch, and the same labelled fields the account and recurring forms use.
Future<void> showAddTransactionSheet(
  BuildContext context, {
  Map<String, dynamic>? prefill,
  Transaction? transaction,
}) {
  return showScandySheet<void>(
    context: context,
    title: transaction == null ? 'Log a transaction' : 'Edit transaction',
    child: _AddTransactionForm(prefill: prefill, transaction: transaction),
  );
}

class _AddTransactionForm extends StatefulWidget {
  const _AddTransactionForm({this.prefill, this.transaction});

  /// Optionally seeded from an OCR scan (`amount`, `date`, `description`).
  final Map<String, dynamic>? prefill;

  /// When set the form edits that row instead of creating a new one.
  final Transaction? transaction;

  @override
  State<_AddTransactionForm> createState() => _AddTransactionFormState();
}

class _AddTransactionFormState extends State<_AddTransactionForm> {
  late EntryKind _kind = switch (widget.transaction) {
    null => EntryKind.expense,
    final t when t.isTransfer => EntryKind.transfer,
    final t when t.isIncome => EntryKind.income,
    _ => EntryKind.expense,
  };

  late final _amount = TextEditingController(text: _initialAmount());
  late final _description = TextEditingController(
      text: widget.transaction?.description ??
          widget.prefill?['description'] as String? ??
          '');

  late DateTime _date = widget.transaction?.date ?? _prefillDate();
  late TimeOfDay _time = _initialTime();

  late String? _category = widget.transaction?.category;
  late String? _accountId = widget.transaction?.isTransfer == true
      ? widget.transaction!.fromAccountId
      : widget.transaction?.accountId;
  late String? _toAccountId = widget.transaction?.toAccountId;

  String? _amountError;
  String? _descriptionError;
  String? _accountError;
  bool _busy = false;

  bool get _isEditing => widget.transaction != null;

  TimeOfDay _initialTime() {
    // An edited row wins; otherwise take the time the scanner read off the
    // receipt, which is the whole point of it having read one. Only if neither
    // is available does this fall back to the clock.
    final raw = widget.transaction?.time ?? widget.prefill?['time']?.toString();
    if (raw != null && raw.length >= 5) {
      final h = int.tryParse(raw.substring(0, 2));
      final m = int.tryParse(raw.substring(3, 5));
      if (h != null && m != null && h < 24 && m < 60) {
        return TimeOfDay(hour: h, minute: m);
      }
    }
    return TimeOfDay.fromDateTime(DateTime.now());
  }

  String _initialAmount() {
    final existing = widget.transaction;
    if (existing != null) {
      return (existing.amountCents.abs() / 100).toStringAsFixed(2);
    }
    return _prefillAmount();
  }

  String _prefillAmount() {
    final raw = widget.prefill?['amount'];
    if (raw == null) return '';
    // A scan returns something like "RM 12.34"; keep only the number.
    final cleaned =
        raw.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return cleaned;
  }

  DateTime _prefillDate() {
    final raw = widget.prefill?['date']?.toString();
    if (raw != null) {
      // The scanner returns DD/MM/YYYY.
      final parts = raw.split('/');
      if (parts.length == 3) {
        final d = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (d != null && m != null && y != null) return DateTime(y, m, d);
      }
    }
    return DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _isTransfer => _kind == EntryKind.transfer;

  String? _accountName(AppState state, String? id) {
    if (id == null) return null;
    for (final a in state.accounts) {
      if (a.id == id) return a.name;
    }
    return null;
  }

  Future<void> _pickAccount(
    AppState state, {
    required String title,
    required String? current,
    required ValueChanged<String> onPicked,
  }) async {
    final picked = await showScandyPicker<String>(
      context: context,
      title: title,
      selected: current,
      options: [
        for (final a in state.accounts)
          PickerOption(value: a.id, label: a.name),
      ],
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  List<String> _categoriesFor(AppState state) => switch (_kind) {
        EntryKind.income => state.categories['income'] ?? const [],
        _ => state.categories['expense'] ?? const [],
      };

  bool _validate(AppState state) {
    final amount = double.tryParse(_amount.text.trim());
    final description = _description.text.trim();

    setState(() {
      _amountError = _amount.text.trim().isEmpty
          ? 'Enter an amount'
          : amount == null
              ? 'Must be a number'
              : amount <= 0
                  ? 'Must be more than zero'
                  : null;

      // The backend defaults a transfer's description to "Transfer", so it is
      // optional there and required everywhere else — it is the only label the
      // row will carry.
      _descriptionError =
          !_isTransfer && description.isEmpty ? 'Give it a description' : null;

      if (_isTransfer) {
        _accountError = _accountId == null || _toAccountId == null
            ? 'Pick both accounts'
            : _accountId == _toAccountId
                ? 'From and To must differ'
                : null;
      } else {
        _accountError = state.accounts.isNotEmpty && _accountId == null
            ? 'Pick an account'
            : null;
      }
    });

    return _amountError == null &&
        _descriptionError == null &&
        _accountError == null;
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    if (!_validate(state)) return;
    setState(() => _busy = true);

    // The API takes DD/MM/YYYY and HH:MM:SS (see _to_iso_date/_normalize_time).
    final date = DateFormat('dd/MM/yyyy').format(_date);
    final time = '${_time.hour.toString().padLeft(2, '0')}:'
        '${_time.minute.toString().padLeft(2, '0')}:00';
    final amount = double.parse(_amount.text.trim());
    final description = _description.text.trim();

    try {
      if (_isEditing) {
        // PUT takes the same field names, plus to_account_id when the row is
        // (or becomes) a transfer. The backend rebuilds the pair from scratch.
        await state.repo.updateTransaction(widget.transaction!.id, {
          'date': date,
          'time': time,
          'description': description.isEmpty && _isTransfer
              ? 'Transfer'
              : description,
          'amount': amount,
          'category': _isTransfer ? 'Transfer' : (_category ?? 'Uncategorized'),
          'account_id': _accountId,
          'type': _isTransfer
              ? 'transfer'
              : _kind == EntryKind.income
                  ? 'income'
                  : 'expense',
          if (_isTransfer) 'to_account_id': _toAccountId,
        });
      } else if (_isTransfer) {
        await state.repo.createTransfer({
          'date': date,
          'time': time,
          'description': description.isEmpty ? 'Transfer' : description,
          'amount': amount,
          'from_account_id': _accountId,
          'to_account_id': _toAccountId,
        });
      } else {
        await state.repo.createManualTransaction({
          'date': date,
          'time': time,
          'description': description,
          'amount': amount,
          'category': _category ?? 'Uncategorized',
          'account_id': _accountId,
          'type': _kind == EntryKind.income ? 'income' : 'expense',
        });
      }
      await state.refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _errorToast(context, '$e');
    }
  }

  Future<void> _pickDate() async {
    // 2000 rather than 2015: that is the scanner's own floor (_minYear in
    // receipt_rules.dart), and a date it was willing to read off a receipt has
    // to be openable here. showDatePicker asserts when initialDate falls
    // outside the range, so anything still out of bounds is clamped in.
    final first = DateTime(2000);
    final last = DateTime.now().add(const Duration(days: 365));
    final initial = _date.isBefore(first)
        ? first
        : _date.isAfter(last)
            ? last
            : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final state = context.watch<AppState>();
    final categories = _categoriesFor(state);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScandySegmented<EntryKind>(
          value: _kind,
          onChanged: (k) => setState(() {
            _kind = k;
            // Category lists differ per type, and a transfer has none at all.
            _category = null;
            _accountError = null;
          }),
          options: const [
            SegmentOption(value: EntryKind.expense, label: 'Expense'),
            SegmentOption(value: EntryKind.income, label: 'Income'),
            SegmentOption(value: EntryKind.transfer, label: 'Transfer'),
          ],
        ),
        const SizedBox(height: 16),
        ScandyField(
          label: 'Amount',
          controller: _amount,
          hint: '0.00',
          prefix: 'RM ',
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          errorText: _amountError,
        ),
        const SizedBox(height: 14),
        ScandyField(
          label: _isTransfer ? 'Description (optional)' : 'Description',
          controller: _description,
          hint: _isTransfer ? 'Transfer' : 'Jaya Grocer',
          errorText: _descriptionError,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _PickerTile(
                label: 'Date',
                value: DateFormat('d MMM yyyy').format(_date),
                icon: Icons.calendar_today,
                onTap: _pickDate,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PickerTile(
                label: 'Time',
                value: _time.format(context),
                icon: Icons.schedule,
                onTap: _pickTime,
              ),
            ),
          ],
        ),
        if (!_isTransfer && categories.isNotEmpty) ...[
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
                  for (final category in categories)
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
            label: _isTransfer ? 'From' : 'Account',
            value: _accountName(state, _accountId),
            placeholder: 'Choose an account',
            errorText: _isTransfer ? null : _accountError,
            onTap: () => _pickAccount(
              state,
              title: _isTransfer ? 'From account' : 'Account',
              current: _accountId,
              onPicked: (v) => _accountId = v,
            ),
          ),
          if (_isTransfer) ...[
            const SizedBox(height: 14),
            ScandyPickerRow(
              label: 'To',
              value: _accountName(state, _toAccountId),
              placeholder: 'Choose an account',
              errorText: _accountError,
              onTap: () => _pickAccount(
                state,
                title: 'To account',
                current: _toAccountId,
                onPicked: (v) => _toAccountId = v,
              ),
            ),
          ],
        ],
        const SizedBox(height: 20),
        PrimaryButton(
          label: _isEditing
              ? 'Save changes'
              : _isTransfer
                  ? 'Record transfer'
                  : 'Add transaction',
          busy: _busy,
          onPressed: _save,
        ),
        const SizedBox(height: 8),
        // The Android back gesture also dismisses, but a visible way out
        // matters on a form this long.
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
          style: TextButton.styleFrom(
            foregroundColor: c.textSecondary,
            minimumSize: const Size.fromHeight(44),
          ),
          child: Text('Cancel', style: ScandyText.sheetItemTitle),
        ),
      ],
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: ScandyText.statLabel.copyWith(color: c.textSecondary)),
        const SizedBox(height: 6),
        Material(
          color: c.surfaceMuted,
          borderRadius: BorderRadius.circular(ScandyRadius.tile),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: c.iconMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ScandyText.rowTitle
                            .copyWith(color: c.textPrimary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

void _errorToast(BuildContext context, String message) {
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
