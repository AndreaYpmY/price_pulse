import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/objects/price_report.dart';
import '../../model/objects/store.dart';
import '../../model/providers/providers.dart';
import '../utility/app_localizations.dart';
import '../utility/product_matcher.dart';
import '../widgets/price_card.dart';
import '../widgets/settings_sheet.dart';

class HomePage extends ConsumerStatefulWidget {
  final VoidCallback onNavigateToScanner;

  const HomePage({
    super.key,
    required this.onNavigateToScanner,
  });

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _onlyHabitual = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Costruisco banner adattivo in base a luogo e giorno della settimana
  Widget _buildContextBanner(
    BuildContext context,
    UserContextState userContext,
    AppLocalizations loc,
  ) {
    final theme = Theme.of(context);

    IconData icon;
    String title;
    String subtitle;
    bool isActionable = false;

    switch (userContext.type) {
      case ContextType.inStore: // se vicino ad un supermercato
        icon = Icons.storefront_rounded;
        final storeName = userContext.nearbyStore?.name ?? '';
        final dist = userContext.distanceMeters != null
            ? ' (${userContext.distanceMeters!.round()} m)'
            : '';
        title = '${loc.translate('context_in_store_title')} $storeName$dist';
        subtitle = loc.translate('context_in_store_subtitle');
        isActionable = true;
        break;
      case ContextType.shoppingDay: // se è fine settimana (venerdi e sabato)
        icon = Icons.shopping_cart_checkout_rounded;
        title = loc.translate('context_shopping_day_title');
        subtitle = loc.translate('context_shopping_day_subtitle');
        break;
      case ContextType.general: // default
        icon = Icons.savings_outlined;
        title = loc.translate('context_general_title');
        subtitle = loc.translate('context_general_subtitle');
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Material(
        color: isActionable
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isActionable ? widget.onNavigateToScanner : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  child: Icon(icon, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isActionable
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isActionable
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActionable) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    final reportsAsync = ref.watch(priceReportsProvider);
    final storesAsync = ref.watch(storesProvider);
    final positionAsync = ref.watch(userLocationProvider);
    final userContext = ref.watch(userContextProvider);
    final habitualCounts = ref.watch(habitualProductsProvider);
    final locationService = ref.watch(locationServiceProvider);

    final hasHabitual = habitualCounts.isNotEmpty;
    final showOnlyHabitual = _onlyHabitual && hasHabitual;

    final stores = storesAsync.value ?? [];
    final Map<String, Store> storeById = {
      for (final s in stores) s.id: s,
    };
    final position = positionAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          loc.translate('app_name'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: loc.translate('settings_title'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => SettingsSheet.show(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Banner Context-Aware (Luogo / Tempo)
          _buildContextBanner(context, userContext, loc),

          // 2. Barra di ricerca testuale
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.trim()),
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
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.45),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 3. Chip filtro: compare solo se l'utente ha almeno un prodotto abituale salvato
          if (hasHabitual)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(loc.translate('filter_all')),
                    selected: !showOnlyHabitual,
                    onSelected: (_) => setState(() => _onlyHabitual = false),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(loc.translate('filter_habitual')),
                    selected: showOnlyHabitual,
                    onSelected: (_) => setState(() => _onlyHabitual = true),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 8),

          // 4. Feed offerte in tempo reale da Firestore
          Expanded(
            child: reportsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    err.toString(),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (allReports) {
                final queryLower = _searchQuery.toLowerCase();
                final habitualKeys = habitualCounts.keys.toList();

                final filteredReports = allReports.where((report) {
                  if (queryLower.isNotEmpty) {
                    final matchesText =
                        report.productName.toLowerCase().contains(queryLower) || report.storeName.toLowerCase().contains(queryLower);
                    if (!matchesText) return false;
                  }

                  if (showOnlyHabitual) {
                    final isHabitual = habitualKeys.any(
                      (habitName) =>
                          ProductMatcher.areSimilar(habitName, report.productName),
                    );
                    if (!isHabitual) return false;
                  }

                  return true;
                }).toList();

                if (filteredReports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          loc.translate('no_results'),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(userLocationProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 20),
                    itemCount: filteredReports.length,
                    itemBuilder: (context, index) {
                      final report = filteredReports[index];

                      final originalIndex = allReports.indexOf(report);
                      final olderReports = originalIndex >= 0 &&
                              originalIndex + 1 < allReports.length
                          ? allReports.sublist(originalIndex + 1)
                          : <PriceReport>[];

                      final previousReport = ProductMatcher.findLatestReport(
                        productName: report.productName,
                        storeId: report.storeId,
                        allReports: olderReports,
                      );

                      double? distanceMeters;
                      final store = storeById[report.storeId];
                      if (position != null && store != null) {
                        distanceMeters = locationService.calculateDistanceMeters(
                          position.latitude,
                          position.longitude,
                          store.lat,
                          store.lng,
                        );
                      }

                      return PriceCard(
                        key: ValueKey(report.id),
                        report: report,
                        previousReport: previousReport,
                        distanceMeters: distanceMeters,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
