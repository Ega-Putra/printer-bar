import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:thermal_print/services/free_text_controller.dart';
import 'package:thermal_print/services/free_text_document.dart';
import 'package:thermal_print/services/free_text_render.dart';

/// Kolom x paling kiri yang mengandung piksel gelap, atau -1 bila
/// gambar sepenuhnya putih.
int _minBlackX(img.Image image) {
  for (var x = 0; x < image.width; x++) {
    for (var y = 0; y < image.height; y++) {
      if (image.getPixel(x, y).r < 128) return x;
    }
  }
  return -1;
}

/// Apakah gambar mengandung piksel gelap sama sekali.
bool _hasBlack(img.Image image) => _minBlackX(image) >= 0;

void main() {
  group('StyledTextController', () {
    testWidgets('ketikan baru memakai gaya pending', (tester) async {
      final c = StyledTextController();
      addTearDown(c.dispose);
      c.text = 'hi';
      await tester.pump();
      // Kursor di akhir (posisi 2), gaya pending = gaya 'i' (polos).
      c.selection = const TextSelection.collapsed(offset: 2);
      c.toggleAttribute(FreeTextAttribute.bold);
      expect(c.pendingStyle.bold, isTrue);
      // Simulasi ketikan '!' di akhir.
      c.text = 'hi!';
      await tester.pump();
      expect(c.document.plainText, 'hi!');
      expect(c.document.segments.length, 2);
      expect(c.document.segments[1].text, '!');
      expect(c.document.segments[1].style.bold, isTrue);
    });

    testWidgets('toggle pada seleksi mengubah segmen', (tester) async {
      final c = StyledTextController();
      addTearDown(c.dispose);
      c.text = 'hello world';
      await tester.pump();
      c.selection = const TextSelection(baseOffset: 6, extentOffset: 11);
      c.toggleAttribute(FreeTextAttribute.italic);
      expect(c.isActive(FreeTextAttribute.italic), isTrue);
      expect(c.document.segments[1].text, 'world');
      expect(c.document.segments[1].style.italic, isTrue);
      // Teks polos tidak berubah karena toggle.
      expect(c.text, 'hello world');
    });

    testWidgets('clearDocument mengosongkan dokumen dan teks', (tester) async {
      final c = StyledTextController();
      addTearDown(c.dispose);
      c.text = 'abc';
      await tester.pump();
      c.clearDocument();
      expect(c.text, '');
      expect(c.document.isEmpty, isTrue);
    });
  });

  group('FreeTextRenderer', () {
    testWidgets('render lebar tepat + ada piksel hitam', (tester) async {
      final doc = StyledDocument.plain('Halo');
      final image = (await tester.runAsync(() => FreeTextRenderer.render(
            doc: doc,
            widthPx: 384,
            fontSize: 28,
            alignment: FreeTextAlign.left,
          )))!;
      expect(image.width, 384);
      expect(image.height, greaterThan(0));
      expect(_hasBlack(image), isTrue);
    });

    testWidgets('teks panjang membungkus jadi beberapa baris', (tester) async {
      const text =
          'Ini adalah kalimat yang cukup panjang sehingga harus membungkus '
          'ke beberapa baris pada lebar kertas 58mm.';
      final single = (await tester.runAsync(() => FreeTextRenderer.render(
            doc: StyledDocument.plain('Halo'),
            widthPx: 384,
            fontSize: 28,
            alignment: FreeTextAlign.left,
          )))!;
      final wrapped = (await tester.runAsync(() => FreeTextRenderer.render(
            doc: StyledDocument.plain(text),
            widthPx: 384,
            fontSize: 28,
            alignment: FreeTextAlign.left,
          )))!;
      expect(wrapped.height, greaterThan(single.height * 2));
    });

    testWidgets('rata tengah menggeser teks ke kanan vs rata kiri',
        (tester) async {
      const text = 'Hi';
      Future<img.Image> render(FreeTextAlign a) async =>
          (await tester.runAsync(() => FreeTextRenderer.render(
                doc: StyledDocument.plain(text),
                widthPx: 384,
                fontSize: 28,
                alignment: a,
              )))!;
      final left = await render(FreeTextAlign.left);
      final center = await render(FreeTextAlign.center);
      final right = await render(FreeTextAlign.right);
      final leftX = _minBlackX(left);
      final centerX = _minBlackX(center);
      final rightX = _minBlackX(right);
      expect(leftX, 0);
      expect(centerX, greaterThan(leftX));
      expect(rightX, greaterThan(centerX));
    });
  });
}
