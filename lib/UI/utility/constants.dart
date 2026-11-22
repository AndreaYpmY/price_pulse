class Constants {
  Constants._();

  static const String appName = 'PricePulse';
  static const String defaultLanguageCode = 'it'; // Lingua predefinita
  static const bool defaultDarkMode = false; // Tema chiaro predefinito

  static const Set<String> stopWords = {
    'il', 'lo', 'la', 'i', 'gli', 'le',
    'un', 'uno', 'una',
    'di', 'a', 'da', 'in', 'con', 'su', 'per', 'tra', 'fra',
    'al', 'allo', 'alla', 'ai', 'agli', 'alle',
    'del', 'dello', 'della', 'dei', 'degli', 'delle',
    'e', 'ed', 'o',
  };
  static const String keywordCleanupPattern = r'[^\w\sàèéìòù]'; // pulizia nomi prodotti

  // Soglie geografiche
  static const double maxLocalRadiusMeters = 20000.0; // 20 km
  static const double inStoreRadiusMeters = 150.0;    // 150 m, rilevare ingresso in negozio

  static const int fridayShoppingStartHour = 16;      // Venerdì dalle 16:00

  static const int maxDuplicateCandidates = 5;        // Max articoli simili (duplicateDialog)

  // Soglie anti-spam notifiche
  static const double minPriceDropPercentage = 0.05;  // Ribasso minimo del 5%
  static const int notificationCooldownHours = 24;    // Max 1 notifica ogni 24h per prodotto
  static const bool defaultPriceAlertsEnabled = true; // Avvisi ribassi attivi di default
}