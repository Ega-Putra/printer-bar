import 'package:barcode/barcode.dart' as bc;
import 'package:barcode_image/barcode_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:thermal_print/services/code128_decoder.dart';
import 'package:thermal_print/services/image_pipeline.dart';

/// Gambar barcode Code128 untuk [data], digambar pakai package:barcode
/// (implementasi encoder independen dari decoder yang dites).
img.Image _renderBarcode(String data, {int width = 640, int height = 120}) {
  final canvas = img.Image(width: width, height: height);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  drawBarcode(
    canvas,
    bc.Barcode.code128(),
    data,
    x: 20,
    y: 10,
    width: width - 40,
    height: height - 20,
  );
  return canvas;
}

void main() {
  group('Code128Decoder (roundtrip melawan encoder package:barcode)', () {
    test('resi Shopee 13 digit', () {
      final canvas = _renderBarcode('0046146045180');
      final box = Box(20, 10, canvas.width - 20.0, canvas.height - 10.0);
      expect(Code128Decoder.decode(canvas, box), '0046146045180');
    });

    test('digit genap (murni Code C)', () {
      final canvas = _renderBarcode('123456789012');
      final box = Box(20, 10, canvas.width - 20.0, canvas.height - 10.0);
      expect(Code128Decoder.decode(canvas, box), '123456789012');
    });

    test('alfanumerik (Code B)', () {
      final canvas = _renderBarcode('SHP123-XYZ');
      final box = Box(20, 10, canvas.width - 20.0, canvas.height - 10.0);
      expect(Code128Decoder.decode(canvas, box), 'SHP123-XYZ');
    });

    test('campuran digit ganjil + huruf', () {
      // String panjang -> render lebih lebar agar modul tidak terlalu padat.
      final canvas = _renderBarcode('JNT7723456789012AB', width: 1000);
      final box = Box(20, 10, canvas.width - 20.0, canvas.height - 10.0);
      expect(Code128Decoder.decode(canvas, box), 'JNT7723456789012AB');
    });

    test('box longgar (ada margin putih di sekitar)', () {
      final canvas = _renderBarcode('9876543210');
      // Box sengaja lebih besar dari barcode-nya.
      final box = Box(0, 0, canvas.width.toDouble(), canvas.height.toDouble());
      expect(Code128Decoder.decode(canvas, box), '9876543210');
    });

    test('box ketat (tanpa quiet zone)', () {
      final canvas = _renderBarcode('5551234');
      final box = Box(20, 10, canvas.width - 20.0, canvas.height - 10.0);
      expect(Code128Decoder.decode(canvas, box), '5551234');
    });
  });

  group('Code128Decoder (negatif)', () {
    test('gambar kosong -> null', () {
      final canvas = img.Image(width: 400, height: 100);
      img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
      final box = Box(0, 0, 400, 100);
      expect(Code128Decoder.decode(canvas, box), isNull);
    });

    test('coretan acak -> null (checksum gagal)', () {
      final canvas = img.Image(width: 400, height: 100);
      img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
      // Garis-garis vertikal acak yang bukan Code128 valid.
      for (var x = 10; x < 390; x += 7) {
        img.fillRect(canvas,
            x1: x,
            y1: 10,
            x2: x + (x % 3),
            y2: 90,
            color: img.ColorRgb8(0, 0, 0));
      }
      final box = Box(0, 0, 400, 100);
      expect(Code128Decoder.decode(canvas, box), isNull);
    });
  });
}
