import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// The pieces every desktop frame in the handoff is assembled from.
///
/// The desktop frames are a different composition to the phone ones — cards
/// sit in grids, lists become tables with column headers, and actions are
/// labelled buttons rather than icons — so they get their own widgets rather
/// than stretched versions of the mobile ones.

/// Window width at which the shell swaps the bottom bar for the sidebar.
///
/// The desktop frame is 1240px and the phone frame 390px, with nothing drawn
/// in between; 900 is where the tables stop being cramped — a portrait tablet
/// still gets the phone composition, which is the one that fits it.
const desktopBreakpoint = 900.0;

/// Gap between the blocks of a desktop page (the frames use 20–22px).
const desktopGap = 20.0;

/// Content padding inside the main column: 26px top, 30px sides, 34px bottom.
const desktopPadding = EdgeInsets.fromLTRB(30, 26, 30, 34);

/// The design frame is 1240px wide with a 236px sidebar, so its content column
/// is a little over 1000px. Past that the tables just get airier, so the
/// column is capped and centred instead of stretching across a 4K display.
const desktopContentMaxWidth = 1080.0;

/// Vertically scrolling page body, capped and centred.
class DesktopPage extends StatelessWidget {
  const DesktopPage({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        padding: desktopPadding,
        // topCenter, not Center: a short page (Recurring with three charges)
        // would otherwise float in the middle of the window.
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: desktopContentMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// Page title over an optional subtitle, with actions hard right.
class DesktopHeader extends StatelessWidget {
  const DesktopHeader({
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style:
                      ScandyDesktopText.pageTitle.copyWith(color: c.textPrimary)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!,
                    style: ScandyDesktopText.pageSubtitle
                        .copyWith(color: c.textSecondary)),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 20), trailing!],
      ],
    );
  }
}

/// Accounts and Recurring lead with a figure instead of a subtitle: title,
/// then an uppercase label, then the number at 40px.
///
/// Two trailing slots, not one. [titleTrailing] rides the title line, where
/// search belongs — it reads as page chrome. [trailing] sits at the bottom
/// beside the figure, which is where the frame puts the add button. Putting
/// both in one cluster made search look like part of "Add account".
class DesktopFigureHeader extends StatelessWidget {
  const DesktopFigureHeader({
    super.key,
    required this.title,
    required this.label,
    required this.figure,
    this.figureColor,
    this.titleTrailing,
    this.trailing,
  });

  final String title;
  final String label;
  final String figure;
  final Color? figureColor;
  final Widget? titleTrailing;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title,
                  style: ScandyDesktopText.pageTitle
                      .copyWith(color: c.textPrimary)),
            ),
            if (titleTrailing != null) ...[
              const SizedBox(width: 20),
              titleTrailing!,
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label.toUpperCase(),
                      style: ScandyDesktopText.eyebrow
                          .copyWith(color: c.textSecondary)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(figure,
                        style: ScandyDesktopText.bigFigure
                            .copyWith(color: figureColor ?? c.textPrimary)),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 20), trailing!],
          ],
        ),
      ],
    );
  }
}

/// Filled accent button with a leading glyph — "Scan receipt", "Add account".
class DesktopAccentButton extends StatelessWidget {
  const DesktopAccentButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.height = 42,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Material(
      color: c.accent,
      borderRadius: BorderRadius.circular(ScandyRadius.tile),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        hoverColor: c.accentPressed,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: c.onAccent),
              const SizedBox(width: 9),
              Text(label,
                  style: ScandyDesktopText.buttonLabel
                      .copyWith(color: c.onAccent)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 42px outlined square — the desktop search button.
class DesktopIconButton extends StatelessWidget {
  const DesktopIconButton({
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
        borderRadius: BorderRadius.circular(ScandyRadius.tile),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(ScandyRadius.tile),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(ScandyRadius.tile),
            ),
            child: Icon(icon, size: 21, color: c.textTertiary),
          ),
        ),
      ),
    );
  }
}

/// The borderless 32px glyph button that ends every table row.
class RowActionButton extends StatelessWidget {
  const RowActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.hoverColor,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  /// Edit tints accent on hover, delete tints red — the design draws both.
  final Color? hoverColor;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(9),
        hoverColor: (hoverColor ?? c.accent).withValues(alpha: 0.12),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 18, color: c.iconMuted),
        ),
      ),
    );
  }
}

/// Edit + delete, right-aligned, as the "Actions" column of every table.
class RowActions extends StatelessWidget {
  const RowActions({super.key, required this.onEdit, this.onDelete});

  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        RowActionButton(
          icon: Icons.edit,
          tooltip: 'Edit',
          onPressed: onEdit,
        ),
        if (onDelete != null)
          RowActionButton(
            icon: Icons.delete,
            tooltip: 'Delete',
            hoverColor: c.negative,
            onPressed: onDelete!,
          ),
      ],
    );
  }
}

/// The pill that carries a category inside a row.
class DesktopChip extends StatelessWidget {
  const DesktopChip({super.key, required this.label, this.income = false});

  final String label;

  /// Income rows use the green tint; everything else is neutral.
  final bool income;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: income ? c.positiveSoft : c.surfaceMuted,
        borderRadius: BorderRadius.circular(ScandyRadius.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: ScandyDesktopText.chip
            .copyWith(color: income ? c.onPositiveSoft : c.textTertiary),
      ),
    );
  }
}

/// A small tinted count pill — "6 categories", "24 days left".
class DesktopBadge extends StatelessWidget {
  const DesktopBadge({
    super.key,
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ScandyRadius.pill),
      ),
      child: Text(label, style: ScandyDesktopText.pill.copyWith(color: color)),
    );
  }
}

/// One of the 3- or 4-up cards at the top of Summary and Recurring.
class DesktopStatCard extends StatelessWidget {
  const DesktopStatCard({
    super.key,
    required this.label,
    required this.value,
    this.meta,
    this.valueColor,
    this.accent = false,
  });

  final String label;
  final String value;
  final String? meta;
  final Color? valueColor;

  /// "Next charge" is drawn in the accent tint rather than on surface.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final labelColor = accent ? c.onAccentSoft : c.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 17),
      decoration: BoxDecoration(
        color: accent ? c.accentSoft : c.surface,
        border: Border.all(color: accent ? c.accentSoft : c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(),
              style:
                  ScandyDesktopText.tableHeader.copyWith(color: labelColor)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                maxLines: 1,
                style: ScandyDesktopText.statValue
                    .copyWith(color: valueColor ?? c.textPrimary)),
          ),
          if (meta != null) ...[
            const SizedBox(height: 6),
            Text(meta!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ScandyDesktopText.statMeta.copyWith(color: labelColor)),
          ],
        ],
      ),
    );
  }
}

/// Equal-width cards in a row, with the design's 14px gutter.
class DesktopCardRow extends StatelessWidget {
  const DesktopCardRow({super.key, required this.children, this.gap = 14});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

/// A white panel: optional heading strip over a body, 16px radius, clipped so
/// row dividers and hover fills stop at the corner.
class DesktopPanel extends StatelessWidget {
  const DesktopPanel({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.fromLTRB(22, 17, 22, 17),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.dividerStrong)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title!,
                            style: ScandyDesktopText.cardTitle
                                .copyWith(color: c.textPrimary)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 5),
                          Text(subtitle!,
                              style: ScandyDesktopText.actionSubtitle
                                  .copyWith(color: c.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// Column widths for a table. A null width means "take the remaining space";
/// every frame in the handoff has exactly one such column.
typedef TableColumns = List<double?>;

/// Lays cells out on [columns] with the design's 16px gutter. Used for both
/// the header strip and the rows, so they can never drift apart.
Row desktopCells(TableColumns columns, List<Widget> cells) {
  assert(columns.length == cells.length);
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      for (var i = 0; i < cells.length; i++) ...[
        if (i > 0) const SizedBox(width: 16),
        if (columns[i] == null)
          Expanded(child: cells[i])
        else
          SizedBox(width: columns[i], child: cells[i]),
      ],
    ],
  );
}

/// The uppercase column-header strip that opens every desktop table.
class DesktopTableHeader extends StatelessWidget {
  const DesktopTableHeader({
    super.key,
    required this.columns,
    required this.labels,
    this.alignRight = const {},
  });

  final TableColumns columns;
  final List<String> labels;

  /// Indices whose label is right-aligned — Amount and Actions, per the frames.
  final Set<int> alignRight;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
      decoration: BoxDecoration(
        color: c.page,
        border: Border(bottom: BorderSide(color: c.dividerStrong)),
      ),
      child: desktopCells(columns, [
        for (var i = 0; i < labels.length; i++)
          Text(
            labels[i].toUpperCase(),
            textAlign: alignRight.contains(i) ? TextAlign.right : TextAlign.left,
            style:
                ScandyDesktopText.tableHeader.copyWith(color: c.textSecondary),
          ),
      ]),
    );
  }
}

/// One table row: hover fill, a rule underneath except on the last.
class DesktopTableRow extends StatelessWidget {
  const DesktopTableRow({
    super.key,
    required this.columns,
    required this.cells,
    this.onTap,
    this.showDivider = true,
    this.verticalPadding = 14,
  });

  final TableColumns columns;
  final List<Widget> cells;
  final VoidCallback? onTap;
  final bool showDivider;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: c.page.withValues(alpha: 0.6),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: 22, vertical: verticalPadding),
          decoration: showDivider
              ? BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.divider)),
                )
              : null,
          child: desktopCells(columns, cells),
        ),
      ),
    );
  }
}

/// Icon tile + title over meta — the first cell of most table rows.
class DesktopRowIdentity extends StatelessWidget {
  const DesktopRowIdentity({
    super.key,
    required this.icon,
    required this.title,
    required this.meta,
    this.tileColor,
    this.glyphColor,
    this.metaColor,
    this.size = 38,
    this.large = false,
  });

  final IconData icon;
  final String title;
  final String meta;
  final Color? tileColor;
  final Color? glyphColor;
  final Color? metaColor;
  final double size;

  /// Account rows use the larger title and tile.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Row(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: tileColor ?? c.surfaceMuted,
            borderRadius: BorderRadius.circular(large ? 13 : 12),
          ),
          child: Icon(icon,
              size: large ? 21 : 20, color: glyphColor ?? c.textTertiary),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (large
                          ? ScandyDesktopText.cellTitleLarge
                          : ScandyDesktopText.cellTitle)
                      .copyWith(color: c.textPrimary)),
              const SizedBox(height: 2),
              Text(meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (metaColor == null
                          ? ScandyDesktopText.cellMeta
                          : ScandyDesktopText.cellMetaStrong)
                      .copyWith(color: metaColor ?? c.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

/// A right-aligned figure cell that shrinks rather than wraps.
class DesktopAmountCell extends StatelessWidget {
  const DesktopAmountCell({
    super.key,
    required this.text,
    required this.color,
    this.large = false,
  });

  final String text;
  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text(
        text,
        style: (large
                ? ScandyDesktopText.cellAmountLarge
                : ScandyDesktopText.cellAmount)
            .copyWith(color: color),
      ),
    );
  }
}

/// The empty state inside a desktop panel — the mobile one, with the padding
/// the wider card wants.
class DesktopEmpty extends StatelessWidget {
  const DesktopEmpty({
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
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 44),
      child: Column(
        children: [
          Icon(icon, size: 30, color: c.iconMuted),
          const SizedBox(height: 12),
          Text(title,
              style:
                  ScandyDesktopText.cardTitle.copyWith(color: c.textPrimary)),
          const SizedBox(height: 5),
          Text(message,
              textAlign: TextAlign.center,
              style: ScandyDesktopText.actionSubtitle
                  .copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}
