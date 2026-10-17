import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Kotak pembatas sederhana dalam koordinat piksel.
///
/// Didefinisikan sendiri (bukan `Rect` dari dart:ui) supaya seluruh
/// pipeline ini murni-Dart dan bisa di-unit-test tanpa Flutter.
class Box {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const Box(this.left, this.top, this.right, this.bottom);

  double get width => right - left;
  double get height => bottom - top;
  double get area => width * height;
}

/// Kumpulan utilitas pengolahan gambar untuk pipeline cetak thermal.
///
/// Alur v2: render PDF → [crop] (area pilihan user) → skala ke lebar
/// kertas → opsional crop barcode → opsional [rotate90Clockwise] →
/// [composeVertical] → [toRasterBytes] → ESC/POS.
///
/// Semua fungsi di sini murni (tidak menyentuh plugin apa pun) sehingga
/// bisa di-unit-test penuh.
class ImagePipeline {
  /// Skala [src] ke [targetWidth] piksel, aspek rasio dipertahankan.
  static img.Image scaleToWidth(img.Image src, int targetWidth) {
    if (src.width == targetWidth) return src.clone();
    return img.copyResize(src, width: targetWidth);
  }

  /// Crop [box] dari [src] tanpa mengubah skala.
  static img.Image crop(img.Image src, Box box) {
    final x = box.left.floor().clamp(0, src.width - 1);
    final y = box.top.floor().clamp(0, src.height - 1);
    final w = (box.right.ceil() - x).clamp(1, src.width - x);
    final h = (box.bottom.ceil() - y).clamp(1, src.height - y);
    return img.copyCrop(src, x: x, y: y, width: w, height: h);
  }

  /// Ubah gambar menjadi byte raster 1-bit (bit paling signifikan = piksel
  /// paling kiri), siap dikirim lewat perintah ESC/POS `GS v 0`.
  ///
  /// Lebar [src] HARUS kelipatan 8. Piksel dengan luminance < 128
  /// dianggap hitam (titik panas menyala).
  static Uint8List toRasterBytes(img.Image src) {
    assert(src.width % 8 == 0, 'lebar gambar harus kelipatan 8');
    final gray = img.grayscale(src);
    final bytesPerRow = src.width ~/ 8;
    final out = Uint8List(bytesPerRow * src.height);
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        // Pada gambar grayscale, r == g == b.
        final lum = gray.getPixel(x, y).r.toDouble();
        if (lum < 128) {
          out[y * bytesPerRow + (x ~/ 8)] |= (0x80 >> (x % 8));
        }
      }
    }
    return out;
  }

  /// Hitung kotak crop = [box] ditambah padding [padFraction] dari ukuran
  /// box, lalu dijepit agar tidak keluar dari dimensi gambar.
  static Box paddedCrop(
    Box box,
    int imgW,
    int imgH, {
    double padFraction = 0.08,
  }) {
    final padX = box.width * padFraction;
    final padY = box.height * padFraction;
    final l = (box.left - padX).clamp(0.0, imgW.toDouble());
    final t = (box.top - padY).clamp(0.0, imgH.toDouble());
    final r = (box.right + padX).clamp(0.0, imgW.toDouble());
    final b = (box.bottom + padY).clamp(0.0, imgH.toDouble());
    return Box(l, t, r, b);
  }

  /// Crop [box] dari [src] lalu skala hasilnya ke [targetWidth] piksel
  /// (aspek rasio dipertahankan).
  static img.Image cropAndScaleToWidth(
    img.Image src,
    Box box,
    int targetWidth,
  ) {
    return scaleToWidth(crop(src, box), targetWidth);
  }

  /// Geser [box] (koordinat gambar penuh) ke koordinat gambar yang sudah
  /// di-crop ke [crop]. Mengembalikan null bila box tidak bersinggungan
  /// sama sekali dengan area crop.
  static Box? translateBox(Box box, Box crop) {
    final l = (box.left - crop.left).clamp(0.0, crop.width);
    final t = (box.top - crop.top).clamp(0.0, crop.height);
    final r = (box.right - crop.left).clamp(0.0, crop.width);
    final b = (box.bottom - crop.top).clamp(0.0, crop.height);
    if (r <= l || b <= t) return null;
    return Box(l, t, r, b);
  }

  /// Putar [src] 90° searah jarum jam (untuk opsi barcode vertikal).
  static img.Image rotate90Clockwise(img.Image src) {
    return img.copyRotate(src, angle: 90);
  }

  /// Letakkan [src] di tengah kanvas putih selebar [targetWidth]
  /// (tinggi tetap). Dipakai setelah rotasi barcode vertikal.
  static img.Image padToWidth(img.Image src, int targetWidth) {
    if (src.width >= targetWidth) return src.clone();
    final canvas = img.Image(width: targetWidth, height: src.height);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    final dx = (targetWidth - src.width) ~/ 2;
    img.compositeImage(canvas, src, dstX: dx);
    return canvas;
  }

  /// Susun [parts] secara vertikal di atas kanvas putih dengan jarak
  /// [gap] piksel antar bagian. Semua bagian diasumsikan selebar sama.
  static img.Image composeVertical(List<img.Image> parts, {int gap = 24}) {
    assert(parts.isNotEmpty, 'parts tidak boleh kosong');
    final w = parts.first.width;
    var h = 0;
    for (final p in parts) {
      h += p.height;
    }
    h += gap * (parts.length - 1);
    final canvas = img.Image(width: w, height: h);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    var y = 0;
    for (final p in parts) {
      img.compositeImage(canvas, p, dstY: y);
      y += p.height + gap;
    }
    return canvas;
  }

  /// Decode byte PNG/JPEG menjadi [img.Image].
  ///
  /// Melempar [FormatException] bila byte bukan gambar yang valid.
  static img.Image decode(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Berkas bukan gambar yang valid');
    }
    return decoded;
  }
}
