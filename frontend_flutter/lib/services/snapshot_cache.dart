import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account.dart';
import '../models/subscription.dart';
import '../models/transaction.dart';

/// Everything a screen needs, as it stood after one successful load.
class Snapshot {
  const Snapshot({
    required this.transactions,
    required this.accounts,
    required this.subscriptions,
    required this.categories,
  });

  final List<Transaction> transactions;
  final List<Account> accounts;
  final List<Subscription> subscriptions;
  final Map<String, List<String>> categories;
}

/// The last successful load, kept on disk so the next launch has a ledger to
/// show before the network has answered.
///
/// It is a cache, not a store: the server is still the truth, and every
/// launch revalidates against it. All this buys is the seconds between the
/// first frame and the first response, which is exactly the stretch that used
/// to be a spinner. Keyed by user so a snapshot is only ever handed back to
/// the person it was taken for, and wiped on sign-out so it does not outlive
/// them on a shared phone either.
///
/// Every failure is swallowed: a cache that cannot be read is the same as no
/// cache, and one that cannot be written is only slower.
class SnapshotCache {
  static const _key = 'scandy.snapshot';

  /// Bump when the shape changes. An old blob is discarded, not migrated --
  /// the next load rewrites it.
  static const _version = 1;

  Future<Snapshot?> read(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;

      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['version'] != _version || json['user'] != userId) return null;

      final categories = (json['categories'] as Map<String, dynamic>).map(
        (kind, names) => MapEntry(kind, List<String>.from(names as List)),
      );
      return Snapshot(
        transactions: _list(json['transactions'], Transaction.fromJson),
        accounts: _list(json['accounts'], Account.fromJson),
        subscriptions: _list(json['subscriptions'], Subscription.fromRow),
        categories: categories,
      );
    } catch (e) {
      debugPrint('Snapshot cache unreadable, ignoring it: $e');
      return null;
    }
  }

  Future<void> write(String userId, Snapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'version': _version,
          'user': userId,
          'transactions': [for (final t in snapshot.transactions) t.toJson()],
          'accounts': [for (final a in snapshot.accounts) a.toJson()],
          'subscriptions': [for (final s in snapshot.subscriptions) s.toJson()],
          'categories': snapshot.categories,
        }),
      );
    } catch (e) {
      debugPrint('Snapshot cache not written: $e');
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('Snapshot cache not cleared: $e');
    }
  }

  static List<T> _list<T>(
    Object? raw,
    T Function(Map<String, dynamic>) parse,
  ) =>
      [for (final item in raw as List) parse(item as Map<String, dynamic>)]
          .toList(growable: false);
}
