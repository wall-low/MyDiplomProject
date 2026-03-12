import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Сохранённая карта (только последние 4 цифры + срок + имя)
/// Полный номер карты НЕ хранится
class SavedCard {
  final String last4;
  final String expiry; // MM/YY
  final String holder;
  final String network; // visa / mastercard / mir / other

  SavedCard({
    required this.last4,
    required this.expiry,
    required this.holder,
    required this.network,
  });

  Map<String, dynamic> toJson() => {
        'last4': last4,
        'expiry': expiry,
        'holder': holder,
        'network': network,
      };

  factory SavedCard.fromJson(Map<String, dynamic> json) => SavedCard(
        last4: json['last4'] as String? ?? '',
        expiry: json['expiry'] as String? ?? '',
        holder: json['holder'] as String? ?? '',
        network: json['network'] as String? ?? 'other',
      );

  String get displayName => '•••• •••• •••• $last4';

  /// Определить платёжную сеть по первой цифре номера
  static String detectNetwork(String cardNumber) {
    final digits = cardNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'other';
    if (digits.startsWith('4')) return 'visa';
    if (digits.startsWith('5') || digits.startsWith('2')) return 'mastercard';
    if (digits.startsWith('2200') ||
        digits.startsWith('2201') ||
        digits.startsWith('2202') ||
        digits.startsWith('2203') ||
        digits.startsWith('2204')) {
      return 'mir';
    }
    if (digits.startsWith('22')) { return 'mir'; }
    return 'other';
  }
}

/// Локальное хранилище сохранённой карты (SharedPreferences)
///
/// Хранит только маскированные данные:
/// - последние 4 цифры
/// - срок действия
/// - имя держателя
/// Полный номер и CVV НИКОГДА не сохраняются
class CardStorageService {
  static const _key = 'saved_payment_card';

  Future<SavedCard?> getSavedCard() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return null;
    try {
      return SavedCard.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null; // ignore: avoid_catches_without_on_clauses
    }
  }

  Future<void> saveCard(SavedCard card) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(card.toJson()));
  }

  Future<void> removeCard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
