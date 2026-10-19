import 'package:flutter_test/flutter_test.dart';
import 'package:thermal_print/models/paper_size.dart';

void main() {
  test('lebar dots = PRINTABLE width head printer @203dpi (BUKAN lebar kertas)',
      () {
    // Regresi v1.8: mengirim raster selebar KERTAS (464/640/896) membuat
    // hasil cetak fisik bergeser/duplikat ke kanan — head printer selalu
    // lebih sempit dari kertasnya.
    expect(PaperSize.mm58.dots, 384); // 48 byte/baris
    expect(PaperSize.mm80.dots, 576); // 72 byte/baris
    expect(PaperSize.mm112.dots, 832); // 104 byte/baris
  });

  test('semua lebar dots kelipatan 8 (syarat raster ESC/POS)', () {
    for (final p in PaperSize.values) {
      expect(p.dots % 8, 0, reason: '${p.label} dots=${p.dots}');
    }
  });

  test('printable width selalu lebih sempit dari lebar kertas', () {
    for (final p in PaperSize.values) {
      final paperDots = (p.mm / 25.4 * 203).round();
      expect(p.dots, lessThan(paperDots),
          reason: '${p.label}: printable ${p.dots} vs kertas $paperDots');
    }
  });
}
