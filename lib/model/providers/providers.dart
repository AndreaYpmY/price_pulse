import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:geolocator/geolocator.dart';

import '../objects/price_report.dart';
import '../objects/store.dart';
import '../services/firestore_service.dart';
import '../services/gemini_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/preferences_service.dart';


// SERVICE PROVIDERS (Singleton)
final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());
final geminiServiceProvider = Provider<GeminiService>((ref) => GeminiService());
final locationServiceProvider = Provider<LocationService>((ref) => LocationService());
final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());
final preferencesServiceProvider = Provider<PreferencesService>((ref) => PreferencesService());

// ----------------------------------------------------------------------------------------------------

// DATA STREAM PROVIDERS (Firestore)
final storesProvider = StreamProvider<List<Store>>((ref) {  // supermercati salvati in tempo reale
  return ref.watch(firestoreServiceProvider).getStoresStream();
});

final priceReportsProvider = StreamProvider<List<PriceReport>>((ref) {  // prezzi  salvati in tempo reale
  return ref.watch(firestoreServiceProvider).getReportsStream();
});

// ----------------------------------------------------------------------------------------------------

// LOCATION PROVIDER
final userLocationProvider = FutureProvider<Position?>((ref) async {  // posizione GPS attuale
  return ref.watch(locationServiceProvider).getCurrentPosition();
});

// ----------------------------------------------------------------------------------------------------

// SETTINGS & HABITS NOTIFIERS (Tema, Lingua e Cronologia Abituali)
class ThemeModeNotifier extends StateNotifier<ThemeMode> {    //  TEMA (chiaro/scuro)
  final PreferencesService _prefs;

  ThemeModeNotifier(this._prefs) : super(ThemeMode.light) {
    _load(); // default chiaro
  }

  Future<void> _load() async {  // vedo se aveva impostato dark mode
    final isDark = await _prefs.isDarkMode();
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggleTheme() async {  // switch tema
    final nextIsDark = state != ThemeMode.dark;
    state = nextIsDark ? ThemeMode.dark : ThemeMode.light;
    await _prefs.setDarkMode(nextIsDark);
  }
}
// ------------

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) { // provider del tema
  return ThemeModeNotifier(ref.watch(preferencesServiceProvider));
});

class LocaleNotifier extends StateNotifier<Locale> {  // LINGUA
  final PreferencesService _prefs;

  LocaleNotifier(this._prefs) : super(const Locale('it')) {
    _load();  // default italiano
  }

  Future<void> _load() async {  // vedo se aveva impostato la lingua
    final code = await _prefs.getLanguageCode();
    state = Locale(code);
  }

  Future<void> setLanguage(String code) async { // cambio lingua
    state = Locale(code);
    await _prefs.setLanguageCode(code);
  }
}
// ------------

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {  // provider lingua
  return LocaleNotifier(ref.watch(preferencesServiceProvider));
});

class HabitualProductsNotifier extends StateNotifier<ProductCounts> { // PRODOTTI ABITUALI
  final PreferencesService _prefs;

  HabitualProductsNotifier(this._prefs) : super({}) {
    refresh(); // mappa vuota inizialmente
  }

  Future<void> refresh() async { // leggo dal telefono la mappa aggiornata
    state = await _prefs.getProductCounts();
  }

  Future<void> recordInteraction(String productName) async { // aumenta contatore prodotto
    await _prefs.recordProductInteraction(productName);
    await refresh();
  }

  Future<void> clearHistory() async { // cancella history
    await _prefs.clearHistory();
    state = {};
  }
}

final habitualProductsProvider = StateNotifierProvider<HabitualProductsNotifier, ProductCounts>((ref) { // provider prodotti abituali
  return HabitualProductsNotifier(ref.watch(preferencesServiceProvider));
});

// ----------------------------------------------------------------------------------------------------

// CONTEXT-AWARE ENGINE (Posizione + Tempo + Abitudini)
enum ContextType { inStore, shoppingDay, habitualDeals, general } // 4 possibili situazioni

class UserContextState {
  final ContextType type;
  final Store? nearbyStore;
  final double? distanceMeters;

  const UserContextState({
    required this.type,
    this.nearbyStore,
    this.distanceMeters,
  });
}

final userContextProvider = Provider<UserContextState>((ref) { // calcolare contesto attuale
  final positionAsync = ref.watch(userLocationProvider);
  final storesAsync = ref.watch(storesProvider);
  final locationService = ref.watch(locationServiceProvider);
  final habitualCounts = ref.watch(habitualProductsProvider);

  final position = positionAsync.value;
  final stores = storesAsync.value ?? [];

  // Regola 1 (Spazio): Verifico se l'utente si trova entro 150m da un supermercato
  if (position != null && stores.isNotEmpty) {
    Store? closestStore;
    double minDistance = double.infinity;

    for (final store in stores) { // supermercato più vicino
      final dist = locationService.calculateDistanceMeters(
        position.latitude,
        position.longitude,
        store.lat,
        store.lng,
      );
      if (dist < minDistance) {
        minDistance = dist;
        closestStore = store;
      }
    }

    if (closestStore != null && minDistance <= 150) { // supermercato se è a 150metri
      return UserContextState(
        type: ContextType.inStore,
        nearbyStore: closestStore,
        distanceMeters: minDistance,
      );
    }
  }

  // Regola 2 (Contesto Storico): L'utente ha già prodotti abituali salvati
  if (habitualCounts.isNotEmpty) {
    return const UserContextState(type: ContextType.habitualDeals);
  }

  // Regola 3 (Tempo): Sabato o Venerdì pomeriggio (giorni tipici di spesa)
  final now = DateTime.now();
  if (now.weekday == DateTime.saturday || (now.weekday == DateTime.friday && now.hour >= 16)) {
    return const UserContextState(type: ContextType.shoppingDay);
  }

  return const UserContextState(type: ContextType.general);
});

