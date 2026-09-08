import 'dart:async';
import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account.dart';
import '../models/subscription.dart';
import '../models/transaction.dart';

/// Thrown for any non-2xx response or transport failure, carrying a message
/// that is safe to show in a snackbar.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// Talks to the Flask backend in `backend/app.py`.
///
/// The Vue app never needed a base URL: `vue.config.js` proxied `/api` in dev
/// and Capacitor served the SPA from the same origin in production. A Flutter
/// binary has no origin, so the host is explicit and user-editable — on the
/// Android emulator the host machine is `10.0.2.2`, and on a physical phone it
/// is the machine's LAN address.
class ApiClient {
  /// [baseUrl] is for tests and for callers that already know the address;
  /// everything else takes [defaultBaseUrl] and then whatever the user saved.
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? defaultBaseUrl;

  final http.Client _client;

  static const _baseUrlKey = 'scandy.baseUrl';

  /// Baked in at build time, for your own builds:
  ///
  ///     flutter build apk --release \
  ///         --dart-define=SCANDY_SERVER_URL=http://100.x.y.z:5001
  ///
  /// A personal server address is a network identifier, so it belongs in a build
  /// flag rather than committed to a public repository.
  static const _configuredBaseUrl = String.fromEnvironment('SCANDY_SERVER_URL');

  /// First-run address, overridden by whatever the user saves.
  ///
  /// Empty on a phone unless it was configured at build time, and deliberately
  /// so. There is no address that is right for an arbitrary device: the previous
  /// default was `10.0.2.2`, the Android *emulator's* alias for the host
  /// machine, which on a real phone produced "Can't reach Scandy at
  /// http://10.0.2.2:5001" — an error implying a server that was never there.
  /// Saying nothing is set is both true and actionable.
  ///
  /// On the web the page's own host is the better guess than `localhost`: the
  /// app is served from the same machine as the backend, so opening it at
  /// `100.x.y.z:8088` should talk to `100.x.y.z:5001`, not to whatever happens
  /// to be on the viewer's own loopback.
  ///
  /// `defaultTargetPlatform` rather than `dart:io`'s `Platform`, so this file
  /// still compiles for web.
  static String get defaultBaseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    if (kIsWeb) {
      final host = Uri.base.host;
      return 'http://${host.isEmpty ? 'localhost' : host}:5001';
    }
    // A desktop build is on the same machine as the backend; a phone is not.
    return defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS
        ? ''
        : 'http://localhost:5001';
  }

  /// Whether a server address is known at all.
  bool get hasBaseUrl => _baseUrl.isNotEmpty;

  String _baseUrl;
  String get baseUrl => _baseUrl;

  Future<void> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey) ?? defaultBaseUrl;
  }

  Future<void> setBaseUrl(String value) async {
    _baseUrl = value.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, _baseUrl);
  }

  Uri _uri(String path) {
    if (_baseUrl.isEmpty) throw ApiException(_notConfigured);
    return Uri.parse('$_baseUrl$path');
  }

  /// Distinct from "unreachable": nothing is wrong with the network, the app
  /// simply has not been told where the server is.
  static const _notConfigured =
      'No server address set yet. Open Server settings and enter the address of '
      'the machine running Scandy — its Tailscale address reaches it from '
      'anywhere, for example http://100.x.y.z:5001.';

  /// Shown for both a refused connection and a timeout — from the user's side
  /// they are the same problem, and the address is the actionable part.
  String get _unreachable =>
      "Can't reach Scandy at $_baseUrl. Check the server address in Settings.";

  Future<dynamic> _get(String path) async {
    try {
      final res = await _client
          .get(_uri(path))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw ApiException('$path failed (${res.statusCode})',
            statusCode: res.statusCode);
      }
      return jsonDecode(utf8.decode(res.bodyBytes));
    } on http.ClientException {
      throw ApiException(_unreachable);
    } on TimeoutException {
      throw ApiException(_unreachable);
    }
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final req = http.Request(method, _uri(path))
        ..headers['Content-Type'] = 'application/json';
      if (body != null) req.body = jsonEncode(body);
      final streamed =
          await _client.send(req).timeout(const Duration(seconds: 20));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw ApiException(
          _errorMessage(res) ?? '$method $path failed (${res.statusCode})',
          statusCode: res.statusCode,
        );
      }
      return res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    } on http.ClientException {
      throw ApiException(_unreachable);
    } on TimeoutException {
      throw ApiException(_unreachable);
    }
  }

  String? _errorMessage(http.Response res) {
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {
      // Non-JSON error body; fall back to the caller's generic message.
    }
    return null;
  }

  Future<List<Transaction>> fetchTransactions() async {
    final data = await _get('/api/transactions');
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Transaction.fromJson)
        .toList(growable: false);
  }

  Future<List<Account>> fetchAccounts() async {
    final data = await _get('/api/accounts');
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Account.fromJson)
        .toList(growable: false);
  }

  Future<List<Subscription>> fetchSubscriptions() async {
    final data = await _get('/api/subscriptions');
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Subscription.fromJson)
        .toList(growable: false);
  }

  /// `{"expense": [...], "income": [...], "transfer": [...]}`.
  Future<Map<String, List<String>>> fetchCategories() async {
    final data = await _get('/api/categories');
    if (data is! Map) return const {};
    return data.map(
      (key, value) => MapEntry(
        key as String,
        (value as List?)?.whereType<String>().toList(growable: false) ??
            const <String>[],
      ),
    );
  }

  Future<void> deleteTransaction(String id) =>
      _send('DELETE', '/api/transactions/$id');

  Future<void> updateTransaction(String id, Map<String, dynamic> body) =>
      _send('PUT', '/api/transactions/$id', body: body);

  Future<void> createManualTransaction(Map<String, dynamic> body) =>
      _send('POST', '/api/transactions/manual', body: body);

  Future<void> createTransfer(Map<String, dynamic> body) =>
      _send('POST', '/api/transactions/transfer', body: body);

  // ---- Accounts ----

  Future<void> createAccount(Map<String, dynamic> body) =>
      _send('POST', '/api/accounts', body: body);

  Future<void> updateAccount(String id, Map<String, dynamic> body) =>
      _send('PUT', '/api/accounts/$id', body: body);

  Future<void> deleteAccount(String id) =>
      _send('DELETE', '/api/accounts/$id');

  // ---- Subscriptions ----

  Future<void> createSubscription(Map<String, dynamic> body) =>
      _send('POST', '/api/subscriptions', body: body);

  Future<void> updateSubscription(String id, Map<String, dynamic> body) =>
      _send('PUT', '/api/subscriptions/$id', body: body);

  Future<void> deleteSubscription(String id) =>
      _send('DELETE', '/api/subscriptions/$id');

  // ---- Categories ----
  //
  // All three share the /api/categories path and are distinguished by verb;
  // delete carries a JSON body, which is unusual but is what the backend
  // reads (`data.get('name')` in delete_category_route).

  Future<void> addCategory({required String type, required String name}) =>
      _send('POST', '/api/categories', body: {'type': type, 'name': name});

  Future<void> renameCategory({
    required String type,
    required String oldName,
    required String newName,
  }) =>
      _send('PUT', '/api/categories',
          body: {'type': type, 'old_name': oldName, 'new_name': newName});

  Future<void> deleteCategory({required String type, required String name}) =>
      _send('DELETE', '/api/categories',
          body: {'type': type, 'name': name});

  /// Uploads a receipt image for OCR. Returns the extracted fields — this
  /// endpoint only scans, it does not persist a transaction.
  ///
  /// Takes an [XFile] rather than a `dart:io` File so the same path works from
  /// a browser, where there is no filesystem to read from — the bytes are read
  /// through the abstraction and posted directly.
  Future<Map<String, dynamic>> scanReceipt(XFile image) async {
    final bytes = await image.readAsBytes();
    final filename = image.name.isEmpty ? 'receipt.jpg' : image.name;
    final req = http.MultipartRequest('POST', _uri('/api/upload'))
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType('image', _extensionOf(filename)),
      ));
    try {
      // Sent through _client, not req.send(): the latter spins up its own
      // one-shot client, which would bypass any client injected for tests.
      final streamed =
          await _client.send(req).timeout(const Duration(seconds: 90));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 429) {
        throw ApiException('The scanner is busy — try again in a moment.',
            statusCode: 429);
      }
      final decoded = res.body.isEmpty
          ? null
          : jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        final message = decoded is Map && decoded['error'] is String
            ? decoded['error'] as String
            : 'Scan failed (${res.statusCode})';
        throw ApiException(message, statusCode: res.statusCode);
      }
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on http.ClientException {
      throw ApiException(_unreachable);
    } on TimeoutException {
      throw ApiException(_unreachable);
    }
  }

  /// The backend only accepts png/jpg/jpeg/gif (`ALLOWED_EXTENSIONS`), so an
  /// unrecognised name falls back to jpeg rather than sending a subtype the
  /// server will reject.
  String _extensionOf(String filename) {
    final ext = filename.contains('.')
        ? filename.split('.').last.toLowerCase()
        : 'jpeg';
    return switch (ext) {
      'jpg' || 'jpeg' => 'jpeg',
      'png' => 'png',
      'gif' => 'gif',
      _ => 'jpeg',
    };
  }

  void dispose() => _client.close();
}
