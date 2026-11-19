import 'package:flutter/material.dart';
import '../utility/app_localizations.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('scanner_title'))),
      body: const Center(child: Text('Scanner AI - PROVVISORIO')),
    );
  }
}