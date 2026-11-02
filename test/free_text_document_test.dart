import 'package:flutter_test/flutter_test.dart';
import 'package:thermal_print/services/free_text_document.dart';

void main() {
  group('StyledDocument', () {
    test('toggle pada rentang akhir membelah segmen jadi 2', () {
      final doc = StyledDocument.plain('hello world');
      final out = doc.toggleRange(6, 11, FreeTextAttribute.bold);
      expect(out.plainText, 'hello world');
      expect(out.segments.length, 2);
      expect(out.segments[0].text, 'hello ');
      expect(out.segments[0].style.bold, isFalse);
      expect(out.segments[1].text, 'world');
      expect(out.segments[1].style.bold, isTrue);
      // Segmen kosong tidak pernah dipertahankan:
      expect(out.segments.where((s) => s.text.isEmpty), isEmpty);
    });

    test('toggle pada rentang tengah membelah segmen jadi 3', () {
      final doc = StyledDocument.plain('hello world');
      final out = doc.toggleRange(3, 8, FreeTextAttribute.underline);
      expect(out.plainText, 'hello world');
      expect(out.segments.length, 3);
      expect(out.segments[0].text, 'hel');
      expect(out.segments[1].text, 'lo wo');
      expect(out.segments[1].style.underline, isTrue);
      expect(out.segments[2].text, 'rld');
      expect(out.segments[2].style.underline, isFalse);
    });

    test('toggle kedua kali menghapus atribut', () {
      final doc = StyledDocument.plain('hello world')
          .toggleRange(0, 5, FreeTextAttribute.italic);
      final out = doc.toggleRange(0, 5, FreeTextAttribute.italic);
      expect(out.segments.length, 1);
      expect(out.segments.single.style.italic, isFalse);
    });

    test('toggle pada rentang campuran menetapkan ke semua', () {
      // 'ab' tebal, 'cd' polos → toggle bold pada 0..4 → semua tebal.
      final doc = StyledDocument([
        const StyledSegment('ab', FreeTextStyle(bold: true)),
        const StyledSegment('cd'),
      ]);
      final out = doc.toggleRange(0, 4, FreeTextAttribute.bold);
      expect(out.segments.length, 1);
      expect(out.segments.single.text, 'abcd');
      expect(out.segments.single.style.bold, isTrue);
    });

    test('toggle pada rentang penuh menghapus dari semua', () {
      final doc = StyledDocument([
        const StyledSegment('ab', FreeTextStyle(bold: true)),
        const StyledSegment('cd', FreeTextStyle(bold: true)),
      ]);
      final out = doc.toggleRange(0, 4, FreeTextAttribute.bold);
      expect(out.segments.length, 1);
      expect(out.segments.single.style.bold, isFalse);
    });

    test('toggle rentang kosong tidak mengubah dokumen', () {
      final doc = StyledDocument.plain('abc');
      expect(identical(doc.toggleRange(1, 1, FreeTextAttribute.bold), doc),
          isTrue);
    });

    test('replaceRange menyisip, menghapus, dan menggabung', () {
      // 'hello world' → hapus 'o w' (4..7), sisip 'X' tebal.
      final doc = StyledDocument.plain('hello world').replaceRange(
          4, 7, 'X', const FreeTextStyle(bold: true));
      expect(doc.plainText, 'hellXorld');
      expect(doc.segments.length, 3);
      expect(doc.segments[1].text, 'X');
      expect(doc.segments[1].style.bold, isTrue);
      // Sisipan bergaya sama dengan tetangga langsung bergabung.
      final merged = doc.replaceRange(5, 5, 'Y', const FreeTextStyle());
      expect(merged.plainText, 'hellXYorld');
      expect(merged.segments.length, 3);
      expect(merged.segments[2].text, 'Yorld');
    });

    test('replaceRange di luar batas dijepit', () {
      final doc = StyledDocument.plain('abc')
          .replaceRange(-5, 99, 'Z', const FreeTextStyle());
      expect(doc.plainText, 'Z');
    });

    test('styleAt dan allHave', () {
      final doc = StyledDocument([
        const StyledSegment('ab', FreeTextStyle(italic: true)),
        const StyledSegment('cd'),
      ]);
      expect(doc.styleAt(0).italic, isTrue);
      expect(doc.styleAt(3).italic, isFalse);
      expect(doc.allHave(0, 2, FreeTextAttribute.italic), isTrue);
      expect(doc.allHave(0, 4, FreeTextAttribute.italic), isFalse);
      expect(doc.allHave(2, 2, FreeTextAttribute.italic), isFalse);
    });

    test('dokumen kosong aman', () {
      final doc = StyledDocument.empty();
      expect(doc.isEmpty, isTrue);
      expect(doc.styleAt(0), const FreeTextStyle());
      expect(doc.toggleRange(0, 0, FreeTextAttribute.bold), doc);
    });
  });
}
