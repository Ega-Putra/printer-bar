import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:thermal_print/services/barcode_service.dart';
import 'package:thermal_print/services/image_pipeline.dart';

void main() {
  DetectedBarcode det(String? value, BarcodeFormat? format) =>
      DetectedBarcode(
          box: const Box(0, 0, 10, 10),
          rawValue: value,
          format: format);

  group('regenerateBarcode', () {
    test('code128 13 digit -> 384px penuh, tidak kosong', () {
      final out = BarcodeService.regenerateBarcode(
        det: det('0046146045180', BarcodeFormat.code128),
        widthPx: 384,
        barHeightPx: 200,
      );
      expect(out, isNotNull);
      expect(out!.width, 384);
      expect(out.height, greaterThan(200)); // bilah + teks nilai
      var black = 0;
      for (var y = 0; y < out.height; y++) {
        for (var x = 0; x < out.width; x++) {
          if (out.getPixel(x, y).r == 0) black++;
        }
      }
      expect(black, greaterThan(1000));
      // Roundtrip: detektor heuristik menemukan area barcode-nya.
      final region = ImagePipeline.findBarcodeRegion(out);
      expect(region, isNotNull);
      expect(region!.width, greaterThan(300));
      // Quiet zone: 16px terluar kiri-kanan di area bilah harus putih.
      for (var y = 0; y < 200; y++) {
        for (var x = 0; x < 16; x++) {
          expect(out.getPixel(x, y).r, 255,
              reason: 'quiet zone kiri ($x,$y)');
          expect(out.getPixel(383 - x, y).r, 255,
              reason: 'quiet zone kanan (${383 - x},$y)');
        }
      }
    });

    test('tanpa nilai decode -> null (fallback crop)', () {
      expect(
        BarcodeService.regenerateBarcode(
          det: det(null, BarcodeFormat.code128),
          widthPx: 384,
          barHeightPx: 200,
        ),
        isNull,
      );
    });

    test('format QR -> null (fallback crop)', () {
      expect(
        BarcodeService.regenerateBarcode(
          det: det('https://example.com', BarcodeFormat.qrCode),
          widthPx: 384,
          barHeightPx: 200,
        ),
        isNull,
      );
    });

    test('EAN-13 data tidak valid -> null', () {
      expect(
        BarcodeService.regenerateBarcode(
          det: det('123', BarcodeFormat.ean13),
          widthPx: 384,
          barHeightPx: 200,
        ),
        isNull,
      );
    });

    test('EAN-13 valid -> tidak null', () {
      final out = BarcodeService.regenerateBarcode(
        det: det('5901234123457', BarcodeFormat.ean13),
        widthPx: 384,
        barHeightPx: 200,
      );
      expect(out, isNotNull);
      expect(out!.width, 384);
    });
  });
}
