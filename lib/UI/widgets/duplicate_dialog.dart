import 'package:flutter/material.dart';
import '../../model/objects/price_report.dart';
import '../utility/app_localizations.dart';

enum DuplicateResolutionType { updateExisting, saveAsNew }

class DuplicateResolution {
  final DuplicateResolutionType type;
  final PriceReport? targetReport;

  const DuplicateResolution._(this.type, [this.targetReport]);

  const DuplicateResolution.update(PriceReport report)
      : this._(DuplicateResolutionType.updateExisting, report);

  const DuplicateResolution.saveAsNew()
      : this._(DuplicateResolutionType.saveAsNew);
}

class DuplicateDialog extends StatefulWidget {
  final List<PriceReport> duplicates;
  final String newProductName;
  final double newPrice;

  const DuplicateDialog({
    super.key,
    required this.duplicates,
    required this.newProductName,
    required this.newPrice,
  });

  static Future<DuplicateResolution?> show(
      BuildContext context, {
        required List<PriceReport> duplicates,
        required String newProductName,
        required double newPrice,
      }) {
    return showDialog<DuplicateResolution>(
      context: context,
      builder: (_) => DuplicateDialog(
        duplicates: duplicates,
        newProductName: newProductName,
        newPrice: newPrice,
      ),
    );
  }

  @override
  State<DuplicateDialog> createState() => _DuplicateDialogState();
}

class _DuplicateDialogState extends State<DuplicateDialog> {
  late PriceReport _selectedDuplicate;

  @override
  void initState() {
    super.initState();
    _selectedDuplicate = widget.duplicates.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      icon: Icon(
        Icons.compare_arrows_rounded,
        size: 32,
        color: theme.colorScheme.primary,
      ),
      title: Text(
        loc.translate('duplicate_title'),
        textAlign: TextAlign.center,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loc.translate('duplicate_message'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 190),
            child: Scrollbar(
              thumbVisibility: widget.duplicates.length > 2,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.duplicates.map((item) {
                    final isSelected = item.id == _selectedDuplicate.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: widget.duplicates.length > 1 ? () => setState(() => _selectedDuplicate = item) : null,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.productName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '€ ${item.price.toStringAsFixed(2)}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Riepilogo del nuovo prezzo inserito
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    widget.newProductName,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '→ € ${widget.newPrice.toStringAsFixed(2)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 1. Azione consigliata
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop(
                DuplicateResolution.update(_selectedDuplicate),
              );
            },
            icon: const Icon(Icons.sync_rounded),
            label: Text(loc.translate('update_price')),
          ),

          const SizedBox(height: 8),

          // 2. Azione secondaria
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop(
                const DuplicateResolution.saveAsNew(),
              );
            },
            child: Text(loc.translate('save_as_new')),
          ),

          const SizedBox(height: 4),

          // 3. Annulla
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(loc.translate('back')),
          ),
        ],
      ),
    );
  }
}