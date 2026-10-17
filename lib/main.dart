import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const ThermalPrintApp());
}

class ThermalPrintApp extends StatelessWidget {
  const ThermalPrintApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Printer Bar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
