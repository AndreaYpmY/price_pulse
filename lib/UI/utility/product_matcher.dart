import '../../model/objects/price_report.dart';

class ProductMatcher {
  ProductMatcher._();

  // Parole comuni da ignorare durante il confronto tra nomi di prodotti
  static const Set<String> _stopWords = {
    'il', 'lo', 'la', 'i', 'gli', 'le',
    'un', 'uno', 'una',
    'di', 'a', 'da', 'in', 'con', 'su', 'per', 'tra', 'fra',
    'al', 'allo', 'alla', 'ai', 'agli', 'alle',
    'del', 'dello', 'della', 'dei', 'degli', 'delle',
    'e', 'ed', 'o',
  };

  // Pulisce testo
  static Set<String> extractKeywords(String productName) {
    final cleaned = productName
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\sàèéìòù]'), ' ')
        .trim();

    return cleaned
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 1 && !_stopWords.contains(word))
        .toSet();
  }

  // Verifico prodotti, si riferiscono allo stesso articolo?
  static bool areSimilar(String nameA, String nameB) {
    final keywordsA = extractKeywords(nameA);
    final keywordsB = extractKeywords(nameB);

    if (keywordsA.isEmpty || keywordsB.isEmpty) return false;

    final commonCount = keywordsA.intersection(keywordsB).length;

    // Se uno dei due nomi è formato da una sola parola (es. "Latte") basta 1 parola in comune, altrimenti ne servono almeno 2 (es. "barilla" + "500g")
    final minRequired = (keywordsA.length == 1 || keywordsB.length == 1) ? 1 : 2;

    return commonCount >= minRequired;
  }

  // Cerca duplicati già segnalati nello stesso supermercato, se prodotto ha più segnalazioni nel tempo, restituisce solo la più recente
  // (Per ogni nome distinto, ordinata dalla più recente alla più vecchia)
  static List<PriceReport> findPotentialDuplicates({
    required String productName,
    required String storeId,
    required List<PriceReport> allReports,
  }) {
    final Map<String, PriceReport> latestByNormalizedName = {};

    for (final report in allReports) {
      // Filtro solo segnalazioni dello stesso punto vendita
      if (report.storeId != storeId) continue;

      // Verifico somiglianza testuale
      if (!areSimilar(productName, report.productName)) continue;

      // Raggruppo per nome normalizzato tenendo solo la rilevazione più recente
      final key = report.productName.trim().toLowerCase();
      final existing = latestByNormalizedName[key];
      if (existing == null || report.createdAt.isAfter(existing.createdAt)) {
        latestByNormalizedName[key] = report;
      }
    }

    final results = latestByNormalizedName.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return results;
  }

  // Restituisco ultima segnalazione precedente dello stesso prodotto in quel negozio
  static PriceReport? findLatestReport({
    required String productName,
    required String storeId,
    required List<PriceReport> allReports,
  }) {
    final matches = findPotentialDuplicates(
      productName: productName,
      storeId: storeId,
      allReports: allReports,
    );
    return matches.isNotEmpty ? matches.first : null;
  }
}