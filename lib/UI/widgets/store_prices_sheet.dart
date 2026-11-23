import 'package:flutter/material.dart';

import '../../model/objects/price_report.dart';
import '../../model/objects/store.dart';
import '../utility/app_localizations.dart';
import '../utility/product_matcher.dart';
import 'price_card.dart';

class StorePricesSheet extends StatelessWidget {
  final Store store;
  final List<PriceReport> allReports;
  final double? distanceMeters;

  const StorePricesSheet({
    super.key,
    required this.store,
    required this.allReports,
    this.distanceMeters,
  });

  // Metodo per aprire il pannello dal basso
  static Future<void> show(
      BuildContext context, {
        required Store store,
        required List<PriceReport> allReports,
        double? distanceMeters,
      }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StorePricesSheet(
        store: store,
        allReports: allReports,
        distanceMeters: distanceMeters,
      ),
    );
  }

  String _formatDistanceBadge(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    // Filtro solo segnalazioni appartenenti a questo supermercato
    final storeReports =
    allReports.where((r) => r.storeId == store.id).toList();

    // Mantengo solo ultima rilevazione per ciascun prodotto
    final Map<String, PriceReport> latestByProduct = {};
    for (final report in storeReports) {
      final key = report.productName.trim().toLowerCase();
      final existing = latestByProduct[key];
      if (existing == null || report.createdAt.isAfter(existing.createdAt)) {
        latestByProduct[key] = report;
      }
    }

    final latestList = latestByProduct.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.88,
      builder: (context, scrollController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Intestazione con nome supermercato e badge distanza GPS
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    child: const Icon(Icons.storefront_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          loc.translate('latest_prices'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (distanceMeters != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _formatDistanceBadge(distanceMeters!),
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),

            // Elenco scorrevole degli ultimi prezzi rilevati nel punto vendita
            Expanded(
              child: latestList.isEmpty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 44,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        loc.translate('no_store_prices'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  : ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: latestList.length,
                itemBuilder: (context, index) {
                  final report = latestList[index];
                  final olderReports = storeReports
                      .where((r) => r.id != report.id && r.createdAt.isBefore(report.createdAt),).toList();

                  final previousReport = ProductMatcher.findLatestReport(
                    productName: report.productName,
                    storeId: store.id,
                    allReports: olderReports,
                  );

                  return PriceCard(
                    key: ValueKey(report.id),
                    report: report,
                    previousReport: previousReport,
                    distanceMeters: distanceMeters,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}