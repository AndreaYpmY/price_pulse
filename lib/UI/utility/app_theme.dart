import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Colori principali PricePulse
  static const Color _primaryGreen = Color(0xFF1B8A5A);
  static const Color _darkPrimaryGreen = Color(0xFF4ADE80);

  // Colori riutilizzabili nelle card per indicare calo o rincaro prezzo
  static const Color priceDropColor = Color(0xFF16A34A); // Verde sconto
  static const Color priceRiseColor = Color(0xFFDC2626); // Rosso aumento

  // 1. TEMA CHIARO (Light Mode)
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // Genero automaticamente una palette partendo dal verde principale
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryGreen,
      brightness: Brightness.light,
      primary: _primaryGreen,
      surface: const Color(0xFFF6F8F7),
    ),

    scaffoldBackgroundColor: const Color(0xFFF6F8F7),

    // Stile AppBar
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: Color(0xFFF6F8F7),
      foregroundColor: Color(0xFF111827),
    ),

    // Stile barra di navigazione inferiore (Home, Scanner, Mappa)
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: _primaryGreen.withValues(alpha: 0.15),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),

    // Stile predefinito  campi di testo (barra di ricerca e form dello scanner)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primaryGreen, width: 2),
      ),
    ),

    // Stile pulsanti principali (es. "Scatta foto", "Condividi prezzo")
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
  );

  // ---------------------------------------------------------------------------

  // 2. TEMA SCURO (Dark Mode)
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryGreen,
      brightness: Brightness.dark,
      primary: _darkPrimaryGreen,
      surface: const Color(0xFF121614), // Sfondo scuro
    ),

    scaffoldBackgroundColor: const Color(0xFF121614),

    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: Color(0xFF121614),
      foregroundColor: Color(0xFFF3F4F6),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF1B221E),
      indicatorColor: _darkPrimaryGreen.withValues(alpha: 0.20),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1B221E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2D3832)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2D3832)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _darkPrimaryGreen, width: 2),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _darkPrimaryGreen,
        foregroundColor: const Color(0xFF062818),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
  );
}