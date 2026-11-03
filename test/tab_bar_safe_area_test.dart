import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermal_print/main.dart';

/// REGRESI: tab bar bawah tidak boleh tertutup area navigasi sistem Android
/// (gesture bar / tombol navigasi 3 tombol). Penyebab lama: TabBar mentah di
/// slot bottomNavigationBar tanpa SafeArea, sehingga label tab terpotong.
/// Perbaikan: SafeArea di dalam Material tab bar, memakai viewPadding sistem.
///
/// Test ini memalsukan viewPadding bawah 48px (setara nav bar 3 tombol)
/// dan memastikan batas bawah TabBar berakhir tepat di atas inset tersebut.
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

  testWidgets('tab bar duduk di atas inset navigasi sistem', (tester) async {
    // Surface default test: 800x600 logis. FakeViewPadding memakai piksel
    // FISIK, jadi kunci DPR=1.0 agar 48 fisik = 48 logis.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 600);
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    tester.view.padding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ThermalPrintApp());
    await tester.pumpAndSettle();

    final tabBarRect = tester.getRect(find.byType(TabBar));
    // Tanpa SafeArea, batas bawah TabBar = 600 (mentok layar, tertutup nav).
    // Dengan SafeArea, batas bawah = 600 - 48 = 552.
    expect(tabBarRect.bottom, closeTo(552.0, 1.0));
  });

  testWidgets('tanpa inset bawah, tab bar tetap mentok bawah layar', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 600);
    tester.view.viewPadding = const FakeViewPadding(bottom: 0);
    tester.view.padding = const FakeViewPadding(bottom: 0);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ThermalPrintApp());
    await tester.pumpAndSettle();

    final tabBarRect = tester.getRect(find.byType(TabBar));
    expect(tabBarRect.bottom, closeTo(600.0, 1.0));
  });
}
