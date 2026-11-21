import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/objects/price_report.dart';
import '../../model/providers/providers.dart';
import '../utility/app_localizations.dart';
import '../utility/product_matcher.dart';
import 'home_page.dart';
import 'map_page.dart';
import 'scanner_page.dart';

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  int _currentIndex = 0; // Home 0; Scanner 1; Map 2
  String? _myDeviceId;
  Set<String>? _knownReportIds;

  @override
  void initState() {
    super.initState();
    _initDeviceId();
  }

  Future<void> _initDeviceId() async {
    final id = await ref.read(preferencesServiceProvider).getDeviceId();
    if (mounted) {
      setState(() => _myDeviceId = id);
    }
  }

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _handleNewCommunityReport(
      PriceReport newReport,
      List<PriceReport> allReports,
      ) async {
    final prefsService = ref.read(preferencesServiceProvider);
    final myId = _myDeviceId ?? await prefsService.getDeviceId();

    // 1. Ignora le segnalazioni caricate da questo stesso dispositivo
    if (newReport.reporterId.isNotEmpty && newReport.reporterId == myId) {
      return;
    }

    // 2. Verifica se il prodotto rientra tra quelli abituali dell'utente corrente
    final habitualCounts = ref.read(habitualProductsProvider);
    if (!prefsService.isHabitualInMap(newReport.productName, habitualCounts)) {
      return;
    }

    // 3. Confronta con l'ultima segnalazione precedente nello stesso supermercato
    final olderReports = allReports
        .where(
          (r) =>
      r.id != newReport.id &&
          r.createdAt.isBefore(newReport.createdAt),
    )
        .toList();

    final previousReport = ProductMatcher.findLatestReport(
      productName: newReport.productName,
      storeId: newReport.storeId,
      allReports: olderReports,
    );

    if (previousReport == null || newReport.price >= previousReport.price) {
      return;
    }

    if (!mounted) return;
    final loc = AppLocalizations.of(context)!;

    await ref.read(notificationServiceProvider).showPriceAlert(
      title: '${loc.translate('price_drop_alert')} ${newReport.productName}',
      body:
      '${newReport.storeName}: € ${previousReport.price.toStringAsFixed(2)} → € ${newReport.price.toStringAsFixed(2)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    // Ascolto in tempo reale i nuovi prezzi segnalati dalla community su Firestore
    ref.listen<AsyncValue<List<PriceReport>>>(priceReportsProvider, (_, next) {
      final reports = next.value;
      if (reports == null) return;

      // Al primo caricamento memorizzo gli ID esistenti senza inviare notifiche storiche
      if (_knownReportIds == null) {
        _knownReportIds = reports.map((r) => r.id).toSet();
        return;
      }

      final newReports = reports
          .where((r) => r.id.isNotEmpty && !_knownReportIds!.contains(r.id))
          .toList();

      _knownReportIds = reports.map((r) => r.id).toSet();

      for (final report in newReports) {
        _handleNewCommunityReport(report, reports);
      }
    });

    final pages = [
      HomePage(onNavigateToScanner: () => _selectTab(1)), // Se premo il pulsante va nella sezione scanner
      const ScannerPage(),
      const MapPage(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex, // evidenzia
        onDestinationSelected: _selectTab,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: loc.translate('nav_home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: const Icon(Icons.qr_code_scanner_rounded),
            label: loc.translate('nav_scanner'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map_rounded),
            label: loc.translate('nav_map'),
          ),
        ],
      ),
    );
  }
}