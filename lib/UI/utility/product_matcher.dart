import '../../model/objects/price_report.dart';
import 'constants.dart';

class ProductMatcher {
  ProductMatcher._();

  static Set<String> extractKeywords(String productName) {
    final cleaned = productName
        .toLowerCase()
        .replaceAll(RegExp(Constants.keywordCleanupPattern), ' ')
        .trim();

    return cleaned
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 1 && !Constants.stopWords.contains(word))
        .toSet();
  }

  // Verifico se due nomi di prodotti si riferiscono allo stesso articolo
  static bool areSimilar(String nameA, String nameB) {
    final keywordsA = extractKeywords(nameA);
    final keywordsB = extractKeywords(nameB);

    if (keywordsA.isEmpty || keywordsB.isEmpty) return false;

    final commonCount = keywordsA.intersection(keywordsB).length;
    final minRequired = (keywordsA.length == 1 || keywordsB.length == 1) ? 1 : 2;

    return commonCount >= minRequired;
  }

  // Cerco potenziali duplicati già segnalati nello stesso supermercato:
  // - Mantengo solo la segnalazione più recente per ogni nome distinto
  // - Ordino per rilevanza (più parole in comune in cima, poi data)
  // - Limito ai primi [maxResults] risultati
  static List<PriceReport> findPotentialDuplicates({
    required String productName,
    required String storeId,
    required List<PriceReport> allReports,
    int maxResults = Constants.maxDuplicateCandidates,
  }) {
    final targetKeywords = extractKeywords(productName);
    if (targetKeywords.isEmpty) return [];

    final Map<String, PriceReport> latestByNormalizedName = {};

    for (final report in allReports) {
      if (report.storeId != storeId) continue;
      if (!areSimilar(productName, report.productName)) continue;

      final key = report.productName.trim().toLowerCase();
      final existing = latestByNormalizedName[key];
      if (existing == null || report.createdAt.isAfter(existing.createdAt)) {
        latestByNormalizedName[key] = report;
      }
    }

    final results = latestByNormalizedName.values.toList()
      ..sort((a, b) {
        final scoreA = targetKeywords.intersection(extractKeywords(a.productName)).length;
        final scoreB = targetKeywords.intersection(extractKeywords(b.productName)).length;
        if (scoreB != scoreA) {
          return scoreB.compareTo(scoreA);
        }
        return b.createdAt.compareTo(a.createdAt);
      });

    return results.take(maxResults).toList();
  }

  // Restituisco rilevazione più pertinente e recente nello stesso negozio
  static PriceReport? findLatestReport({
    required String productName,
    required String storeId,
    required List<PriceReport> allReports,
  }) {
    final matches = findPotentialDuplicates(
      productName: productName,
      storeId: storeId,
      allReports: allReports,
      maxResults: 1,
    );
    return matches.isNotEmpty ? matches.first : null;
  }
}