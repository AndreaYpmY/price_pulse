import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:price_pulse/UI/utility/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef ProductCounts = Map<String, int>;
typedef StoreCounts = Map<String, int>;

class PreferencesService {
  static const String _keyDeviceId = 'device_id';
  static const String _keyProductCounts = 'habitual_product_counts';
  static const String _keyStoreCounts = 'habitual_store_counts';
  static const String _keyDarkMode = 'is_dark_mode';
  static const String _keyLanguage = 'language_code';

  // Id anonimo persistente del dispositivo
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_keyDeviceId);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final generated =
        'dev_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';
    await prefs.setString(_keyDeviceId, generated);
    return generated;
  }

  // Pulisce testo: da "Pasta di Barilla 500g" diventa {"pasta", "barilla", "500g"}
  Set<String> _extractKeywords(String productName) {
    final cleaned = productName
        .toLowerCase()
        .replaceAll(RegExp(Constants.keywordCleanupPattern), ' ')
        .trim();

    return cleaned
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 1 && !Constants.stopWords.contains(word))
        .toSet();
  }

  // Aggiorno contatore prodotti abituali
  Future<void> recordProductInteraction(String productName) async {
    final cleanName = productName.trim().toLowerCase();
    if (cleanName.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final ProductCounts counts = await getProductCounts();

    String keyToUpdate = cleanName;
    final newKeywords = _extractKeywords(cleanName);

    for (final existingKey in counts.keys) {
      final existingKeywords = _extractKeywords(existingKey);
      final common = newKeywords.intersection(existingKeywords);
      if (common.length >= 2 || existingKey == cleanName) {
        keyToUpdate = existingKey;
        break;
      }
    }

    counts[keyToUpdate] = (counts[keyToUpdate] ?? 0) + 1;
    await prefs.setString(_keyProductCounts, jsonEncode(counts));
  }

  Future<ProductCounts> getProductCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawJson = prefs.getString(_keyProductCounts);
    if (rawJson == null || rawJson.isEmpty) return {};

    try {
      final Map<String, dynamic> decoded = jsonDecode(rawJson);
      return decoded.map((key, value) => MapEntry(key, (value as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  // Aggiorno contatore supermercati frequenti
  Future<void> recordStoreInteraction(String storeId) async {
    final cleanId = storeId.trim();
    if (cleanId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final StoreCounts counts = await getStoreCounts();

    counts[cleanId] = (counts[cleanId] ?? 0) + 1;
    await prefs.setString(_keyStoreCounts, jsonEncode(counts));
  }

  Future<StoreCounts> getStoreCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawJson = prefs.getString(_keyStoreCounts);
    if (rawJson == null || rawJson.isEmpty) return {};

    try {
      final Map<String, dynamic> decoded = jsonDecode(rawJson);
      return decoded.map((key, value) => MapEntry(key, (value as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  // Score del singolo prodotto
  Future<int> getInteractionScore(String productName) async {
    final counts = await getProductCounts();
    return matchScoreInMap(productName, counts);
  }

  // Quante volte ha inserito il prodotto
  int matchScoreInMap(String productName, ProductCounts counts) {
    final targetKeywords = _extractKeywords(productName);
    if (targetKeywords.isEmpty) return 0;

    int maxScore = 0;
    for (final count in counts.entries) {
      final savedKeywords = _extractKeywords(count.key);
      final common = targetKeywords.intersection(savedKeywords);

      final int requiredMatch = targetKeywords.length == 1 ? 1 : 2;
      if (common.length >= requiredMatch && count.value > maxScore) {
        maxScore = count.value;
      }
    }
    return maxScore;
  }

  // Verifica se è un prodotto abituale (minOccurrences variabile, default 1)
  bool isHabitualInMap(String productName, ProductCounts counts, {int minOccurrences = 1}) {
    return matchScoreInMap(productName, counts) >= minOccurrences;
  }

  // Cancello tutta la cronologia locale (prodotti e supermercati)
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyProductCounts);
    await prefs.remove(_keyStoreCounts);
  }

  // TEMA
  Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDarkMode) ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, value);
  }

  // LINGUA
  Future<String> getLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLanguage) ?? 'it';
  }

  Future<void> setLanguageCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, code);
  }
}
