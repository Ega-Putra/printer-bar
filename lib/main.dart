import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ThermalPrintApp());
}

class ThermalPrintApp extends StatelessWidget {
  /// [locale] hanya untuk test (mis. screenshot test memaksa 'id' agar
  /// golden tetap Bahasa Indonesia). Produksi: null = ikuti bahasa sistem.
  const ThermalPrintApp({super.key, this.locale});

  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Printer Bar',
      debugShowCheckedModeBanner: false,
      // TANPA locale hardcode di produksi: Flutter memilih dari
      // supportedLocales sesuai bahasa sistem. Urutan penting: 'en' PERTAMA
      // = fallback bila bahasa sistem tidak didukung (id kedua).
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('id'),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
