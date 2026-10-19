import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:thermal_print/services/image_pipeline.dart';

/// Gambar uji 8x8: 4 kolom kiri hitam, 4 kolom kanan putih.
img.Image testStripe() {
  final im = img.Image(width: 8, height: 8);
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      im.setPixel(
        x,
        y,
        x < 4 ? img.ColorRgb8(0, 0, 0) : img.ColorRgb8(255, 255, 255),
      );
    }
  }
  return im;
}

void main() {
  test('toRasterBytes: pola stripe 8x8 -> 0xF0 per baris', () {
    final bytes = ImagePipeline.toRasterBytes(testStripe());
    expect(bytes.length, 8);
    expect(bytes, Uint8List.fromList(List.filled(8, 0xF0)));
  });

  test('toRasterBytes: gambar putih penuh -> semua nol', () {
    final white = img.Image(width: 16, height: 4);
    img.fill(white, color: img.ColorRgb8(255, 255, 255));
    final bytes = ImagePipeline.toRasterBytes(white);
    expect(bytes, Uint8List(8)); // 16/8 * 4 = 8 byte nol
  });

  test('paddedCrop: padding proporsional dari ukuran box', () {
    const box = Box(10, 10, 50, 50); // 40x40
    final padded =
        ImagePipeline.paddedCrop(box, 100, 100, padFraction: 0.1);
    expect(padded.left, 6.0);
    expect(padded.top, 6.0);
    expect(padded.right, 54.0);
    expect(padded.bottom, 54.0);
  });

  test('paddedCrop: dijepit ke dalam gambar', () {
    const box = Box(0, 0, 20, 20);
    final padded =
        ImagePipeline.paddedCrop(box, 100, 100, padFraction: 0.5);
    expect(padded.left, 0.0);
    expect(padded.top, 0.0);
    expect(padded.right, 30.0);
    expect(padded.bottom, 30.0);
  });

  test('cropAndScaleToWidth: crop lalu skala pertahankan aspek', () {
    final src = img.Image(width: 100, height: 100);
    final out =
        ImagePipeline.cropAndScaleToWidth(src, const Box(10, 10, 50, 50), 80);
    expect(out.width, 80);
    expect(out.height, 80); // crop 40x40 -> skala 2x
  });

  test('composeVertical: tinggi = jumlah tinggi + gap', () {
    final a = img.Image(width: 16, height: 10);
    final b = img.Image(width: 16, height: 20);
    final c = ImagePipeline.composeVertical([a, b], gap: 4);
    expect(c.width, 16);
    expect(c.height, 34);
  });

  test('scaleToWidth: aspek rasio dipertahankan', () {
    final src = img.Image(width: 100, height: 200);
    final out = ImagePipeline.scaleToWidth(src, 50);
    expect(out.width, 50);
    expect(out.height, 100);
  });

  test('crop: dimensi sesuai box', () {
    final src = img.Image(width: 100, height: 80);
    final out = ImagePipeline.crop(src, const Box(10, 10, 50, 40));
    expect(out.width, 40);
    expect(out.height, 30);
  });

  test('translateBox: box di dalam crop -> koordinat tergeser', () {
    const det = Box(100, 100, 200, 140);
    const crop = Box(50, 50, 300, 300);
    final t = ImagePipeline.translateBox(det, crop)!;
    expect(t.left, 50.0);
    expect(t.top, 50.0);
    expect(t.right, 150.0);
    expect(t.bottom, 90.0);
  });

  test('translateBox: box di luar crop -> null', () {
    const det = Box(10, 10, 40, 40);
    const crop = Box(100, 100, 300, 300);
    expect(ImagePipeline.translateBox(det, crop), isNull);
  });

  test('translateBox: box terpotong crop -> dijepit', () {
    const det = Box(80, 80, 200, 200);
    const crop = Box(100, 100, 300, 300);
    final t = ImagePipeline.translateBox(det, crop)!;
    expect(t.left, 0.0);
    expect(t.top, 0.0);
    expect(t.right, 100.0);
    expect(t.bottom, 100.0);
  });

  test('padToWidth: gambar di tengah kanvas putih', () {
    final src = img.Image(width: 4, height: 2);
    img.fill(src, color: img.ColorRgb8(0, 0, 0));
    final out = ImagePipeline.padToWidth(src, 8);
    expect(out.width, 8);
    expect(out.height, 2);
    // pinggir kiri putih, tengah hitam
    expect(out.getPixel(0, 0).r, 255);
    expect(out.getPixel(2, 0).r, 0);
    expect(out.getPixel(5, 1).r, 0);
    expect(out.getPixel(7, 1).r, 255);
  });

  test('padToWidth: gambar lebih lebar dari target dikecilkan (invariant)', () {
    // Regresi: barcode vertikal dengan slider tinggi maksimal bisa lebih
    // lebar dari target — tanpa ini, stride raster vs header ESC/POS
    // tidak cocok dan hasil cetak artefak.
    final src = img.Image(width: 16, height: 4);
    img.fill(src, color: img.ColorRgb8(0, 0, 0));
    final out = ImagePipeline.padToWidth(src, 8);
    expect(out.width, 8);
    // aspek rasio dipertahankan: 16x4 -> 8x2
    expect(out.height, 2);
  });

  test('rotate90Clockwise: 2x2 diputar searah jarum jam', () {
    // lama: [R G]
    //       [B W]
    // baru: [B R]
    //       [W G]
    final src = img.Image(width: 2, height: 2);
    src.setPixel(0, 0, img.ColorRgb8(255, 0, 0));
    src.setPixel(1, 0, img.ColorRgb8(0, 255, 0));
    src.setPixel(0, 1, img.ColorRgb8(0, 0, 255));
    src.setPixel(1, 1, img.ColorRgb8(255, 255, 255));
    final out = ImagePipeline.rotate90Clockwise(src);
    expect(out.width, 2);
    expect(out.height, 2);
    // (0,0) biru
    expect(out.getPixel(0, 0).b, 255);
    expect(out.getPixel(0, 0).r, 0);
    // (1,0) merah
    expect(out.getPixel(1, 0).r, 255);
    // (0,1) putih
    expect(out.getPixel(0, 1).r, 255);
    expect(out.getPixel(0, 1).g, 255);
    expect(out.getPixel(0, 1).b, 255);
    // (1,1) hijau
    expect(out.getPixel(1, 1).g, 255);
    expect(out.getPixel(1, 1).r, 0);
  });

  group('findBarcodeRegion', () {
    /// Barcode sintetis ala Code128: x 100..300, y 200..350,
    /// bilah vertikal selebar 2-5 px selang-seling.
    img.Image syntheticBarcode() {
      final im = img.Image(width: 768, height: 1000);
      img.fill(im, color: img.ColorRgb8(255, 255, 255));
      var x = 100;
      var black = true;
      var seed = 7;
      while (x < 300) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        final wBar = 2 + (seed % 4); // 2..5 px
        for (var dx = 0; dx < wBar && x + dx < 300; dx++) {
          for (var y = 200; y < 350; y++) {
            im.setPixel(
              x + dx,
              y,
              black
                  ? img.ColorRgb8(0, 0, 0)
                  : img.ColorRgb8(255, 255, 255),
            );
          }
        }
        x += wBar;
        black = !black;
      }
      return im;
    }

    test('barcode sintetis terdeteksi di area yang benar', () {
      final box = ImagePipeline.findBarcodeRegion(syntheticBarcode());
      expect(box, isNotNull);
      // Toleransi: padding 6px + sampling baris.
      expect(box!.left, inInclusiveRange(85.0, 105.0));
      expect(box.top, inInclusiveRange(185.0, 205.0));
      expect(box.right, inInclusiveRange(295.0, 315.0));
      expect(box.bottom, inInclusiveRange(345.0, 365.0));
    });

    test('gambar putih polos -> null', () {
      final white = img.Image(width: 768, height: 1000);
      img.fill(white, color: img.ColorRgb8(255, 255, 255));
      expect(ImagePipeline.findBarcodeRegion(white), isNull);
    });

    test('garis-garis teks horizontal -> null (bukan barcode)', () {
      final im = img.Image(width: 768, height: 1000);
      img.fill(im, color: img.ColorRgb8(255, 255, 255));
      // Simulasi baris teks: balok hitam 600px x 12px tiap 40px.
      for (var y = 100; y < 900; y += 40) {
        for (var x = 80; x < 680; x++) {
          for (var dy = 0; dy < 12; dy++) {
            im.setPixel(x, y + dy, img.ColorRgb8(0, 0, 0));
          }
        }
      }
      expect(ImagePipeline.findBarcodeRegion(im), isNull);
    });

    test('barcode + teks: tetap barcode yang terpilih', () {
      final im = syntheticBarcode();
      for (var y = 500; y < 900; y += 40) {
        for (var x = 80; x < 680; x++) {
          for (var dy = 0; dy < 12; dy++) {
            im.setPixel(x, y + dy, img.ColorRgb8(0, 0, 0));
          }
        }
      }
      final box = ImagePipeline.findBarcodeRegion(im);
      expect(box, isNotNull);
      expect(box!.top, lessThan(400.0));
    });
  });

  group('dithering & rasterToImage', () {
    test('toRasterBytesDithered: gradasi -> ada hitam & putih', () {
      // Gradasi horizontal 64px: kiri hitam -> kanan putih.
      final im = img.Image(width: 64, height: 16);
      for (var y = 0; y < 16; y++) {
        for (var x = 0; x < 64; x++) {
          final v = (x * 255 ~/ 63);
          im.setPixel(x, y, img.ColorRgb8(v, v, v));
        }
      }
      final raster = ImagePipeline.toRasterBytesDithered(im);
      expect(raster.length, 64 ~/ 8 * 16);
      final blackBytes =
          raster.where((b) => b != 0).length;
      final whiteBytes =
          raster.where((b) => b == 0).length;
      expect(blackBytes, greaterThan(0));
      expect(whiteBytes, greaterThan(0));
      // Kiri harus jauh lebih hitam daripada kanan.
      var leftBlack = 0;
      var rightBlack = 0;
      for (var y = 0; y < 16; y++) {
        for (var x = 0; x < 16; x++) {
          if ((raster[y * 8 + (x ~/ 8)] >> (7 - (x % 8)) & 1) == 1) {
            leftBlack++;
          }
        }
        for (var x = 48; x < 64; x++) {
          if ((raster[y * 8 + (x ~/ 8)] >> (7 - (x % 8)) & 1) == 1) {
            rightBlack++;
          }
        }
      }
      expect(leftBlack, greaterThan(rightBlack * 4));
    });

    test('toRasterBytesDithered: hitam-putih murni tidak berubah', () {
      final bytes = ImagePipeline.toRasterBytesDithered(testStripe());
      expect(bytes, Uint8List.fromList(List.filled(8, 0xF0)));
    });

    test('rasterToImage: roundtrip stripe 8x8', () {
      final raster = ImagePipeline.toRasterBytes(testStripe());
      final back = ImagePipeline.rasterToImage(raster, 8);
      expect(back.width, 8);
      expect(back.height, 8);
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 8; x++) {
          final expectedBlack = x < 4;
          expect(back.getPixel(x, y).r == 0, expectedBlack,
              reason: 'piksel ($x,$y)');
        }
      }
    });
  });
}
