import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../state/app_state.dart';
import '../../state/theme_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../common/sheets.dart';
import '../common/widgets.dart';
import '../shell/bottom_nav.dart';

/// "Settings" — appearance, categories, and where the backend lives.
///
/// The design covers Appearance and Categories. The server card is an addition:
/// a Flutter binary has no origin to infer the API from, unlike the Vue build
/// which was served alongside it.
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
        const ScreenHeader(title: 'Settings'),
        const SizedBox(height: 16),
        const _AppearanceSection(),
        const SizedBox(height: 16),
        const _CategoriesSection(),
        const SizedBox(height: 16),
        const ServerSection(),
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
          tooltip: 'Back',
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
    final theme = context.watch<ThemeController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GroupLabel('Appearance'),
        const SizedBox(height: 9),
        ScandyCard(
          radius: ScandyRadius.list,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Theme',
                  style: ScandyText.rowTitleLarge
                      .copyWith(color: c.textPrimary)),
              const SizedBox(height: 12),
              ScandySegmented<ThemeMode>(
                value: theme.mode,
                onChanged: theme.set,
                // The design lists Light, Dark, System in that order — not the
                // order of Flutter's own enum.
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
    final state = context.watch<AppState>();

    // 'transfer' is a single fixed category the backend manages itself, so it
    // is not offered for editing.
    const groups = [('expense', 'Expense categories'), ('income', 'Income categories')];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GroupLabel('Categories'),
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
          'Renaming a category updates it everywhere. Deleting one leaves old '
          'transactions labelled.',
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
                        Text('Add category',
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
            tooltip: 'Rename',
          ),
          if (canDelete)
            IconButton(
              onPressed: () => deleteCategory(context, type: type, name: name),
              icon: Icon(Icons.delete, size: 18, color: c.iconMuted),
              tooltip: 'Delete',
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

  // Outside the builder: a StatefulBuilder re-runs it on every setState, so a
  // message declared inside would be cleared by the very rebuild that was
  // meant to show it — which silently swallowed every backend rejection
  // ("already exists", "too long", "'Transfer' is reserved").
  String? error;

  await showScandySheet<void>(
    context: context,
    title: existingName == null ? 'Add category' : 'Rename category',
    child: StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        Future<void> submit() async {
          final value = controller.text.trim();
          if (value.isEmpty) {
            setSheetState(() => error = 'Give the category a name');
            return;
          }
          try {
            if (existingName == null) {
              await state.api.addCategory(type: type, name: value);
            } else {
              await state.api.renameCategory(
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
              label: 'Name',
              controller: controller,
              hint: 'Groceries',
              autofocus: true,
              errorText: error,
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: existingName == null ? 'Add' : 'Rename',
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
  final confirmed = await confirmDestructive(
    context: context,
    title: 'Delete "$name"?',
    message: 'Transactions already filed under it keep the label, but you '
        'will not be able to pick it again.',
  );
  if (!confirmed || !context.mounted) return;

  try {
    await state.api.deleteCategory(type: type, name: name);
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

/// Where the backend lives. Public so the desktop page can show the same
/// card — it is the one setting a Flutter build cannot infer for itself.
class ServerSection extends StatefulWidget {
  const ServerSection({super.key, this.bare = false});

  /// True on desktop, where the surrounding panel already supplies the card
  /// and the heading, so this renders the form alone.
  final bool bare;

  @override
  State<ServerSection> createState() => _ServerSectionState();
}

class _ServerSectionState extends State<ServerSection> {
  late final TextEditingController _controller =
      TextEditingController(text: context.read<AppState>().api.baseUrl);
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final state = context.read<AppState>();
    await state.api.setBaseUrl(_controller.text);
    await state.loadAll();
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ScandyField(
          label: 'Address',
          controller: _controller,
          hint: 'http://100.x.y.z:5001',
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 8),
        Text(
          'Use the Tailscale address of the machine running the backend '
          'to reach it from anywhere. On the same Wi-Fi its LAN address '
          'works too; on the Android emulator the host is 10.0.2.2. '
          'Scanning a receipt works on the phone without this — only your '
          'saved transactions need the server.',
          style: ScandyText.sheetItemSubtitle.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: 'Save and reload',
          busy: _saving,
          onPressed: _save,
        ),
      ],
    );

    if (widget.bare) return form;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GroupLabel('Server'),
        const SizedBox(height: 9),
        ScandyCard(
          radius: ScandyRadius.list,
          padding: const EdgeInsets.all(16),
          child: form,
        ),
      ],
    );
  }
}


/// Who is signed in, and the way out.
///
/// Sits at the bottom of Settings deliberately: signing out is rare and
/// destructive-feeling, and it should not share an edge with the controls
/// people actually come here for.
class AccountSection extends StatelessWidget {
  const AccountSection({super.key, this.bare = false});

  /// True on desktop, where the panel supplies the card and heading.
  final bool bare;

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await confirmDestructive(
      context: context,
      title: 'Sign out?',
      message: 'Your transactions stay in your account. You will need your '
          'password to get back in.',
      confirmLabel: 'Sign out',
    );
    if (!confirmed) return;

    // AuthGate is listening for signedOut and swaps the app for the sign-in
    // screen, so there is nothing to navigate to here.
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    final user = Supabase.instance.client.auth.currentUser;
    final name = (user?.userMetadata?['display_name'] as String?)?.trim();
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
                  if (name != null && name.isNotEmpty)
                    Text(name,
                        style: ScandyText.rowTitle
                            .copyWith(color: c.textPrimary)),
                  Text(
                    email,
                    style: ScandyText.sheetItemSubtitle
                        .copyWith(color: c.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
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
            child: Text('Sign out', style: ScandyText.sheetItemTitle),
          ),
        ),
      ],
    );

    if (bare) return body;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GroupLabel('Account'),
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
