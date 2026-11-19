import 'package:flutter/material.dart';
import '../utility/app_localizations.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('map_title'))),
      body: const Center(child: Text('Mappa del Risparmio - PROVVISORIO')),
    );
  }
}