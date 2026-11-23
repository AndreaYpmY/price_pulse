import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:price_pulse/UI/utility/constants.dart';

import '../../model/objects/price_report.dart';
import '../../model/objects/store.dart';
import '../../model/providers/providers.dart';
import '../../model/services/location_service.dart';
import '../utility/app_localizations.dart';
import '../widgets/store_prices_sheet.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  bool _hasCenteredOnUser = false;

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatDistanceBadge(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  double? _calculateDistance(
      Store store,
      Position? position,
      LocationService locationService,
      ) {
    if (position == null) return null;
    if (store.lat == 0 && store.lng == 0) return null;

    return locationService.calculateDistanceMeters(
      position.latitude,
      position.longitude,
      store.lat,
      store.lng,
    );
  }

  void _centerOnUser(Position? position) {
    if (position != null) {
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        15.0,
      );
    } else {
      ref.invalidate(userLocationProvider);
    }
  }

  void _openStoreDetails(
      Store store,
      List<PriceReport> allReports,
      double? distanceMeters,
      ) {
    _mapController.move(LatLng(store.lat, store.lng), 15.5);
    StorePricesSheet.show(
      context,
      store: store,
      allReports: allReports,
      distanceMeters: distanceMeters,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    final storesAsync = ref.watch(storesProvider);
    final reportsAsync = ref.watch(priceReportsProvider);
    final positionAsync = ref.watch(userLocationProvider);
    final habitualStoreCounts = ref.watch(habitualStoresProvider);
    final locationService = ref.watch(locationServiceProvider);

    final stores = storesAsync.value ?? [];
    final allReports = reportsAsync.value ?? [];
    final position = positionAsync.value;

    // Centro automaticamente sulla posizione GPS la prima volta che viene agganciata
    ref.listen<AsyncValue<Position?>>(userLocationProvider, (_, next) {
      final pos = next.value;
      if (pos != null && !_hasCenteredOnUser) {
        _hasCenteredOnUser = true;
        _mapController.move(LatLng(pos.latitude, pos.longitude), Constants.defaultZoom);
      }
    });

    if (position != null && !_hasCenteredOnUser) {
      _hasCenteredOnUser = true;
    }

    // Conto quanti prodotti distinti hanno un prezzo attivo per ogni supermercato
    final Map<String, Set<String>> uniqueProductsByStore = {};
    for (final report in allReports) {
      uniqueProductsByStore
          .putIfAbsent(report.storeId, () => <String>{})
          .add(report.productName.trim().toLowerCase());
    }

    // Pre-calcolo le distanze dei supermercati dall'utente
    final Map<String, double?> distanceByStoreId = {
      for (final store in stores)
        store.id: _calculateDistance(store, position, locationService),
    };

    // Ricerca rapida per nome supermercato oppure per prodotto disponibile in quel negozio
    final queryLower = _searchQuery.toLowerCase();
    final List<Store> matchingStores = queryLower.isEmpty ? [] : stores.where((store) {
      if (store.name.toLowerCase().contains(queryLower)) return true;
      final products = uniqueProductsByStore[store.id];
      if (products == null) return false;
      return products.any((p) => p.contains(queryLower));
    }).toList()
      ..sort((a, b) {
        final distA = distanceByStoreId[a.id];
        final distB = distanceByStoreId[b.id];
        if (distA != null && distB != null) {
          return distA.compareTo(distB);
        }
        return a.name.compareTo(b.name);
      });

    final initialCenter = position != null ? LatLng(position.latitude, position.longitude) : Constants.defaultCenter;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          loc.translate('map_title'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Stack(
        children: [
          // 1. Mappa interattiva OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: Constants.defaultZoom,
              minZoom: 4,
              maxZoom: 18,
              onTap: (_, _) {
                if (_searchQuery.isNotEmpty) {
                  FocusScope.of(context).unfocus();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.price_pulse',
              ),
              MarkerLayer(
                markers: [
                  // Marker dei supermercati
                  ...stores
                      .where((s) => s.lat != 0 || s.lng != 0)
                      .map((store) {
                    final offerCount =
                        uniqueProductsByStore[store.id]?.length ?? 0;
                    final isHabitualStore =
                    habitualStoreCounts.containsKey(store.id);
                    final hasOffers = offerCount > 0;

                    return Marker(
                      point: LatLng(store.lat, store.lng),
                      width: 68,
                      height: 52,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: () => _openStoreDetails(
                          store,
                          allReports,
                          distanceByStoreId[store.id],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: hasOffers
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isHabitualStore
                                      ? Colors.amber.shade600
                                      : theme.colorScheme.primary,
                                  width: isHabitualStore ? 2 : 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.storefront_rounded,
                                    size: 16,
                                    color: hasOffers
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.primary,
                                  ),
                                  if (hasOffers) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '$offerCount',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: theme.colorScheme.onPrimary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 18,
                              color: hasOffers
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surface,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Marker posizione attuale utente
                  if (position != null)
                    Marker(
                      point: LatLng(position.latitude, position.longitude),
                      width: 26,
                      height: 26,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.35),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 2. Barra di ricerca sovrapposta (cerca per supermercato o per prodotto)
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  elevation: 3,
                  shadowColor: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  color: theme.colorScheme.surface,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _searchQuery = value.trim()),
                    decoration: InputDecoration(
                      hintText: loc.translate('search_hint'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // Elenco rapido risultati filtrati
                if (_searchQuery.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: matchingStores.isEmpty
                        ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        loc.translate('no_results'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                        : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: matchingStores.length,
                      separatorBuilder: (_, _) =>
                      const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final store = matchingStores[index];
                        final dist = distanceByStoreId[store.id];
                        final offerCount =
                            uniqueProductsByStore[store.id]?.length ?? 0;

                        return ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.storefront_rounded,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(
                            store.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: offerCount > 0
                              ? Text(
                            '${loc.translate('latest_prices')}: $offerCount',
                          )
                              : null,
                          trailing: dist != null
                              ? Text(
                            _formatDistanceBadge(dist),
                            style: theme.textTheme.labelMedium
                                ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          )
                              : null,
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _openStoreDetails(store, allReports, dist);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 3. Indicatore caricamento iniziale supermercati
          if (storesAsync.isLoading)
            const Positioned(
              top: 76,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                ),
              ),
            ),

          // 4. Attribuzione OpenStreetMap
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '© OpenStreetMap',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _centerOnUser(position),
        child: const Icon(Icons.my_location_rounded),
      ),
    );
  }
}