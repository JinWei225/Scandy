import 'package:flutter/material.dart';

/// Maps a category name to the tile glyph shown beside a transaction.
///
/// The design only illustrates five categories (Groceries → shopping_basket,
/// Transport → local_taxi, Salary → payments, Subscriptions → event_repeat,
/// Food & drink → local_cafe). The rest are extended in the same spirit to
/// cover the real category list in `backend/categories.json`; matching is
/// case-insensitive so a renamed category keeps its icon.
///
/// The Chinese names are the ones handle_new_user() seeds a Chinese account
/// with. Without them every row on that account would draw the fallback
/// receipt glyph, which is the difference between a translated app and one
/// that merely has translated words in it. A name nobody here recognises --
/// which is most of them, once people start renaming -- still falls back.
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

    // — the Chinese starter list, in the same order as the English one —
    case '餐饮':
      return Icons.local_cafe;
    case '购物':
      return Icons.shopping_bag;
    case '交通':
      return Icons.local_taxi;
    case '水电杂费':
      return Icons.receipt_long;
    case '娱乐':
      return Icons.movie;
    case '医疗':
      return Icons.favorite;
    case '日用采买':
      return Icons.shopping_basket;
    case '分期付款':
      return Icons.calendar_month;
    case '工资':
      return Icons.payments;
    case '投资':
      return Icons.trending_up;
    case '礼金':
      return Icons.card_giftcard;
    case '退款':
      return Icons.undo;
    case '订阅':
      return Icons.event_repeat;
    case '转账':
      return Icons.swap_horiz;

    default:
      return Icons.receipt_long;
  }
}
