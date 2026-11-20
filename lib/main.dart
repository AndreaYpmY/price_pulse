import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'UI/pages/main_layout.dart';
import 'UI/utility/app_localizations.dart';
import 'UI/utility/app_theme.dart';
import 'UI/utility/constants.dart';
import 'firebase_options.dart';
import 'model/providers/providers.dart';
import 'model/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Legge automaticamente la chiave da config/secrets.json (file locale escluso da Git)
  String geminiApiKey = const String.fromEnvironment('GEMINI_API_KEY');
  if (geminiApiKey.isEmpty) {
    try {
      final raw = await rootBundle.loadString('config/secrets.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      geminiApiKey = (data['GEMINI_API_KEY'] ?? '').toString().trim();
    } catch (_) {
      // Se il file non è presente (es. dopo git clone su un altro PC), non blocca l'avvio
    }
  }
  Gemini.init(apiKey: geminiApiKey);

  await NotificationService().init();

  runApp(const ProviderScope(child: PricePulseApp()));
}

class PricePulseApp extends ConsumerWidget {
  const PricePulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: Constants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: const [Locale('it'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const MainLayout(),
    );
  }
}
