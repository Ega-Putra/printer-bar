import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermal_print/main.dart';

/// Verifikasi resolusi bahasa:
/// - locale 'id' -> UI Bahasa Indonesia
/// - locale 'en' -> UI Bahasa Inggris
/// - locale tak didukung ('fr') -> fallback ke 'en' (bahasa PERTAMA di
///   supportedLocales). Di produksi locale = null sehingga Flutter memakai
///   bahasa sistem dengan aturan fallback yang sama.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockChannel(String name) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      MethodChannel(name),
      (MethodCall call) async => null,
    );
  }

  setUp(() {
    mockChannel('receive_sharing_intent/messages');
    mockChannel('receive_sharing_intent/events-media');
    mockChannel('google_mlkit_barcode_scanning');
  });

  Future<void> pumpApp(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(ThermalPrintApp(locale: locale));
    await tester.pumpAndSettle();
  }

  testWidgets('locale id menampilkan UI Bahasa Indonesia', (tester) async {
    await pumpApp(tester, const Locale('id'));
    expect(find.text('Pengaturan'), findsOneWidget);
    expect(find.text('Pilih PDF'), findsOneWidget);
  });

  testWidgets('locale en menampilkan UI Bahasa Inggris', (tester) async {
    await pumpApp(tester, const Locale('en'));
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Pick PDF'), findsOneWidget);
  });

  testWidgets('locale tak didukung fallback ke Bahasa Inggris', (tester) async {
    await pumpApp(tester, const Locale('fr'));
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Pick PDF'), findsOneWidget);
  });
}
