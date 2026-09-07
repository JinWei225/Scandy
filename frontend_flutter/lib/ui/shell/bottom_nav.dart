import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// Destinations in the redesigned nav. The centre slot is the ADD button, not
/// a destination, so it is absent here and injected by [ScandyBottomNav].
enum NavTab {
  home('Home', Icons.cottage),
  summary('Summary', Icons.bar_chart),
  accounts('Accounts', Icons.account_balance_wallet),
  recurring('Recurring', Icons.event_repeat);

  const NavTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Five equal columns with the ADD button in the middle, per the design:
/// 8px padding, 14px below (plus whatever the device's gesture inset needs),
/// 56px minimum touch height, 24px glyphs.
class ScandyBottomNav extends StatelessWidget {
  const ScandyBottomNav({
    super.key,
    required this.current,
    required this.onSelect,
    required this.onAdd,
  });

  /// Null when no destination in this bar is showing — Settings is a desktop
  /// destination with no slot here, so resizing away from it leaves the bar
  /// with nothing highlighted rather than lying about where you are.
  final NavTab? current;
  final ValueChanged<NavTab> onSelect;
  final VoidCallback onAdd;

  /// 8px top padding + a 56px row + the bottom inset. The design's 14px
  /// assumes a bezel; three-button navigation and gesture bars are taller, so
  /// whichever is larger wins.
  static double bottomInsetFor(BuildContext context) =>
      math.max(14.0, MediaQuery.viewPaddingOf(context).bottom);

  /// Total height the bar occupies. The shell draws it *over* the active
  /// screen, so every scrollable must reserve this much at the bottom or its
  /// last row hides underneath — which is exactly what happened with the
  /// on-screen navigation buttons enabled.
  static double heightFor(BuildContext context) =>
      8 + 56 + bottomInsetFor(context);

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final inset = bottomInsetFor(context);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.fromLTRB(8, 8, 8, inset),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _Item(tab: NavTab.home, current: current, onSelect: onSelect)),
          Expanded(child: _Item(tab: NavTab.summary, current: current, onSelect: onSelect)),
          Expanded(child: _AddButton(onPressed: onAdd)),
          Expanded(child: _Item(tab: NavTab.accounts, current: current, onSelect: onSelect)),
          Expanded(child: _Item(tab: NavTab.recurring, current: current, onSelect: onSelect)),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.tab, required this.current, required this.onSelect});

  final NavTab tab;
  final NavTab? current;
  final ValueChanged<NavTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final selected = tab == current;
    final color = selected ? c.accent : c.textSecondary;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () => onSelect(tab),
        borderRadius: BorderRadius.circular(ScandyRadius.tile),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tab.icon, size: 24, color: color),
              const SizedBox(height: 3),
              Text(
                tab.label,
                style: (selected ? ScandyText.navLabelActive : ScandyText.navLabel)
                    .copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 60×60 squircle that overlaps the nav's top edge. The design draws a 4px
/// ring of the nav's own colour around it; that ring is omitted here at the
/// user's request, so the accent fill meets the bar directly.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return SizedBox(
      height: 56,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Semantics(
            button: true,
            label: 'Add a transaction',
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ScandyRadius.sheet),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ScandyRadius.sheet),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPressed,
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 27, color: c.onAccent),
                        const SizedBox(height: 1),
                        Text(
                          'ADD',
                          style: ScandyText.fabLabel.copyWith(color: c.onAccent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
