import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:thermal_print/widgets/print_preview_image.dart';

/// Regression test untuk bug "loncat ke atas" (v1.1.2).
///
/// ROOT CAUSE (terbukti dari kode, bukan tebakan): setiap tap tombol di
/// kartu "Opsi Cetak" memanggil `_refreshPrintPreview()` yang meng-encode
/// PNG BARU (objek [Uint8List] baru) walau pikselnya mirip. `Image.memory`
/// tanpa `gaplessPlayback` membuang frame lama SEKETIKA dan melaporkan
/// tinggi NOL selama byte baru di-decode (async, 1-2 frame di HP).
/// Kartu pratinjau — yang berada DI ATAS tombol opsi — kolaps sesaat,
/// sehingga `ScrollPosition` meng-clamp offset scroll ke atas ("loncat"),
/// dan offset TIDAK kembali walau gambar sudah muncul lagi.
/// ScrollController persisten + PageStorageKey (v1.1.1) TIDAK menolong
/// karena offset memang di-clamp secara sah oleh penyusutan konten
/// sesaat itu — controller-nya tidak pernah di-recreate.
///
/// Test ini mengunci properti yang mencegah mekanisme di atas:
/// [Image.gaplessPlayback] harus true (frame lama tetap tampil sampai
/// frame baru siap → tidak ada kolaps → tidak ada clamp → tidak loncat).
///
/// Catatan: test perilaku scroll end-to-end tidak diskriminatif di
/// `flutter_test` (decode gambar di test env tidak meniru timing async
/// 1-2 frame di HP — diverifikasi empiris), sehingga properti inilah
/// yang dikunci secara deterministik.
Uint8List _makePng(int w, int h, int v) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(v, v, v));
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  testWidgets(
      'PrintPreviewImage memakai gaplessPlayback (anti loncat scroll)',
      (tester) async {
    final bytes = _makePng(384, 800, 200);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pola persis tab Cetak: pratinjau DI ATAS tombol opsi.
                PrintPreviewImage(bytes: bytes),
                const SizedBox(height: 2000),
                const Text('Opsi'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.gaplessPlayback, isTrue,
        reason: 'tanpa gaplessPlayback, tiap ganti byte pratinjau kolaps '
            'sesaat → scroll tab Cetak ter-clamp ke atas');
  });

  testWidgets('ganti byte tidak melempar error & widget tetap di tree',
      (tester) async {
    final bytesA = _makePng(384, 800, 200);
    final bytesB = _makePng(384, 800, 100);
    final bytes = ValueNotifier<Uint8List>(bytesA);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<Uint8List>(
          valueListenable: bytes,
          builder: (_, b, _) => PrintPreviewImage(bytes: b),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Simulasi _refreshPrintPreview: byte SELALU objek baru.
    bytes.value = bytesB;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(PrintPreviewImage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
