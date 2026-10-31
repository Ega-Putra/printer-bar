import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermal_print/main.dart';

/// CAPTURE-ONLY test: menghasilkan screenshot PNG asli aplikasi untuk
/// listing Play Store (tidak ada emulator/HP di box ini).
///
/// Jalankan: flutter test --update-goldens test/screenshot_capture_test.dart
/// Hasil: test/goldens/screenshot_cetak.png & screenshot_pengaturan.png
/// (1080x2160 — surface logis 360x720 @ DPR 3.0).
///
/// Channel platform yang disentuh HomeScreen saat initState dimock agar
/// tidak melempar MissingPluginException:
/// - receive_sharing_intent: getInitialMedia + stream share masuk.
/// - ML Kit barcode: close() saat dispose.
/// Muat font asli (Roboto + MaterialIcons) dari cache SDK Flutter.
/// Tanpa ini, teks di test widget dirender sebagai kotak (font Ahem)
/// dan ikon jadi placeholder — tidak layak untuk screenshot listing.
Future<void> loadRealFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/home/hatch/flutter';
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> fontData(String name) async {
    final bytes = await File('$dir/$name').readAsBytes();
    return ByteData.view(bytes.buffer);
  }

  final roboto = FontLoader('Roboto')
    ..addFont(fontData('Roboto-Regular.ttf'))
    ..addFont(fontData('Roboto-Medium.ttf'))
    ..addFont(fontData('Roboto-Bold.ttf'));
  await roboto.load();

  final icons = FontLoader('MaterialIcons')
    ..addFont(fontData('MaterialIcons-Regular.otf'));
  await icons.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockChannel(String name) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      MethodChannel(name),
      (MethodCall call) async => null,
    );
  }

  setUpAll(() async {
    // Di setUpAll (zona async asli) agar baca file font tidak deadlock
    // di FakeAsync-nya testWidgets.
    await loadRealFonts();
  });

  setUp(() {
    mockChannel('receive_sharing_intent/messages');
    mockChannel('receive_sharing_intent/events-media');
    mockChannel('google_mlkit_barcode_scanning');
  });

  testWidgets('capture play store screenshots', (tester) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // Paksa locale 'id' agar golden tetap Bahasa Indonesia
    // (produksi: locale null = ikuti bahasa sistem).
    await tester.pumpWidget(
      const ThermalPrintApp(locale: Locale('id')),
    );
    await tester.pumpAndSettle();

    // (a) Tab "Cetak" — keadaan awal (belum ada PDF).
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/screenshot_cetak.png'),
    );

    // (b) Tab "Pengaturan".
    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/screenshot_pengaturan.png'),
    );
  });
}
