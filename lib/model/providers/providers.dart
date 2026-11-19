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
final storesProvider = StreamProvider<List<Store>>((ref) {
  return ref.watch(firestoreServiceProvider).getStoresStream();
});

final priceReportsProvider = StreamProvider<List<PriceReport>>((ref) {
  return ref.watch(firestoreServiceProvider).getReportsStream();
});

// ----------------------------------------------------------------------------------------------------

// LOCATION PROVIDER
final userLocationProvider = FutureProvider<Position?>((ref) async {
  return ref.watch(locationServiceProvider).getCurrentPosition();
});

// ----------------------------------------------------------------------------------------------------

// SETTINGS & HABITS NOTIFIERS (Tema, Lingua e Cronologia Abituali)
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final PreferencesService _prefs;

  ThemeModeNotifier(this._prefs) : super(ThemeMode.light) {
    _load();
  }

  Future<void> _load() async {
    final isDark = await _prefs.isDarkMode();
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggleTheme() async {
    final nextIsDark = state != ThemeMode.dark;
    state = nextIsDark ? ThemeMode.dark : ThemeMode.light;
    await _prefs.setDarkMode(nextIsDark);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(preferencesServiceProvider));
});

class LocaleNotifier extends StateNotifier<Locale> {
  final PreferencesService _prefs;

  LocaleNotifier(this._prefs) : super(const Locale('it')) {
    _load();
  }

  Future<void> _load() async {
    final code = await _prefs.getLanguageCode();
    state = Locale(code);
  }

  Future<void> setLanguage(String code) async {
    state = Locale(code);
    await _prefs.setLanguageCode(code);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier(ref.watch(preferencesServiceProvider));
});

class HabitualProductsNotifier extends StateNotifier<ProductCounts> {
  final PreferencesService _prefs;

  HabitualProductsNotifier(this._prefs) : super({}) {
    refresh();
  }

  Future<void> refresh() async {
    state = await _prefs.getProductCounts();
  }

  Future<void> recordInteraction(String productName) async {
    await _prefs.recordProductInteraction(productName);
    await refresh();
  }

  Future<void> clearHistory() async {
    await _prefs.clearHistory();
    state = {};
  }
}

final habitualProductsProvider = StateNotifierProvider<HabitualProductsNotifier, ProductCounts>((ref) {
  return HabitualProductsNotifier(ref.watch(preferencesServiceProvider));
});

// ----------------------------------------------------------------------------------------------------

// CONTEXT-AWARE ENGINE (Spazio + Tempo)
enum ContextType { inStore, shoppingDay, general }

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

final userContextProvider = Provider<UserContextState>((ref) {
  final positionAsync = ref.watch(userLocationProvider);
  final storesAsync = ref.watch(storesProvider);
  final locationService = ref.watch(locationServiceProvider);

  final position = positionAsync.value;
  final stores = storesAsync.value ?? [];

  // Regola 1 (Spazio): Verifico se l'utente si trova entro 150m da un supermercato
  if (position != null && stores.isNotEmpty) {
    Store? closestStore;
    double minDistance = double.infinity;

    for (final store in stores) {
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

    if (closestStore != null && minDistance <= 150) {
      return UserContextState(
        type: ContextType.inStore,
        nearbyStore: closestStore,
        distanceMeters: minDistance,
      );
    }
  }

  // Regola 2 (Tempo): Sabato o Venerdì pomeriggio (giorni tipici di spesa)
  final now = DateTime.now();
  if (now.weekday == DateTime.saturday ||
      (now.weekday == DateTime.friday && now.hour >= 16)) {
    return const UserContextState(type: ContextType.shoppingDay);
  }

  return const UserContextState(type: ContextType.general);
});
