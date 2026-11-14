import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

typedef ProductCounts = Map<String, int>;

class PreferencesService {
  static const String _keyProductCounts = 'habitual_product_counts';
  static const String _keyDarkMode = 'is_dark_mode';
  static const String _keyLanguage = 'language_code';

  static const Set<String> _stopWords = {
    'di', 'del', 'della', 'dei', 'degli', 'al', 'alla', 'con', 'per', 'in', 'da', 'il', 'la', 'le', 'un', 'una'
  };

  // Pulisce testo da Pasta di Barilla 500g diventa {"pasta","barilla","500g"}
  Set<String> _extractKeywords(String productName) {
    return productName
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length >= 2 && !_stopWords.contains(word))
        .toSet();
  }

  // Aggiorno contatore
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
      if (common.length >= 2 || existingKey == cleanName) { // Se hanno almeno 2 parole chiave in comune
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
      return decoded.map((key, value) => MapEntry(key, (value as num).toInt())); // Mappa prodotti
    } catch (_) {
      return {};
    }
  }
  // count del prodotto
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
      final common = targetKeywords.intersection(savedKeywords); // Restituisce nuovo insieme con solo parole presenti in entrambe

      final int requiredMatch = targetKeywords.length == 1 ? 1 : 2; // In base da quante parole è composto il prodotto
      if (common.length >= requiredMatch && count.value > maxScore) {
        maxScore = count.value;
      }
    }
    return maxScore;
  }

  // Se è un prodotto abituale (minOccurrences variabile, default 1)
  bool isHabitualInMap(String productName, ProductCounts counts, {int minOccurrences = 1}) {
    return matchScoreInMap(productName, counts) >= minOccurrences;
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyProductCounts);
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
