import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/local_scanner.dart';
import '../../services/share_intent_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../common/sheets.dart';
import '../accounts/accounts_screen.dart';
import '../desktop/accounts_desktop.dart';
import '../desktop/desktop_widgets.dart';
import '../desktop/home_desktop.dart';
import '../desktop/recurring_desktop.dart';
import '../desktop/settings_desktop.dart';
import '../desktop/side_nav.dart';
import '../desktop/summary_desktop.dart';
import '../home/home_screen.dart';
import '../recurring/recurring_screen.dart';
import '../scan/scan_source_sheet.dart';
import '../settings/settings_screen.dart';
import '../summary/summary_screen.dart';
import '../transactions/add_transaction_sheet.dart';
import 'add_sheet.dart';
import 'bottom_nav.dart';

/// Hosts the tabs and, depending on the window, either the bottom nav or the
/// sidebar.
///
/// The handoff draws both: phone frames with a five-slot bar whose centre is
/// the ADD button, and desktop frames with a 236px sidebar that carries
/// Settings as a real destination. [desktopBreakpoint] picks between them, and
/// the selected destination survives the switch.
///
/// On the phone the design stacks the add sheet deliberately: scrim above the
/// content, the add card above the scrim, and the nav above *both* — so the
/// bar never dims. A `showModalBottomSheet` would darken the nav too, hence
/// the explicit Stack.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.shareIntent});

  final ShareIntentService shareIntent;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  /// One field for both layouts. The sidebar's destinations are a superset of
  /// the bar's, so this is the wider of the two and the bar maps onto it.
  DesktopTab _tab = DesktopTab.home;
  bool _sheetOpen = false;
  StreamSubscription<XFile>? _shareSub;

  late final AnimationController _sheetAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    reverseDuration: const Duration(milliseconds: 140),
  );

  @override
  void initState() {
    super.initState();
    // A receipt shared from Photos/Gallery goes straight into the scanner,
    // which is what the Capacitor build did.
    //
    // Post-frame, because a share that cold-started the app is replayed as
    // soon as this subscription attaches — which is during initState, before
    // there is a Navigator to put the scanning dialog in front of.
    _shareSub = widget.shareIntent.images.listen((file) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scanFile(file));
    });
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    _sheetAnim.dispose();
    super.dispose();
  }

  void _openSheet() {
    setState(() => _sheetOpen = true);
    _sheetAnim.forward();
  }

  Future<void> _closeSheet() async {
    await _sheetAnim.reverse();
    if (mounted) setState(() => _sheetOpen = false);
  }

  Future<void> _onAddAction(AddAction action) async {
    await _closeSheet();
    if (!mounted) return;

    switch (action) {
      case AddAction.scanReceipt:
        await _pickAndScan();
      case AddAction.logByHand:
        await showAddTransactionSheet(context);
    }
  }

  Future<void> _pickAndScan() async {
    // Ask camera-or-gallery first: a receipt is often already a photo or a
    // screenshot, and opening the camera outright made those unreachable.
    final source = await showScanSourceSheet(context);
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final shot = await picker.pickImage(source: source, imageQuality: 85);
    if (shot == null) return;
    await _scanFile(shot);
  }

  /// Uploads to `/api/upload`, which only runs OCR — it does not persist
  /// anything — then opens the form pre-filled with whatever it read.
  ///
  /// There is deliberately no confirmation step in between: it showed the
  /// extracted fields without letting you correct them, so the only possible
  /// response to a bad read was to continue anyway and fix it on the form.
  /// The form is where every field is editable, so the scan goes straight
  /// there. A failed read still surfaces, inside the scanning dialog.
  Future<void> _scanFile(XFile file) async {
    if (!mounted) return;
    final api = context.read<AppState>().api;

    final job = _ScanJob(api: api, file: file);

    // An on-device scan finishes in about 150 ms. Showing a spinner for that is
    // worse than showing nothing: the photo picker has just displayed its own
    // "1 of 1 ready" progress, so a second one flashing up and vanishing reads
    // as two loading screens for a single action. Wait a moment first, and only
    // put a dialog up for a scan that is genuinely going to take a while —
    // which now means one that went to the server.
    final quick = await job.result
        .timeout(_quietScanWindow, onTimeout: () => const _ScanOutcome.pending());
    if (!mounted) return;

    _ScanOutcome outcome;
    if (quick.isPending || quick.error != null) {
      // Still running, or it failed fast and the message needs somewhere to go.
      final shown = await showDialog<_ScanOutcome>(
        context: context,
        barrierDismissible: false,
        barrierColor: scrimColor(),
        builder: (_) => _ScanningDialog(job: job),
      );
      if (shown == null) return;
      outcome = shown;
    } else {
      outcome = quick;
    }

    if (!mounted || outcome.fields == null) return;
    await showAddTransactionSheet(context, prefill: outcome.fields!);
  }

  /// The bar has no Settings slot, so nothing is highlighted when the window
  /// is narrowed while Settings is open.
  NavTab? get _navTab => switch (_tab) {
    DesktopTab.home => NavTab.home,
    DesktopTab.summary => NavTab.summary,
    DesktopTab.accounts => NavTab.accounts,
    DesktopTab.recurring => NavTab.recurring,
    DesktopTab.settings => null,
  };

  Widget _mobileScreen() => switch (_tab) {
    DesktopTab.home => const HomeScreen(),
    DesktopTab.summary => const SummaryScreen(),
    DesktopTab.accounts => const AccountsScreen(),
    DesktopTab.recurring => const RecurringScreen(),
    DesktopTab.settings => const SettingsScreen(),
  };

  Widget _desktopScreen() => switch (_tab) {
    DesktopTab.home => HomeDesktop(onScanReceipt: _pickAndScan),
    DesktopTab.summary => const SummaryDesktop(),
    DesktopTab.accounts => const AccountsDesktop(),
    DesktopTab.recurring => const RecurringDesktop(),
    DesktopTab.settings => const SettingsDesktop(),
  };

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;

    return LayoutBuilder(
      builder: (context, constraints) => Scaffold(
        backgroundColor: c.page,
        body: constraints.maxWidth >= desktopBreakpoint
            ? _desktopBody(context)
            : _mobileBody(context, c),
      ),
    );
  }

  /// Sidebar + content. There is no add sheet here: the desktop frame puts
  /// "Scan a receipt" and "Log it by hand" on Home as cards, and gives
  /// Accounts and Recurring their own labelled add buttons.
  Widget _desktopBody(BuildContext context) {
    final state = context.watch<AppState>();
    return Row(
      // Both children fill the window: a Row centres by default, which left a
      // short page (Recurring) floating in the middle of the viewport.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScandySideNav(
          current: _tab,
          onSelect: (tab) {
            if (_sheetOpen) _closeSheet();
            setState(() => _tab = tab);
          },
          summary: state.summaryFor(DateTime.now()),
        ),
        Expanded(child: _desktopScreen()),
      ],
    );
  }

  Widget _mobileBody(BuildContext context, ScandyColors c) {
    return Stack(
      children: [
        // z-0: the active tab.
        Positioned.fill(child: SafeArea(bottom: false, child: _mobileScreen())),

        // z-5: scrim. Tapping it dismisses, as the design implies.
        if (_sheetOpen)
          Positioned.fill(
            child: FadeTransition(
              opacity: _sheetAnim,
              child: GestureDetector(
                onTap: _closeSheet,
                child: ColoredBox(
                  color: const Color(0xFF24201C).withValues(alpha: 0.42),
                ),
              ),
            ),
          ),

        // z-6: the add card, 14px in from each side.
        if (_sheetOpen)
          Positioned(
            left: 14,
            right: 14,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                // 96px above the frame bottom in the design; the nav is
                // ~82px tall, so this clears it by the same margin.
                padding: const EdgeInsets.only(bottom: 96),
                child: FadeTransition(
                  opacity: _sheetAnim,
                  child: SlideTransition(
                    position:
                        Tween(
                          begin: const Offset(0, 0.06),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _sheetAnim,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                    child: AddSheet(onSelected: _onAddAction),
                  ),
                ),
              ),
            ),
          ),

        // z-7: the nav, deliberately above the scrim.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ScandyBottomNav(
            current: _navTab,
            onSelect: (tab) {
              if (_sheetOpen) _closeSheet();
              setState(() => _tab = _desktopTabFor(tab));
            },
            onAdd: () => _sheetOpen ? _closeSheet() : _openSheet(),
          ),
        ),
      ],
    );
  }

  static DesktopTab _desktopTabFor(NavTab tab) => switch (tab) {
    NavTab.home => DesktopTab.home,
    NavTab.summary => DesktopTab.summary,
    NavTab.accounts => DesktopTab.accounts,
    NavTab.recurring => DesktopTab.recurring,
  };
}

/// How long a scan may take before it is worth interrupting the user with a
/// dialog. On-device scans land well inside this; server scans do not.
const Duration _quietScanWindow = Duration(milliseconds: 450);

/// The result of one scan: fields to prefill, a message to show, or neither
/// yet. Modelled rather than thrown so the future can complete before anyone
/// awaits it without becoming an unhandled error.
class _ScanOutcome {
  const _ScanOutcome.fields(this.fields) : error = null, isPending = false;
  const _ScanOutcome.failed(this.error) : fields = null, isPending = false;
  const _ScanOutcome.pending() : fields = null, error = null, isPending = true;

  final Map<String, dynamic>? fields;
  final String? error;
  final bool isPending;
}

/// Reads the receipt once, on the phone when it can and on the server when it
/// must, and hands the same result to whoever asks.
///
/// On Android and iOS ML Kit plus the local rules answer most scans in well
/// under a second with no network at all. The server is asked only when the
/// device cannot scan (the web build), or when the rules left a field empty —
/// it runs the same rules plus a small extraction model for the remainder.
///
/// When the server is unreachable and the device read *something*, that partial
/// answer still opens the form. Every field there is editable, so a prefilled
/// amount with a blank date is far more useful than a failed scan.
class _ScanJob {
  _ScanJob({required ApiClient api, required XFile file}) {
    result = _run(api, file);
  }

  late final Future<_ScanOutcome> result;

  static Future<_ScanOutcome> _run(ApiClient api, XFile file) async {
    final scanner = createLocalScanner();
    try {
      final local = await _scanLocally(scanner, file);
      if (local != null && local.fields.isComplete) {
        return _ScanOutcome.fields(prefillFrom(local.fields));
      }

      try {
        final data = await api.scanReceipt(file);
        // A receipt it cannot read comes back 200 with an `error` key rather
        // than a failed status, so it has to be checked in the success path.
        final error = data['error'];
        if (error is String) return _ScanOutcome.failed(error);
        return _ScanOutcome.fields(data);
      } on ApiException catch (e) {
        // Offline, or no server address set. A partial local read is still
        // worth opening the form with.
        if (local != null && local.fields.missing.length < 3) {
          return _ScanOutcome.fields(prefillFrom(local.fields));
        }
        return _ScanOutcome.failed(e.message);
      }
    } catch (e) {
      return _ScanOutcome.failed('$e');
    } finally {
      await scanner.dispose();
    }
  }

  /// Never lets an on-device failure end the scan — the server is still there.
  static Future<LocalScanResult?> _scanLocally(
      LocalScanner scanner, XFile file) async {
    if (!scanner.isAvailable) {
      debugPrint('[scan] on-device scanning unavailable on this platform');
      return null;
    }
    try {
      final watch = Stopwatch()..start();
      final result = await scanner.scan(file);
      watch.stop();
      // Logged in every build, not just debug: when a scan goes to the server
      // the useful question is always "what did the device read first", and
      // without this the answer is invisible.
      debugPrint('[scan] on-device ${watch.elapsedMilliseconds}ms -> '
          '${result?.fields} (${result?.text.split('\n').length ?? 0} rows)');
      return result;
    } catch (e, st) {
      debugPrint('[scan] on-device failed, falling back to the server: $e\n$st');
      return null;
    }
  }
}

/// Shown only for a scan slow enough to be worth a dialog — see
/// [_quietScanWindow]. It waits on a job that is already running rather than
/// starting one, so nothing is scanned twice.
class _ScanningDialog extends StatefulWidget {
  const _ScanningDialog({required this.job});

  final _ScanJob job;

  @override
  State<_ScanningDialog> createState() => _ScanningDialogState();
}

class _ScanningDialogState extends State<_ScanningDialog> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _await();
  }

  Future<void> _await() async {
    final outcome = await widget.job.result;
    if (!mounted) return;
    if (outcome.error != null) {
      setState(() => _error = outcome.error);
      return;
    }
    Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.scandy;
    return Center(
      // Without a Material above it, every line of text in a dialog route
      // inherits Flutter's debug style — the yellow double underline that was
      // showing under "This can take a few seconds."
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
            children: [
              if (_error == null) ...[
                CircularProgressIndicator(color: c.accent, strokeWidth: 2.5),
                const SizedBox(height: 18),
                Text(
                  'Reading your receipt…',
                  style: ScandyText.sheetItemTitle.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This can take a few seconds.',
                  textAlign: TextAlign.center,
                  style: ScandyText.sheetItemSubtitle.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              ] else ...[
                Icon(Icons.error_outline, color: c.negative, size: 28),
                const SizedBox(height: 14),
                Text(
                  "Couldn't read that one",
                  style: ScandyText.sheetItemTitle.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: ScandyText.sheetItemSubtitle.copyWith(
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    // Dismissing with empty fields opens the form with nothing
                    // pre-filled, so a failed scan still ends somewhere useful.
                    // It has to be an outcome, not a bare map: the route is
                    // typed, and popping anything else throws instead of
                    // closing the dialog.
                    onPressed: () => Navigator.of(context)
                        .pop(const _ScanOutcome.fields(<String, dynamic>{})),
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: c.onAccent,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ScandyRadius.tile),
                      ),
                    ),
                    child: Text(
                      'Enter it by hand',
                      style: ScandyText.sheetItemTitle,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: c.textSecondary,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: Text('Cancel', style: ScandyText.sheetItemTitle),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
