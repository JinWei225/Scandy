/// One import for everything a screen needs to speak the reader's language.
library;

import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// `context.l.signIn` reads better than `L.of(context).signIn` at the call
/// sites, and there are a few hundred of them.
extension ScandyL10n on BuildContext {
  L get l => L.of(this);
}
