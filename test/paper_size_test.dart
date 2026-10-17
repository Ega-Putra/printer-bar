import 'package:flutter_test/flutter_test.dart';
import 'package:thermal_print/models/paper_size.dart';

void main() {
  test('lebar dots sesuai rumus mm -> dots @ 203dpi', () {
    // round(mm / 25.4 * 203 / 8) * 8
    expect(PaperSize.mm58.dots, 464);
    expect(PaperSize.mm80.dots, 640);
    expect(PaperSize.mm112.dots, 896);
  });

  test('semua lebar dots kelipatan 8 (syarat raster ESC/POS)', () {
    for (final p in PaperSize.values) {
      expect(p.dots % 8, 0, reason: '${p.label} dots=${p.dots}');
    }
  });
}
