import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/theme_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../common/widgets.dart';
import '../settings/settings_screen.dart';
import 'desktop_widgets.dart';

/// Settings, desktop composition: the theme control sits beside its label
/// rather than under it, and the two category lists run side by side — the
/// phone stacks them behind chevrons because it has no room for both.
class SettingsDesktop extends StatelessWidget {
  const SettingsDesktop({super.key});

  @override
  Widget build(BuildContext context) {
    return const DesktopPage(
      children: [
        DesktopHeader(
          title: 'Settings',
          subtitle: 'Appearance, categories and your account',
        ),
        SizedBox(height: desktopGap),
        _AppearancePanel(),
        SizedBox(height: desktopGap),
        _CategoriesPanel(),
        SizedBox(height: desktopGap),
        _AccountPanel(),
      ],
    );
  }
}

class _AppearancePanel extends StatelessWidget {
  const _AppearancePanel();

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final theme = context.watch<ThemeController>();

    return DesktopPanel(
      title: 'Appearance',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Theme',
                      style: ScandyDesktopText.cellTitle
                          .copyWith(color: c.textPrimary)),
                  const SizedBox(height: 3),
                  Text('Follows your system setting unless you pick one',
                      style: ScandyDesktopText.actionSubtitle
                          .copyWith(color: c.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 20),
            SizedBox(
              width: 330,
              child: ScandySegmented<ThemeMode>(
                value: theme.mode,
                onChanged: theme.set,
                options: const [
                  SegmentOption(
                      value: ThemeMode.light,
                      label: 'Light',
                      icon: Icons.light_mode),
                  SegmentOption(
                      value: ThemeMode.dark,
                      label: 'Dark',
                      icon: Icons.dark_mode),
                  SegmentOption(
                      value: ThemeMode.system,
                      label: 'System',
                      icon: Icons.contrast),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoriesPanel extends StatelessWidget {
  const _CategoriesPanel();

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final categories = context.watch<AppState>().categories;

    return DesktopPanel(
      title: 'Categories',
      subtitle: 'Renaming a category updates it everywhere. Deleting one '
          'leaves old transactions labelled — it just stops being selectable.',
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _CategoryColumn(
                type: 'expense',
                label: 'Expense categories',
                names: categories['expense'] ?? const [],
              ),
            ),
            Container(width: 1, color: c.dividerStrong),
            Expanded(
              child: _CategoryColumn(
                type: 'income',
                label: 'Income categories',
                names: categories['income'] ?? const [],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryColumn extends StatelessWidget {
  const _CategoryColumn({
    required this.type,
    required this.label,
    required this.names,
  });

  final String type;
  final String label;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    // The backend refuses to delete the last category of a type, so the
    // control is hidden rather than letting the request fail.
    final canDelete = names.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          decoration: BoxDecoration(
            color: c.page,
            border: Border(bottom: BorderSide(color: c.dividerStrong)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label.toUpperCase(),
                    style: ScandyDesktopText.tableHeader
                        .copyWith(color: c.textSecondary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: c.surfaceMuted,
                  borderRadius: BorderRadius.circular(ScandyRadius.pill),
                ),
                child: Text('${names.length}',
                    style: ScandyText.countPill
                        .copyWith(color: c.textSecondary)),
              ),
            ],
          ),
        ),
        for (final name in names)
          Container(
            padding: const EdgeInsets.fromLTRB(22, 5, 14, 5),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ScandyDesktopText.cellTitle
                          .copyWith(color: c.textPrimary)),
                ),
                RowActions(
                  onEdit: () =>
                      editCategory(context, type: type, existingName: name),
                  onDelete: canDelete
                      ? () => deleteCategory(context, type: type, name: name)
                      : null,
                ),
              ],
            ),
          ),
        // The design draws an inline "New expense category" field here; the
        // add sheet is the same one the phone opens, so a category is created
        // the same way on both.
        InkWell(
          onTap: () => editCategory(context, type: type),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.add, size: 20, color: c.accent),
                const SizedBox(width: 10),
                Text('Add category',
                    style:
                        ScandyDesktopText.cellTitle.copyWith(color: c.accent)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The desktop layout composes its own panels rather than reusing the phone
/// screen, so a section added there does not appear here -- which is how the
/// web build ended up with no way to sign out.
class _AccountPanel extends StatelessWidget {
  const _AccountPanel();

  @override
  Widget build(BuildContext context) {
    return const DesktopPanel(
      title: 'Account',
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 18, 22, 20),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(width: 520, child: AccountSection(bare: true)),
        ),
      ),
    );
  }
}
