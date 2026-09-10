import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../common/widgets.dart';

enum AddAction { scanReceipt, logByHand }

/// The "Add a transaction" card that rises above the scrim.
///
/// In the design this sits 96px off the bottom, inset 14px each side, with the
/// bottom nav drawn *over* the scrim rather than under it — so the card reads
/// as attached to the ADD button. The shell owns that stacking; this widget is
/// just the card.
class AddSheet extends StatelessWidget {
  const AddSheet({super.key, required this.onSelected});

  final ValueChanged<AddAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final l = context.l;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(ScandyRadius.sheet),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(
              l.addATransaction.toUpperCase(),
              style: ScandyText.sheetEyebrow.copyWith(color: c.textSecondary),
            ),
          ),
          SheetOptionRow(
            icon: Icons.photo_camera,
            iconColor: c.onAccent,
            tileColor: c.accent,
            title: l.scanAReceipt,
            subtitle: l.scanAReceiptSubtitle,
            onTap: () => onSelected(AddAction.scanReceipt),
          ),
          const SizedBox(height: 4),
          SheetOptionRow(
            icon: Icons.edit_note,
            iconColor: c.textTertiary,
            tileColor: c.surfaceMuted,
            title: l.logItByHand,
            subtitle: l.logItByHandSubtitle,
            onTap: () => onSelected(AddAction.logByHand),
          ),
        ],
      ),
    );
  }
}
