import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:thermal_print/services/image_pipeline.dart';
import 'package:thermal_print/widgets/crop_overlay.dart';

/// Test fitur v1.1.0: rotate, hit-test crop, dan jalur input gambar.

void main() {
  group('rotate90Clockwise', () {
    // Gambar uji 4x2 dengan pola unik per piksel.
    img.Image testPattern() {
      final im = img.Image(width: 4, height: 2);
      var v = 0;
      for (var y = 0; y < 2; y++) {
        for (var x = 0; x < 4; x++) {
          im.setPixel(x, y, img.ColorRgb8(v, v, v));
          v += 10;
        }
      }
      return im;
    }

    bool samePixels(img.Image a, img.Image b) {
      if (a.width != b.width || a.height != b.height) return false;
      for (var y = 0; y < a.height; y++) {
        for (var x = 0; x < a.width; x++) {
          if (a.getPixel(x, y).r != b.getPixel(x, y).r) return false;
        }
      }
      return true;
    }

    test('memutar dimensi: 4x2 menjadi 2x4', () {
      final r = ImagePipeline.rotate90Clockwise(testPattern());
      expect(r.width, 2);
      expect(r.height, 4);
    });

    test('4x putaran kembali ke gambar semula (pixel-exact)', () {
      var im = testPattern();
      final orig = testPattern();
      for (var i = 0; i < 4; i++) {
        im = ImagePipeline.rotate90Clockwise(im);
      }
      expect(samePixels(im, orig), isTrue);
    });

    test('1x putaran 90 CW memetakan piksel dengan benar', () {
      // Piksel (0,0) setelah rotate 90 CW ada di (h-1, 0) = (1, 0).
      final im = testPattern();
      final r = ImagePipeline.rotate90Clockwise(im);
      expect(r.getPixel(1, 0).r, im.getPixel(0, 0).r);
      // Piksel (3,1) -> (0, 3).
      expect(r.getPixel(0, 3).r, im.getPixel(3, 1).r);
    });

    test('lebar hasil rotate kelipatan 8 tetap kelipatan 8', () {
      // Simulasi halaman 384x600 diputar → 600x384 (tetap kelipatan 8).
      final im = img.Image(width: 384, height: 600);
      final r = ImagePipeline.rotate90Clockwise(im);
      expect(r.width % 8, 0);
      expect(r.height, 384);
    });
  });

  group('hitTestCrop', () {
    // Kotak 100..200 di kedua sumbu (koordinat layar).
    List<Offset> corners() => const [
          Offset(100, 100), // TL
          Offset(200, 100), // TR
          Offset(200, 200), // BR
          Offset(100, 200), // BL
        ];
    const hitR = 28.0;

    test('tap di sudut → corner yang benar', () {
      expect(hitTestCrop(const Offset(102, 98), corners(), hitR),
          CropHit.cornerTL);
      expect(hitTestCrop(const Offset(199, 201), corners(), hitR),
          CropHit.cornerBR);
    });

    test('tap di tengah sisi → edge yang benar', () {
      expect(hitTestCrop(const Offset(150, 100), corners(), hitR),
          CropHit.edgeTop);
      expect(hitTestCrop(const Offset(200, 150), corners(), hitR),
          CropHit.edgeRight);
      expect(hitTestCrop(const Offset(150, 200), corners(), hitR),
          CropHit.edgeBottom);
      expect(hitTestCrop(const Offset(100, 150), corners(), hitR),
          CropHit.edgeLeft);
    });

    test('tap di dalam kotak (jauh dari handle) → move', () {
      expect(hitTestCrop(const Offset(150, 150), corners(), hitR),
          CropHit.move);
    });

    test('tap di area kosong → none (TIDAK boleh draw/move)', () {
      expect(hitTestCrop(const Offset(10, 10), corners(), hitR),
          CropHit.none);
      expect(hitTestCrop(const Offset(300, 150), corners(), hitR),
          CropHit.none);
      expect(hitTestCrop(const Offset(150, 300), corners(), hitR),
          CropHit.none);
    });

    test('prioritas: sudut menang atas sisi yang berdekatan', () {
      // Titik di dekat sudut TL sekaligus dekat sisi atas/kiri.
      expect(hitTestCrop(const Offset(105, 105), corners(), hitR),
          CropHit.cornerTL);
    });
  });

  group('jalur input gambar', () {
    test('decode PNG hasil encode → dimensi utuh', () {
      final im = img.Image(width: 320, height: 200);
      img.fill(im, color: img.ColorRgb8(255, 255, 255));
      final png = Uint8List.fromList(img.encodePng(im));
      final back = ImagePipeline.decode(png);
      expect(back.width, 320);
      expect(back.height, 200);
    });

    test('decode byte acak melempar FormatException', () {
      expect(
        () => ImagePipeline.decode(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(isA<FormatException>()),
      );
    });

    test('gambar di-crop lalu diskala ke lebar cetak (alur halaman tunggal)',
        () {
      final im = img.Image(width: 800, height: 600);
      img.fill(im, color: img.ColorRgb8(255, 255, 255));
      final cropped = ImagePipeline.crop(im, const Box(0, 0, 800, 600));
      final scaled = ImagePipeline.scaleToWidth(cropped, 384);
      expect(scaled.width, 384);
      expect(scaled.width % 8, 0);
    });
  });
}
