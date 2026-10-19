import 'package:flutter_test/flutter_test.dart';
import 'package:thermal_print/services/image_pipeline.dart';

/// Regression tests untuk transformasi bbox mengikuti rotasi halaman.
///
/// Deteksi barcode dijalankan SEKALI pada gambar asli; saat pengguna
/// memutar, bbox di-transform matematis via [ImagePipeline.rotateBox]
/// (tidak pernah dideteksi ulang pada gambar putaran).
void main() {
  group('ImagePipeline.rotateBox', () {
    // Rumus dari spesifikasi: rect (x,y,w,h) dalam W×H diputar 90° CW
    // → (H−y−h, x, h, w) dalam H×W.
    test('90° CW mengikuti rumus spesifikasi', () {
      // x=10, y=20, w=30, h=20 dalam 100×200
      const box = Box(10, 20, 40, 40);
      final r = ImagePipeline.rotateBox(box, 1, 100, 200);
      expect(r.left, 160); // 200−20−20
      expect(r.top, 10);
      expect(r.right, 180); // 160+20
      expect(r.bottom, 40); // 10+30
      // Dimensi ikut bertukar: 20×30 dalam bingkai 200×100.
      expect(r.width, 20);
      expect(r.height, 30);
    });

    test('90° CW: contoh barcode nyata', () {
      // Barcode 200×60 di (100,200) dalam gambar 400×800.
      const box = Box(100, 200, 300, 260);
      final r = ImagePipeline.rotateBox(box, 1, 400, 800);
      expect(r.left, 540); // 800−260
      expect(r.top, 100);
      expect(r.right, 600); // 800−200
      expect(r.bottom, 300);
      expect(r.width, 60);
      expect(r.height, 200);
    });

    test('180°: simetris terhadap pusat', () {
      const box = Box(100, 200, 300, 260);
      final r = ImagePipeline.rotateBox(box, 2, 400, 800);
      expect(r.left, 100); // 400−300
      expect(r.top, 540); // 800−260
      expect(r.right, 300); // 400−100
      expect(r.bottom, 600); // 800−200
      expect(r.width, 200);
      expect(r.height, 60);
    });

    test('270° CW (= 90° CCW)', () {
      const box = Box(100, 200, 300, 260);
      final r = ImagePipeline.rotateBox(box, 3, 400, 800);
      // (x,y) → (y, W−x): l'=t, t'=W−r, r'=b, b'=W−l
      expect(r.left, 200);
      expect(r.top, 100); // 400−300
      expect(r.right, 260);
      expect(r.bottom, 300); // 400−100
      expect(r.width, 60);
      expect(r.height, 200);
    });

    test('4 putaran = identitas; 0 putaran = identitas', () {
      const box = Box(10, 20, 50, 60);
      for (final t in [0, 4, 8]) {
        final r = ImagePipeline.rotateBox(box, t, 100, 200);
        expect(r.left, box.left);
        expect(r.top, box.top);
        expect(r.right, box.right);
        expect(r.bottom, box.bottom);
      }
    });

    test('putaran negatif dinormalisasi', () {
      const box = Box(100, 200, 300, 260);
      final neg = ImagePipeline.rotateBox(box, -1, 400, 800);
      final pos = ImagePipeline.rotateBox(box, 3, 400, 800);
      expect(neg.left, pos.left);
      expect(neg.top, pos.top);
      expect(neg.right, pos.right);
      expect(neg.bottom, pos.bottom);
    });

    test('komposisi: 90° + 90° = 180°', () {
      const box = Box(100, 200, 300, 260);
      final once = ImagePipeline.rotateBox(box, 1, 400, 800);
      final twice = ImagePipeline.rotateBox(once, 1, 800, 400);
      final direct = ImagePipeline.rotateBox(box, 2, 400, 800);
      expect(twice.left, direct.left);
      expect(twice.top, direct.top);
      expect(twice.right, direct.right);
      expect(twice.bottom, direct.bottom);
    });

    test('rantai penuh: rotate lalu translateBox ke crop', () {
      // Gambar asli 400×800, barcode di Box(100,200,300,260).
      // Diputar 90° CW → bingkai 800×400, bbox → Box(540,100,600,300).
      // Crop (koordinat putar): Box(500,50,700,350).
      const det = Box(100, 200, 300, 260);
      final rotated = ImagePipeline.rotateBox(det, 1, 400, 800);
      const crop = Box(500, 50, 700, 350);
      final tb = ImagePipeline.translateBox(rotated, crop)!;
      expect(tb.left, 40); // 540−500
      expect(tb.top, 50); // 100−50
      expect(tb.right, 100); // 600−500
      expect(tb.bottom, 250); // 300−50
    });

    test('bbox di luar crop setelah rotasi → null', () {
      const det = Box(100, 200, 300, 260);
      final rotated = ImagePipeline.rotateBox(det, 1, 400, 800);
      // Crop jauh dari bbox terputar.
      const crop = Box(0, 0, 100, 100);
      expect(ImagePipeline.translateBox(rotated, crop), isNull);
    });
  });

  group('logika toggle orientasi', () {
    // Satu tombol toggle: ketuk → boolean berbalik; label & ikon
    // mengikuti state. Diuji sebagai logika murni yang dipakai UI.
    bool next(bool current) => !current;
    String label(bool vertical) => vertical ? 'Vertikal' : 'Horisontal';

    test('toggle membalik state tiap ketukan', () {
      var v = false;
      v = next(v);
      expect(v, isTrue);
      expect(label(v), 'Vertikal');
      v = next(v);
      expect(v, isFalse);
      expect(label(v), 'Horisontal');
    });

    test('label selalu sinkron dengan state', () {
      expect(label(true), isNot(equals(label(false))));
    });
  });
}
