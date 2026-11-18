import 'package:flutter/material.dart';
import '../../model/objects/price_report.dart';
import '../utility/app_localizations.dart';
import '../utility/app_theme.dart';

// todo: colori e disposizione provvisoria (forse) solo per strutturare la card

class PriceCard extends StatelessWidget {
  final PriceReport report;
  final PriceReport? previousReport; //eventuale rilevazione precedente
  final double? distanceMeters;
  final VoidCallback? onTap;

  const PriceCard({
    super.key,
    required this.report,
    this.previousReport,
    this.distanceMeters,
    this.onTap
  });

  // Formatto distanza in metri o chilometri
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  // Formatto in modo compatto la data della segnalazione es. 'Oggi', '1g fa' ecc.
  String _formatRelativeDate(DateTime date, String langCode) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes <= 0 ? 1 : diff.inMinutes;
      return langCode == 'en' ? '${mins}m ago' : '${mins}m fa';
    }
    if (diff.inHours < 24) {
      return langCode == 'en' ? '${diff.inHours}h ago' : '${diff.inHours}h fa';
    }
    return langCode == 'en' ? '${diff.inDays}d ago' : '${diff.inDays}g fa';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final langCode = loc.locale.languageCode;

    // Calcolo se c'è stata variazione prezzo rispetto alla rilevazione precedente
    final hasPrevious = previousReport != null && previousReport!.price != report.price;
    final isPriceDrop = hasPrevious && report.price < previousReport!.price;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell( // per rendere cliccabile
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Nome prodotto + Prezzo attuale in evidenza
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      report.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '€ ${report.price.toStringAsFixed(2)}', // due decimali
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 2. Supermercato, distanza GPS e tempo trascorso
              Row(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      distanceMeters != null ? '${report.storeName} · ${_formatDistance(distanceMeters!)}' : report.storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatRelativeDate(report.createdAt, langCode),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  ),
                ]
              ),

              // 3. Badge opzionale di calo o rincaro
              if (hasPrevious) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (isPriceDrop ? AppTheme.priceDropColor : AppTheme.priceRiseColor).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPriceDrop ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                        size: 16,
                        color: isPriceDrop ? AppTheme.priceDropColor : AppTheme.priceRiseColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${loc.translate(isPriceDrop ? 'price_drop' : 'price_rise')} (€ ${previousReport!.price.toStringAsFixed(2)})',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isPriceDrop ? AppTheme.priceDropColor : AppTheme.priceRiseColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
