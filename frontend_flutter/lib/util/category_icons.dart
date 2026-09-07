import 'package:flutter/material.dart';

/// Maps a category name to the tile glyph shown beside a transaction.
///
/// The design only illustrates five categories (Groceries → shopping_basket,
/// Transport → local_taxi, Salary → payments, Subscriptions → event_repeat,
/// Food & drink → local_cafe). The rest are extended in the same spirit to
/// cover the real category list in `backend/categories.json`; matching is
/// case-insensitive so a renamed category keeps its icon.
IconData iconForCategory(String category, {bool isTransfer = false}) {
  if (isTransfer) return Icons.swap_horiz;

  switch (category.toLowerCase().trim()) {
    // — from the design —
    case 'groceries':
      return Icons.shopping_basket;
    case 'transport':
      return Icons.local_taxi;
    case 'salary':
      return Icons.payments;
    case 'subscriptions':
      return Icons.event_repeat;
    case 'food & drink':
    case 'food and drink':
      return Icons.local_cafe;

    // — the remaining categories the backend ships —
    case 'shopping':
      return Icons.shopping_bag;
    case 'bills & utilities':
      return Icons.receipt_long;
    case 'entertainment':
      return Icons.movie;
    case 'health':
      return Icons.favorite;
    case 'installments':
      return Icons.calendar_month;
    case 'investments':
      return Icons.trending_up;
    case 'gifts':
      return Icons.card_giftcard;
    case 'refunds':
      return Icons.undo;
    case 'monthly living income':
      return Icons.account_balance;
    case 'transfer':
      return Icons.swap_horiz;
    default:
      return Icons.receipt_long;
  }
}
