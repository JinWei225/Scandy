import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../state/app_state.dart';
import '../../state/locale_controller.dart';
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
    final l = context.l;
    return DesktopPage(
      children: [
        DesktopHeader(
          title: l.settings,
          subtitle: l.settingsSubtitleDesktop,
        ),
        const SizedBox(height: desktopGap),
        const _AppearancePanel(),
        const SizedBox(height: desktopGap),
        const _CategoriesPanel(),
        const SizedBox(height: desktopGap),
        const _AccountPanel(),
      ],
    );
  }
}

class _AppearancePanel extends StatelessWidget {
  const _AppearancePanel();

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final l = context.l;
    final theme = context.watch<ThemeController>();
    final locale = context.watch<LocaleController>();

    return DesktopPanel(
      title: l.appearance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingRow(
            title: l.theme,
            subtitle: l.themeFollowsSystem,
            control: ScandySegmented<ThemeMode>(
              value: theme.mode,
              onChanged: theme.set,
              options: [
                SegmentOption(
                    value: ThemeMode.light,
                    label: l.themeLight,
                    icon: Icons.light_mode),
                SegmentOption(
                    value: ThemeMode.dark,
                    label: l.themeDark,
                    icon: Icons.dark_mode),
                SegmentOption(
                    value: ThemeMode.system,
                    label: l.themeSystem,
                    icon: Icons.contrast),
              ],
            ),
          ),
          Container(height: 1, color: c.divider),
          _SettingRow(
            title: l.language,
            subtitle: l.languageFollowsSystem,
            // Each language names itself — see the note on the phone's copy of
            // this control.
            control: ScandySegmented<Locale?>(
              value: locale.locale,
              onChanged: locale.set,
              options: [
                const SegmentOption(value: Locale('en'), label: 'English'),
                const SegmentOption(value: Locale('zh'), label: '中文'),
                SegmentOption(value: null, label: l.languageSystem),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A label and its explanation on the left, the control itself on the right.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    required this.control,
  });

  final String title;
  final String subtitle;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: ScandyDesktopText.cellTitle
                        .copyWith(color: c.textPrimary)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: ScandyDesktopText.actionSubtitle
                        .copyWith(color: c.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(width: 330, child: control),
        ],
      ),
    );
  }
}

class _CategoriesPanel extends StatelessWidget {
  const _CategoriesPanel();

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final l = context.l;
    final categories = context.watch<AppState>().categories;

    return DesktopPanel(
      title: l.categories,
      subtitle: l.categoriesNoteDesktop,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _CategoryColumn(
                type: 'expense',
                label: l.expenseCategories,
                names: categories['expense'] ?? const [],
              ),
            ),
            Container(width: 1, color: c.dividerStrong),
            Expanded(
              child: _CategoryColumn(
                type: 'income',
                label: l.incomeCategories,
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
                Text(context.l.addCategory,
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
    return DesktopPanel(
      title: context.l.accountSection,
      child: const Padding(
        padding: EdgeInsets.fromLTRB(22, 18, 22, 20),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(width: 520, child: AccountSection(bare: true)),
        ),
      ),
    );
  }
}
