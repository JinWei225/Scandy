import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'widgets.dart';

/// Scrim opacity and colour are taken from the one modal the design does
/// specify — the "Add a transaction" sheet on Home.
const scandyScrim = Color(0xFF24201C);
const scandyScrimOpacity = 0.42;

Color scrimColor() => scandyScrim.withValues(alpha: scandyScrimOpacity);

/// A bottom sheet in the house style.
///
/// The handoff never draws a form modal, so this is derived from the pieces it
/// does draw: the Add sheet's 14px side inset, 22px radius, 1px border and
/// surface fill, with the same uppercase eyebrow it uses for "ADD A
/// TRANSACTION". Everything the app opens as a modal goes through here so the
/// sections stay uniform.
Future<T?> showScandySheet<T>({
  required BuildContext context,
  required String title,
  required Widget child,
  List<Widget> actions = const [],
  bool fullHeight = false,
}) {
  final c = context.scandy;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: scrimColor(),
    isScrollControlled: true,
    // On a wide window a full-width sheet would run the length of the screen;
    // this keeps it phone-shaped and centred, which is also how every form
    // inside it was laid out.
    constraints: const BoxConstraints(maxWidth: 560),
    // Without this the route is free to lay the sheet out over the status bar
    // — the height maths below alone cannot prevent it, because the sheet is
    // anchored to the bottom and simply grows past the top edge.
    useSafeArea: true,
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final viewInsets = media.viewInsets.bottom;
      // useSafeArea has already taken the status bar out of the route's box,
      // so only the keyboard and a small breathing gap come off here.
      // Subtracting padding.top again would double-count it.
      final available = media.size.height - viewInsets - 12;
      return Padding(
        // Lifts the sheet clear of the keyboard when a field inside is focused.
        padding: EdgeInsets.only(bottom: viewInsets),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: SafeArea(
            top: false,
            child: Container(
              // fullHeight sheets are pinned open at their maximum from the
              // start. Search autofocuses its field, so a content-sized sheet
              // would open small and then leap to the top the instant the
              // keyboard appeared.
              height: fullHeight
                  ? available.clamp(200.0, media.size.height)
                  : null,
              // `available` already excludes the status bar and the keyboard,
              // so it is the real ceiling — a flat 90%-of-screen cap let a tall
              // sheet slide under the status bar.
              constraints: BoxConstraints(
                maxHeight: available.clamp(200.0, media.size.height),
              ),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(ScandyRadius.sheet),
              ),
              child: Column(
                mainAxisSize: fullHeight ? MainAxisSize.max : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: GroupLabel(title),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: child,
                    ),
                  ),
                  if (actions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: actions,
                      ),
                    )
                  else
                    const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Destructive confirmation. Centred rather than anchored to the bottom, so it
/// reads as a stop rather than as another step in a flow.
Future<bool> confirmDestructive({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmLabel,
}) async {
  final c = context.scandy;
  final l = context.l;
  final confirm = confirmLabel ?? l.actionDelete;
  final result = await showDialog<bool>(
    context: context,
    barrierColor: scrimColor(),
    // A dialog route carries no Material of its own, and text outside one
    // inherits Flutter's debug style — a yellow double underline. The card is
    // drawn by a Container, so the Material is a transparent one above it.
    builder: (dialogContext) => Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(ScandyRadius.sheet),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.negativeSoft,
                  borderRadius: BorderRadius.circular(ScandyRadius.tileLarge),
                ),
                child: Icon(Icons.delete_outline, size: 22, color: c.negative),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: ScandyText.sheetItemTitle.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: ScandyText.sheetItemSubtitle.copyWith(
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.negative,
                    foregroundColor: c.onAccent,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ScandyRadius.tile),
                    ),
                  ),
                  child: Text(confirm, style: ScandyText.sheetItemTitle),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: c.textSecondary,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: Text(l.actionCancel, style: ScandyText.sheetItemTitle),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}

/// Labelled input, styled like the Settings server field so every form in the
/// app looks the same.
class ScandyField extends StatelessWidget {
  const ScandyField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.autofocus = false,
    this.prefix,
    this.errorText,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool autofocus;
  final String? prefix;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: ScandyText.statLabel.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          autofocus: autofocus,
          autocorrect: false,
          style: ScandyText.rowTitleLarge.copyWith(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: ScandyText.rowTitleLarge.copyWith(color: c.iconMuted),
            errorText: errorText,
            errorStyle: ScandyText.sheetItemSubtitle.copyWith(
              color: c.negative,
            ),
            // Rendered as a prefixIcon rather than prefixText: Flutter only
            // paints prefixText while the field has focus, so an empty, blurred
            // amount field would read as a bare "0.00" with no currency.
            prefixIcon: prefix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 14, right: 2),
                    child: Align(
                      widthFactor: 1,
                      child: Text(
                        prefix!,
                        style: ScandyText.rowTitleLarge.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            filled: true,
            fillColor: c.surfaceMuted,
            contentPadding: EdgeInsets.symmetric(
              horizontal: prefix == null ? 14 : 0,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ScandyRadius.tile),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ScandyRadius.tile),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ScandyRadius.tile),
              borderSide: BorderSide(color: c.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Single-choice row list used inside sheets for account/category pickers.
class ScandyChoiceTile<T> extends StatelessWidget {
  const ScandyChoiceTile({
    super.key,
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onSelected,
  });

  final String label;
  final T value;
  final T? groupValue;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onSelected(value),
      borderRadius: BorderRadius.circular(ScandyRadius.tile),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: ScandyText.rowTitleLarge.copyWith(
                  color: selected ? c.textPrimary : c.textTertiary,
                ),
              ),
            ),
            if (selected) Icon(Icons.check, size: 20, color: c.accent),
          ],
        ),
      ),
    );
  }
}

/// One choice in a [showScandyPicker] list.
class PickerOption<T> {
  const PickerOption({required this.value, required this.label});
  final T value;
  final String label;
}

/// Opens a list of choices as its own sheet and returns the picked value.
///
/// Replaces the always-open scrolling boxes the forms used to embed: those
/// nested a scroll region inside a scrolling sheet, which made long lists feel
/// like the sheet was stuck, and hid the current selection until you scrolled.
Future<T?> showScandyPicker<T>({
  required BuildContext context,
  required String title,
  required List<PickerOption<T>> options,
  required T? selected,
}) {
  // Dismiss the keyboard first, or the picker opens squeezed above it.
  FocusManager.instance.primaryFocus?.unfocus();

  return showScandySheet<T>(
    context: context,
    title: title,
    child: Builder(
      builder: (sheetContext) {
        final c = sheetContext.scandy;
        return Container(
          decoration: BoxDecoration(
            color: c.surfaceMuted,
            borderRadius: BorderRadius.circular(ScandyRadius.tile),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in options)
                ScandyChoiceTile<T>(
                  label: option.label,
                  value: option.value,
                  groupValue: selected,
                  onSelected: (v) => Navigator.of(sheetContext).pop(v),
                ),
            ],
          ),
        );
      },
    ),
  );
}

/// A collapsed field that shows the current choice and opens a picker on tap.
class ScandyPickerRow extends StatelessWidget {
  const ScandyPickerRow({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.errorText,
  });

  final String label;

  /// Null renders [placeholder] in the muted colour.
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final chosen = value != null && value!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: ScandyText.statLabel.copyWith(color: c.textSecondary),
        ),
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
                  Expanded(
                    child: Text(
                      chosen ? value! : placeholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ScandyText.rowTitleLarge.copyWith(
                        color: chosen ? c.textPrimary : c.iconMuted,
                      ),
                    ),
                  ),
                  Icon(Icons.expand_more, size: 20, color: c.iconMuted),
                ],
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: ScandyText.sheetItemSubtitle.copyWith(color: c.negative),
          ),
        ],
      ],
    );
  }
}
