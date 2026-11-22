import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../model/objects/price_report.dart';
import '../../model/objects/store.dart';
import '../../model/providers/providers.dart';
import '../../model/services/location_service.dart';
import '../utility/app_localizations.dart';
import '../utility/product_matcher.dart';
import '../widgets/duplicate_dialog.dart';
import '../widgets/laser_scanner.dart';

class ScannerPage extends ConsumerStatefulWidget {
  const ScannerPage({super.key});

  @override
  ConsumerState<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends ConsumerState<ScannerPage> {
  final _formKey = GlobalKey<FormState>(); // se tutti campi sono stati compilati
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _picker = ImagePicker();

  File? _selectedImage;
  String? _selectedStoreId;
  bool _hasUserSelectedStore = false;

  // fasi della schermata
  bool _isAnalyzing = false;
  bool _isFormVisible = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _resetScanner() {
    setState(() {
      _selectedImage = null;
      _isAnalyzing = false;
      _isFormVisible = false;
      _isSaving = false;
      _hasUserSelectedStore = false;
      _selectedStoreId = null;
      _nameController.clear();
      _priceController.clear();
    });
  }

  void _startManualEntry() { // inserimento a mano
    setState(() {
      _selectedImage = null;
      _isAnalyzing = false;
      _isFormVisible = true;
      _nameController.clear();
      _priceController.clear();
    });
  }

  Future<void> _pickAndAnalyzeImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1600);

      if (pickedFile == null) return;

      final imageFile = File(pickedFile.path);
      setState(() {
        _selectedImage = imageFile;
        _isAnalyzing = true;
        _isFormVisible = false;
      });

      final imageBytes = await imageFile.readAsBytes();
      final result = await ref.read(geminiServiceProvider).analyzePriceTag(imageBytes); // risultato da gemini

      if (!mounted) return; // verifico se non si è cambiata schermata

      setState(() {
        _isAnalyzing = false;
        _isFormVisible = true;
        if (result != null) {
          _nameController.text = result.productName;
          if (result.price > 0) {
            _priceController.text = result.price.toStringAsFixed(2);
          }
        }
      });
    } catch (_) { // se manca o c'è un errore si va per la compilazione manuale
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _isFormVisible = true;
      });
    }
  }

  // ordinamento supermercati per vicinanza
  List<Store> _sortStoresByDistance(List<Store> stores, Position? position, LocationService locationService) {
    final sorted = List<Store>.from(stores);
    if (position == null) {
      sorted.sort((a, b) => a.name.compareTo(b.name));
      return sorted;
    }

    sorted.sort((a, b) {
      final distA = locationService.calculateDistanceMeters(
        position.latitude,
        position.longitude,
        a.lat,
        a.lng,
      );
      final distB = locationService.calculateDistanceMeters(
        position.latitude,
        position.longitude,
        b.lat,
        b.lng,
      );
      return distA.compareTo(distB);
    });
    return sorted;
  }

  String _formatDistanceBadge(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _buildStoreLabel(
      Store store,
      Position? position,
      LocationService locationService,
      ) {
    if (position == null) return store.name;
    final dist = locationService.calculateDistanceMeters(
      position.latitude,
      position.longitude,
      store.lat,
      store.lng,
    );
    return '${store.name} (${_formatDistanceBadge(dist)})';
  }

  // Apre pannello ricercabile per scegliere il supermercato (ordinato dal più vicino)
  Future<String?> _openStoreSearchPicker({
    required List<Store> sortedStores,
    required String? currentStoreId,
    required Position? position,
    required LocationService locationService,
    required AppLocalizations loc,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        String searchQuery = '';

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final queryLower = searchQuery.toLowerCase();
            final filteredStores = queryLower.isEmpty
                ? sortedStores
                : sortedStores
                .where((s) => s.name.toLowerCase().contains(queryLower))
                .toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.65,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Text(
                        loc.translate('select_store'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        onChanged: (value) {
                          setSheetState(() => searchQuery = value.trim());
                        },
                        decoration: InputDecoration(
                          hintText: loc.translate('search_hint'),
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              setSheetState(() => searchQuery = '');
                            },
                          )
                              : null,
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.45),
                          contentPadding:
                          const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filteredStores.isEmpty
                          ? Center(
                        child: Text(
                          loc.translate('no_results'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                          : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                        itemCount: filteredStores.length,
                        separatorBuilder: (_, _) =>
                        const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final store = filteredStores[index];
                          final isSelected = store.id == currentStoreId;
                          final distanceText = position != null
                              ? _formatDistanceBadge(
                            locationService.calculateDistanceMeters(
                              position.latitude,
                              position.longitude,
                              store.lat,
                              store.lng,
                            ),
                          )
                              : null;

                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            selected: isSelected,
                            selectedTileColor: theme
                                .colorScheme.primaryContainer
                                .withValues(alpha: 0.4),
                            leading: Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.storefront_rounded,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            title: Text(
                              store.name,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            trailing: distanceText != null
                                ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme
                                    .secondaryContainer,
                                borderRadius:
                                BorderRadius.circular(8),
                              ),
                              child: Text(
                                distanceText,
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme
                                      .onSecondaryContainer,
                                ),
                              ),
                            )
                                : null,
                            onTap: () =>
                                Navigator.of(sheetContext).pop(store.id),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitReport(List<Store> stores) async {
    final loc = AppLocalizations.of(context)!;

    if (!(_formKey.currentState?.validate() ?? false) || _selectedStoreId == null) { // controllo campi obbligatori
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.translate('all_fields_required'))),
      );
      return;
    }

    final selectedStore = stores.firstWhere(
          (s) => s.id == _selectedStoreId,
      orElse: () => stores.first,
    );

    // prendo nome e prezzo prodotto
    final rawName = _nameController.text.trim();
    final normalizedPriceText = _priceController.text.trim().replaceAll(',', '.');
    final parsedPrice = double.tryParse(normalizedPriceText);

    if (rawName.isEmpty || parsedPrice == null || parsedPrice <= 0) { // controllo campi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.translate('all_fields_required'))),
      );
      return;
    }

    setState(() => _isSaving = true); // caricamento salvataggio

    try {
      final allReports = ref.read(priceReportsProvider).value ?? [];

      // 1. Controllo anti-duplicati nello stesso supermercato
      final duplicates = ProductMatcher.findPotentialDuplicates(
        productName: rawName,
        storeId: selectedStore.id,
        allReports: allReports,
      );

      String finalProductName = rawName;

      if (duplicates.isNotEmpty) {
        if (!mounted) return;
        final resolution = await DuplicateDialog.show(
          context,
          duplicates: duplicates,
          newProductName: rawName,
          newPrice: parsedPrice,
        );

        if (!mounted) return;

        // L'utente ha premuto "Indietro": annulla il salvataggio
        if (resolution == null) {
          setState(() => _isSaving = false);
          return;
        }

        // L'utente ha voluto aggiornare prezzo
        if (resolution.type == DuplicateResolutionType.updateExisting &&
            resolution.targetReport != null) {
          finalProductName = resolution.targetReport!.productName;
        }
      }

      // 2. Recupero l'ID anonimo del dispositivo per evitare auto notifiche
      final deviceId = await ref.read(preferencesServiceProvider).getDeviceId();

      // 3. Salvataggio su Cloud Firestore
      final report = PriceReport(
        id: '',
        productName: finalProductName,
        price: parsedPrice,
        storeId: selectedStore.id,
        storeName: selectedStore.name,
        lat: selectedStore.lat,
        lng: selectedStore.lng,
        createdAt: DateTime.now(),
        reporterId: deviceId,
      );

      await ref.read(firestoreServiceProvider).addPriceReport(report);

      // 4. Aggiorno abitudini locali (prodotto + supermercato)
      await ref
          .read(habitualProductsProvider.notifier)
          .recordInteraction(finalProductName, storeId: selectedStore.id);

      if (!mounted) return;

      _resetScanner();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.translate('report_saved'))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    final storesAsync = ref.watch(storesProvider);
    final positionAsync = ref.watch(userLocationProvider);
    final locationService = ref.watch(locationServiceProvider);

    final rawStores = storesAsync.value ?? [];
    final position = positionAsync.value;
    final sortedStores = _sortStoresByDistance(
      rawStores,
      position,
      locationService,
    );

    // Pre-seleziono automaticamente supermercato più vicino se utente non ha scelto manualmente
    if (!_hasUserSelectedStore && sortedStores.isNotEmpty) {
      _selectedStoreId = sortedStores.first.id;
    }

    final validSelectedStoreId =
    sortedStores.any((s) => s.id == _selectedStoreId) ? _selectedStoreId : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          loc.translate('scanner_title'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_isFormVisible && !_isAnalyzing)
            IconButton(
              tooltip: loc.translate('back'),
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _isSaving ? null : _resetScanner,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _buildBodyContent(
            theme: theme,
            loc: loc,
            storesAsync: storesAsync,
            sortedStores: sortedStores,
            validSelectedStoreId: validSelectedStoreId,
            position: position,
            locationService: locationService,
          ),
        ),
      ),
    );
  }

  // layout diverso in base alla schermata
  Widget _buildBodyContent({
    required ThemeData theme,
    required AppLocalizations loc,
    required AsyncValue<List<Store>> storesAsync,
    required List<Store> sortedStores,
    required String? validSelectedStoreId,
    required Position? position,
    required LocationService locationService,
  }) {
    // FASE 2: Analisi AI in corso con animazione LaserScanner
    if (_isAnalyzing && _selectedImage != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LaserScanner(imageFile: _selectedImage!),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        loc.translate('analyzing_ai'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    // FASE 3: Modulo conferma dati (precompilato da Gemini o manuale)
    if (_isFormVisible) {
      return Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Image.file(
                      _selectedImage!,
                      height: 170,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: FilledButton.tonalIcon(
                        onPressed: _isSaving ? null : _resetScanner,
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: Text(loc.translate('take_photo')),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Campo Nome Prodotto
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: loc.translate('product_name'),
                prefixIcon: const Icon(Icons.shopping_bag_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return loc.translate('all_fields_required');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Campo prezzo
            TextFormField(
              controller: _priceController,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: loc.translate('product_price'),
                prefixIcon: const Icon(Icons.euro_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return loc.translate('all_fields_required');
                }
                final parsed =
                double.tryParse(value.trim().replaceAll(',', '.'));
                if (parsed == null || parsed <= 0) {
                  return loc.translate('all_fields_required');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Selezione Supermercato (ordinato dal più vicino tramite GPS + barra di ricerca)
            storesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Text(err.toString()),
              data: (_) {
                if (sortedStores.isEmpty) {
                  return Text(
                    loc.translate('no_results'),
                    style: TextStyle(color: theme.colorScheme.error),
                  );
                }

                Store? selectedStore;
                if (validSelectedStoreId != null) {
                  for (final s in sortedStores) {
                    if (s.id == validSelectedStoreId) {
                      selectedStore = s;
                      break;
                    }
                  }
                }

                return FormField<String>(
                  key: ValueKey(validSelectedStoreId ?? 'no_store'),
                  initialValue: validSelectedStoreId,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return loc.translate('all_fields_required');
                    }
                    return null;
                  },
                  builder: (fieldState) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _isSaving
                          ? null
                          : () async {
                        final pickedId = await _openStoreSearchPicker(
                          sortedStores: sortedStores,
                          currentStoreId: validSelectedStoreId,
                          position: position,
                          locationService: locationService,
                          loc: loc,
                        );
                        if (pickedId != null && mounted) {
                          fieldState.didChange(pickedId);
                          setState(() {
                            _hasUserSelectedStore = true;
                            _selectedStoreId = pickedId;
                          });
                        }
                      },
                      child: InputDecorator(
                        isEmpty: selectedStore == null,
                        decoration: InputDecoration(
                          labelText: loc.translate('select_store'),
                          prefixIcon:
                          const Icon(Icons.store_mall_directory_outlined),
                          suffixIcon: const Icon(Icons.search_rounded),
                          errorText: fieldState.errorText,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          selectedStore != null
                              ? _buildStoreLabel(
                            selectedStore,
                            position,
                            locationService,
                          )
                              : '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 28),

            // Pulsante Condividi Prezzo
            FilledButton.icon(
              onPressed:
              _isSaving ? null : () => _submitReport(sortedStores),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _isSaving
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
                  : const Icon(Icons.cloud_upload_rounded),
              label: Text(
                loc.translate('share_price'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // FASE 1: Schermata iniziale di acquisizione (Fotocamera / Galleria / Manuale)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                child: const Icon(Icons.document_scanner_rounded, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                loc.translate('scanner_title'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loc.translate('context_in_store_subtitle'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // 1. Scatta foto
        FilledButton.icon(
          onPressed: () => _pickAndAnalyzeImage(ImageSource.camera),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.camera_alt_rounded),
          label: Text(
            loc.translate('take_photo'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 12),

        // 2. Scegli da galleria
        FilledButton.tonalIcon(
          onPressed: () => _pickAndAnalyzeImage(ImageSource.gallery),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.photo_library_rounded),
          label: Text(
            loc.translate('choose_gallery'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),

        // 3. Inserisci a mano
        OutlinedButton.icon(
          onPressed: _startManualEntry,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.edit_note_rounded),
          label: Text(
            loc.translate('manual_entry'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}