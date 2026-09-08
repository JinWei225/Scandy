/// The no-ML-Kit build: web, and anything else without a `dart:io`.
///
/// Selected by the conditional import in local_scanner.dart. Scanning falls
/// through to the server, which is what the web UI has always done.
library;

import 'local_scanner.dart';

LocalScanner createLocalScanner() => const UnavailableLocalScanner();
