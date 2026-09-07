import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// The card every section is built from: surface fill, 1px border, and a
/// radius that varies only by role (20 for a hero panel, 18 for a list).
class ScandyCard extends StatelessWidget {
  const ScandyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = ScandyRadius.card,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// List cards clip so row dividers and ink stop at the rounded corner.
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Container(
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      padding: clip ? null : padding,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: clip ? child : child,
    );
  }
}

/// Screen title + optional subtitle, and an optional trailing action.
/// "Monthly summary / Where your money went", "Accounts" + an add button.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: ScandyText.greeting.copyWith(color: c.textPrimary)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    style: ScandyText.greetingMeta
                        .copyWith(color: c.textSecondary)),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

/// "Where it went" + "All 6" — a section title with an optional trailing link.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(title,
              style: ScandyText.sectionTitle.copyWith(color: c.textPrimary)),
        ),
        if (actionLabel != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(actionLabel!,
                  style: ScandyText.link.copyWith(color: c.accent)),
            ),
          ),
      ],
    );
  }
}

/// The 44×44 filled accent button that heads Accounts and Recurring.
class AccentIconButton extends StatelessWidget {
  const AccentIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: c.accent,
        borderRadius: BorderRadius.circular(ScandyRadius.tileLarge),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 23, color: c.onAccent),
          ),
        ),
      ),
    );
  }
}

/// An uppercase group label above a card — "APPEARANCE", "CATEGORIES".
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Text(text.toUpperCase(),
        style: ScandyText.sheetEyebrow.copyWith(color: c.textSecondary));
  }
}

/// A thin proportion bar. Used for category share on Summary (7px) and, at
/// 9px, for the safe-to-spend track.
class ProportionBar extends StatelessWidget {
  const ProportionBar({
    super.key,
    required this.fraction,
    required this.color,
    this.height = 7,
  });

  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final f = fraction.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(ScandyRadius.pill),
      // Width must be explicit and the cross axis stretched, or the childless
      // ColoredBox segments collapse — see SafeToSpendCard for the long story.
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: (f * 10000).round(), child: ColoredBox(color: color)),
            Expanded(
                flex: ((1 - f) * 10000).round(),
                child: ColoredBox(color: c.divider)),
          ],
        ),
      ),
    );
  }
}

/// Full-width primary action, as used on every sheet and form.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          disabledBackgroundColor: c.accent.withValues(alpha: 0.5),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ScandyRadius.tile),
          ),
        ),
        child: busy
            ? SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: c.onAccent),
              )
            : Text(label, style: ScandyText.sheetItemTitle),
      ),
    );
  }
}

/// Empty state inside a list card, matching the Home "Nothing logged yet" block.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 28, color: c.iconMuted),
          const SizedBox(height: 10),
          Text(title, style: ScandyText.rowTitle.copyWith(color: c.textPrimary)),
          const SizedBox(height: 4),
          Text(message,
              textAlign: TextAlign.center,
              style: ScandyText.rowMeta.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}

/// The 44×44 outlined button used in the section headers — search, settings.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(ScandyRadius.tileLarge),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(ScandyRadius.tileLarge),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(ScandyRadius.tileLarge),
            ),
            child: Icon(icon, size: 22, color: c.textTertiary),
          ),
        ),
      ),
    );
  }
}

/// Search + settings, in that order, top-right of every section.
///
/// The design only draws search (on Home) and puts Settings in the desktop
/// sidebar. Keeping both on all four tabs makes the header predictable and
/// gives Settings a reachable home on mobile, where the nav has no slot for it.
class HeaderActions extends StatelessWidget {
  const HeaderActions({super.key, required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SquareIconButton(
          icon: Icons.search,
          tooltip: 'Search transactions',
          onPressed: onSearch,
        ),
        const SizedBox(width: 10),
        SquareIconButton(
          icon: Icons.settings,
          tooltip: 'Settings',
          onPressed: () => Navigator.of(context).pushNamed('/settings'),
        ),
      ],
    );
  }
}

/// Floating "+" for Accounts and Recurring.
///
/// Sits bottom-right, clear of the nav bar, rather than in the header — the
/// header is reserved for search and settings across every section. Sized and
/// shadowed like the nav's ADD button so the two read as the same family.
class ScandyFab extends StatelessWidget {
  const ScandyFab({super.key, required this.onPressed, this.tooltip});

  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Tooltip(
      message: tooltip ?? '',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: c.accent.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: c.accent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(Icons.add, size: 26, color: c.onAccent),
            ),
          ),
        ),
      ),
    );
  }
}

/// Overlays a [ScandyFab] on a scrolling section, clear of the bottom nav.
class FabScaffold extends StatelessWidget {
  const FabScaffold({
    super.key,
    required this.child,
    required this.onPressed,
    this.tooltip,
    required this.navHeight,
  });

  final Widget child;
  final VoidCallback onPressed;
  final String? tooltip;
  final double navHeight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          right: 18,
          bottom: navHeight + 16,
          child: ScandyFab(onPressed: onPressed, tooltip: tooltip),
        ),
      ],
    );
  }
}

/// One option in a [ScandySegmented].
class SegmentOption<T> {
  const SegmentOption({required this.value, required this.label, this.icon});
  final T value;
  final String label;

  /// Omitted for compact rows, where the label alone carries the meaning.
  final IconData? icon;
}

/// The inset-track segmented control the design uses for Settings > Theme,
/// generalised so the transaction form's type switch is visibly the same
/// control rather than a lookalike.
class ScandySegmented<T> extends StatelessWidget {
  const ScandySegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.segmentTrack,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(ScandyRadius.tileLarge),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: _Segment<T>(
                option: option,
                selected: option.value == value,
                onTap: () => onChanged(option.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final SegmentOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final fg = selected ? c.textPrimary : c.textTertiary;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          constraints: BoxConstraints(minHeight: option.icon == null ? 44 : 56),
          decoration: selected
              ? BoxDecoration(
                  color: c.segmentSelected,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                )
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (option.icon != null) ...[
                Icon(option.icon, size: 20, color: fg),
                const SizedBox(height: 4),
              ],
              Text(
                option.label,
                style: (selected
                        ? ScandyText.segmentLabelActive
                        : ScandyText.segmentLabel)
                    .copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tappable row in a sheet: 44px icon tile, title, and a line of
/// explanation. Taken from the design's "Add a transaction" sheet, which is
/// the only modal it draws, so every later sheet inherits the same rhythm.
class SheetOptionRow extends StatelessWidget {
  const SheetOptionRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.tileColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color tileColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(ScandyRadius.row),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ScandyRadius.row),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(ScandyRadius.tileLarge),
                ),
                child: Icon(icon, size: 23, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style:
                          ScandyText.sheetItemTitle.copyWith(color: c.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: ScandyText.sheetItemSubtitle
                          .copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
