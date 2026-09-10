import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../common/sheets.dart';
import '../common/widgets.dart';

/// Asks where the receipt image should come from.
///
/// "Scan a receipt" used to open the camera outright, which is wrong whenever
/// the receipt is already a photo — a screenshot of an e-receipt, or one taken
/// earlier. Returns null if the sheet is dismissed.
Future<ImageSource?> showScanSourceSheet(BuildContext context) {
  return showScandySheet<ImageSource>(
    context: context,
    title: context.l.scanAReceipt,
    child: Builder(
      builder: (sheetContext) {
        final c = sheetContext.scandy;
        final l = sheetContext.l;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetOptionRow(
              icon: Icons.photo_camera,
              iconColor: c.onAccent,
              tileColor: c.accent,
              title: l.takeAPhoto,
              subtitle: l.takeAPhotoSubtitle,
              onTap: () =>
                  Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            const SizedBox(height: 4),
            SheetOptionRow(
              icon: Icons.photo_library,
              iconColor: c.textTertiary,
              tileColor: c.surfaceMuted,
              title: l.chooseFromGallery,
              subtitle: l.chooseFromGallerySubtitle,
              onTap: () =>
                  Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        );
      },
    ),
  );
}
