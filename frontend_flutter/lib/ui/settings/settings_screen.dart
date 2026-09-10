import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/l10n.dart';
import '../../state/app_state.dart';
import '../../state/locale_controller.dart';
import '../../state/theme_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../common/sheets.dart';
import '../common/widgets.dart';
import '../shell/bottom_nav.dart';

/// "Settings" — appearance, categories, and the account.
///
/// The design covers Appearance and Categories. The Account card is an
/// addition: with more than one person using Scandy there has to be somewhere
/// that says who you are and lets you leave.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.embedded = true});

  /// True when shown as a tab (nav visible); false when pushed as a route.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final bottom =
        embedded ? ScandyBottomNav.heightFor(context) + 16 : 24.0;

    return ListView(
      padding: EdgeInsets.fromLTRB(18, 14, 18, bottom),
      children: [
        // Settings has no slot in the design's five-item nav, so it is pushed
        // from the Home header and needs its own way back.
        if (!embedded) const _BackRow(),
        ScreenHeader(title: context.l.settings),
        const SizedBox(height: 16),
        const _AppearanceSection(),
        const SizedBox(height: 16),
        const _CategoriesSection(),
        const SizedBox(height: 16),
        const AccountSection(),
      ],
    );
  }
}

class _BackRow extends StatelessWidget {
  const _BackRow();

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back, size: 22, color: c.textPrimary),
          tooltip: context.l.actionBack,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final l = context.l;
    final theme = context.watch<ThemeController>();
    final locale = context.watch<LocaleController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupLabel(l.appearance),
        const SizedBox(height: 9),
        ScandyCard(
          radius: ScandyRadius.list,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.theme,
                  style: ScandyText.rowTitleLarge
                      .copyWith(color: c.textPrimary)),
              const SizedBox(height: 12),
              ScandySegmented<ThemeMode>(
                value: theme.mode,
                onChanged: theme.set,
                // The design lists Light, Dark, System in that order — not the
                // order of Flutter's own enum.
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
              const SizedBox(height: 18),
              Text(l.language,
                  style: ScandyText.rowTitleLarge
                      .copyWith(color: c.textPrimary)),
              const SizedBox(height: 3),
              Text(l.languageFollowsSystem,
                  style: ScandyText.sheetItemSubtitle
                      .copyWith(color: c.textSecondary)),
              const SizedBox(height: 12),
              // Each language names itself. Somebody who cannot read the
              // current one still has to be able to find their own, which a
              // translated list of language names does not allow.
              ScandySegmented<Locale?>(
                value: locale.locale,
                onChanged: locale.set,
                options: [
                  const SegmentOption(value: Locale('en'), label: 'English'),
                  const SegmentOption(value: Locale('zh'), label: '中文'),
                  SegmentOption(value: null, label: l.languageSystem),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoriesSection extends StatefulWidget {
  const _CategoriesSection();

  @override
  State<_CategoriesSection> createState() => _CategoriesSectionState();
}

class _CategoriesSectionState extends State<_CategoriesSection> {
  /// Which group is expanded, or null for none — the design shows both
  /// collapsed with a chevron.
  String? _expanded;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final l = context.l;
    final state = context.watch<AppState>();

    // 'transfer' is a single fixed category the backend manages itself, so it
    // is not offered for editing. The keys are stored values; the labels are
    // what a reader sees.
    final groups = [
      ('expense', l.expenseCategories),
      ('income', l.incomeCategories),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupLabel(l.categories),
        const SizedBox(height: 9),
        ScandyCard(
          radius: ScandyRadius.list,
          clip: true,
          child: Column(
            children: [
              for (var i = 0; i < groups.length; i++)
                _CategoryGroup(
                  type: groups[i].$1,
                  label: groups[i].$2,
                  names: state.categories[groups[i].$1] ?? const [],
                  expanded: _expanded == groups[i].$1,
                  showDivider: i != groups.length - 1 || _expanded != null,
                  onToggle: () => setState(() => _expanded =
                      _expanded == groups[i].$1 ? null : groups[i].$1),
                ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Text(
          l.categoriesNote,
          style: ScandyText.sheetItemSubtitle.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({
    required this.type,
    required this.label,
    required this.names,
    required this.expanded,
    required this.showDivider,
    required this.onToggle,
  });

  final String type;
  final String label;
  final List<String> names;
  final bool expanded;
  final bool showDivider;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: showDivider || expanded
                ? BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.divider)))
                : null,
            child: Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: ScandyText.rowTitleLarge
                          .copyWith(color: c.textPrimary)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.surfaceMuted,
                    borderRadius: BorderRadius.circular(ScandyRadius.pill),
                  ),
                  child: Text('${names.length}',
                      style: ScandyText.countPill
                          .copyWith(color: c.textSecondary)),
                ),
                const SizedBox(width: 12),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(Icons.expand_more, size: 20, color: c.iconMuted),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Container(
            color: c.surfaceMuted,
            child: Column(
              children: [
                for (final name in names)
                  _CategoryRow(type: type, name: name, canDelete: names.length > 1),
                InkWell(
                  onTap: () => editCategory(context, type: type),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 20, color: c.accent),
                        const SizedBox(width: 10),
                        Text(context.l.addCategory,
                            style: ScandyText.rowTitle
                                .copyWith(color: c.accent)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.type,
    required this.name,
    required this.canDelete,
  });

  final String type;
  final String name;

  /// The backend refuses to delete the last category of a type, so the control
  /// is hidden rather than letting the request fail.
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ScandyText.rowTitle.copyWith(color: c.textPrimary)),
          ),
          IconButton(
            onPressed: () =>
                editCategory(context, type: type, existingName: name),
            icon: Icon(Icons.edit, size: 18, color: c.iconMuted),
            tooltip: context.l.actionRename,
          ),
          if (canDelete)
            IconButton(
              onPressed: () => deleteCategory(context, type: type, name: name),
              icon: Icon(Icons.delete, size: 18, color: c.iconMuted),
              tooltip: context.l.actionDelete,
            ),
        ],
      ),
    );
  }
}

/// Shared with the desktop Settings page, which lists the same categories in
/// two columns and reaches the same add/rename sheet.
Future<void> editCategory(
  BuildContext context, {
  required String type,
  String? existingName,
}) async {
  final controller = TextEditingController(text: existingName ?? '');
  final state = context.read<AppState>();
  final l = context.l;

  // Outside the builder: a StatefulBuilder re-runs it on every setState, so a
  // message declared inside would be cleared by the very rebuild that was
  // meant to show it — which silently swallowed every backend rejection
  // ("already exists", "too long", "'Transfer' is reserved").
  String? error;

  await showScandySheet<void>(
    context: context,
    title: existingName == null ? l.addCategory : l.renameCategory,
    child: StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        Future<void> submit() async {
          final value = controller.text.trim();
          if (value.isEmpty) {
            setSheetState(() => error = l.giveTheCategoryAName);
            return;
          }
          try {
            if (existingName == null) {
              await state.repo.addCategory(type: type, name: value);
            } else {
              await state.repo.renameCategory(
                  type: type, oldName: existingName, newName: value);
            }
            await state.refresh();
            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          } catch (e) {
            setSheetState(() => error = '$e');
          }
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScandyField(
              label: l.fieldName,
              controller: controller,
              hint: l.hintCategoryName,
              autofocus: true,
              errorText: error,
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: existingName == null ? l.actionAdd : l.actionRename,
              onPressed: submit,
            ),
          ],
        );
      },
    ),
  );
  controller.dispose();
}

/// Shared with the desktop Settings page.
Future<void> deleteCategory(
  BuildContext context, {
  required String type,
  required String name,
}) async {
  final state = context.read<AppState>();
  final l = context.l;
  final confirmed = await confirmDestructive(
    context: context,
    title: l.deleteCategoryQ(name),
    message: l.deleteCategoryBody,
  );
  if (!confirmed || !context.mounted) return;

  try {
    await state.repo.deleteCategory(type: type, name: name);
    await state.refresh();
  } catch (e) {
    if (!context.mounted) return;
    final c = context.scandy;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$e',
            style: ScandyText.rowTitle.copyWith(color: c.onAccent)),
        backgroundColor: c.negative,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ScandyRadius.tile),
        ),
      ));
  }
}

/// Who is signed in, and the way out.
///
/// Sits at the bottom of Settings deliberately: signing out is rare and
/// destructive-feeling, and it should not share an edge with the controls
/// people actually come here for.
class AccountSection extends StatefulWidget {
  const AccountSection({super.key, this.bare = false});

  /// True on desktop, where the panel supplies the card and heading.
  final bool bare;

  @override
  State<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<AccountSection> {
  /// Written on both the auth user and the profile row.
  ///
  /// They are two records and both are read: the greeting comes from the
  /// session's metadata, which is what is available before any query returns,
  /// while profiles.display_name is what anything server-side would join on.
  /// Updating one and not the other leaves the app disagreeing with itself.
  Future<void> _rename(BuildContext context, String current) async {
    final controller = TextEditingController(text: current);
    final l = context.l;
    // Declared outside the builder, like editCategory's: a StatefulBuilder
    // re-runs the builder on every setState, so a message declared inside is
    // cleared by the rebuild meant to show it.
    String? error;

    await showScandySheet<void>(
      context: context,
      title: l.yourName,
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> submit() async {
            final value = controller.text.trim();
            if (value.isEmpty) {
              setSheetState(() => error = l.giveYourselfAName);
              return;
            }
            final client = Supabase.instance.client;
            try {
              await client.auth
                  .updateUser(UserAttributes(data: {'display_name': value}));
              await client
                  .from('profiles')
                  .update({'display_name': value})
                  .eq('id', client.auth.currentUser!.id);
              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              if (mounted) setState(() {});
            } catch (_) {
              setSheetState(() => error = l.couldNotSaveThatName);
            }
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScandyField(
                label: l.fieldName,
                controller: controller,
                hint: l.hintYourName,
                autofocus: true,
                errorText: error,
              ),
              const SizedBox(height: 20),
              PrimaryButton(label: l.actionSave, onPressed: submit),
            ],
          );
        },
      ),
    );
    controller.dispose();
  }

  Future<void> _signOut(BuildContext context) async {
    final l = context.l;
    final confirmed = await confirmDestructive(
      context: context,
      title: l.signOutQ,
      message: l.signOutBody,
      confirmLabel: l.signOut,
    );
    if (!confirmed) return;

    // AuthGate is listening for signedOut and swaps the app for the sign-in
    // screen, so there is nothing to navigate to here.
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final l = context.l;
    final user = Supabase.instance.client.auth.currentUser;
    final name = (user?.userMetadata?['display_name'] as String?)?.trim() ?? '';
    final email = user?.email ?? '';

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surfaceMuted,
                borderRadius: BorderRadius.circular(ScandyRadius.tile),
              ),
              child: Icon(Icons.person_outline, size: 20, color: c.textTertiary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? l.addYourName : name,
                    style: ScandyText.rowTitle.copyWith(
                        color: name.isEmpty ? c.textSecondary : c.textPrimary),
                  ),
                  Text(
                    email,
                    style: ScandyText.sheetItemSubtitle
                        .copyWith(color: c.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _rename(context, name),
              icon: Icon(Icons.edit_outlined, size: 18, color: c.iconMuted),
              tooltip: l.changeYourName,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _signOut(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.negative,
              side: BorderSide(color: c.border),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ScandyRadius.tile),
              ),
            ),
            child: Text(l.signOut, style: ScandyText.sheetItemTitle),
          ),
        ),
      ],
    );

    if (widget.bare) return body;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupLabel(l.accountSection),
        const SizedBox(height: 9),
        ScandyCard(
          radius: ScandyRadius.list,
          padding: const EdgeInsets.all(16),
          child: body,
        ),
      ],
    );
  }
}
