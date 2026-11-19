import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../model/objects/price_report.dart';
import '../../model/providers/providers.dart';
import '../widgets/duplicate_dialog.dart';
import '../widgets/laser_scanner.dart';
import '../widgets/price_card.dart';
import '../widgets/settings_sheet.dart';

class WidgetPreviewPage extends ConsumerStatefulWidget {
  final VoidCallback? onToggleTheme;
  final VoidCallback? onToggleLocale;

  const WidgetPreviewPage({
    super.key,
    this.onToggleTheme,
    this.onToggleLocale,
  });

  @override
  ConsumerState<WidgetPreviewPage> createState() => _WidgetPreviewPageState();
}

class _WidgetPreviewPageState extends ConsumerState<WidgetPreviewPage> {
  File? _dummyImageFile;

  @override
  void initState() {
    super.initState();
    _createDummyImage();
  }

  Future<void> _createDummyImage() async {
    const base64Png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
    final file = File('${Directory.systemTemp.path}/test_cartellino.png');
    await file.writeAsBytes(base64Decode(base64Png));
    if (mounted) {
      setState(() => _dummyImageFile = file);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final habitualCount = ref.watch(habitualProductsProvider).length;

    final reportNuovo = PriceReport(
      id: '2',
      productName: 'Pasta Barilla Spaghetti n.5 500g',
      price: 1.19,
      storeId: 's1',
      storeName: 'Conad Via Roma',
      lat: 39.36,
      lng: 16.22,
      createdAt: now.subtract(const Duration(minutes: 15)),
    );

    final reportVecchio = PriceReport(
      id: '1',
      productName: 'Pasta Barilla Spaghetti 500g',
      price: 1.38,
      storeId: 's1',
      storeName: 'Conad Via Roma',
      lat: 39.36,
      lng: 16.22,
      createdAt: now.subtract(const Duration(hours: 3)),
    );

    final reportSingolo = PriceReport(
      id: '3',
      productName: 'Olio Extra Vergine di Oliva 1L',
      price: 6.49,
      storeId: 's2',
      storeName: 'Lidl Viale Parco',
      lat: 39.35,
      lng: 16.23,
      createdAt: now.subtract(const Duration(hours: 5)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogo Widget'),
        actions: [
          IconButton(
            tooltip: 'Impostazioni',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => SettingsSheet.show(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              '1. PriceCard',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          PriceCard(
            report: reportNuovo,
            previousReport: reportVecchio,
            distanceMeters: 250,
            onTap: () => debugPrint('Cliccata card 1'),
          ),
          PriceCard(
            report: reportSingolo,
            distanceMeters: 1450,
            onTap: () => debugPrint('Cliccata card 2'),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              '2. LaserScanner (Animazione TickerProvider)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _dummyImageFile == null
                ? const Center(child: CircularProgressIndicator())
                : LaserScanner(imageFile: _dummyImageFile!),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              '3. SettingsSheet (Modal Bottom Sheet + Riverpod)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Apri SettingsSheet'),
                  onPressed: () => SettingsSheet.show(context),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: Text('Simula abituale ($habitualCount)'),
                  onPressed: () async {
                    await ref
                        .read(habitualProductsProvider.notifier)
                        .recordInteraction('Pasta Barilla 500g');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              '4. DuplicateDialog (AlertDialog Anti-Duplicati)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.compare_arrows_rounded),
              label: const Text('Apri DuplicateDialog'),
              onPressed: () async {
                final resolution = await DuplicateDialog.show(
                  context,
                  duplicates: [reportNuovo, reportVecchio],
                  newProductName: 'Spaghetti Barilla 500g',
                  newPrice: 0.99,
                );

                if (!context.mounted) return;

                final String feedback;
                if (resolution == null) {
                  feedback = 'Scelta: Indietro (nessun salvataggio)';
                } else if (resolution.type ==
                    DuplicateResolutionType.updateExisting) {
                  feedback =
                      'Scelta: Aggiorna "${resolution.targetReport?.productName}" a € 0.99';
                } else {
                  feedback = 'Scelta: Salva come nuovo prodotto';
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(feedback)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
