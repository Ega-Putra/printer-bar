import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'app_errors.dart';

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

  /// Putar [box] 90° searah jarum jam sebanyak [turns] (dinormalisasi
  /// ke 0..3). [w]/[h] = dimensi gambar ASAL (sebelum diputar).
  ///
  /// Dipakai agar deteksi barcode cukup dijalankan SEKALI pada gambar
  /// asli: kotaknya di-transform matematis mengikuti rotasi tampilan,
  /// bukan dideteksi ulang pada gambar yang sudah diputar (ML Kit
  /// sering gagal pada gambar putaran).
  ///
  /// Rumus 90° CW: titik (x, y) dalam W×H → (H − y, x) dalam H×W,
  /// sehingga Box(l, t, r, b) → Box(H − b, l, H − t, r).
  static Box rotateBox(Box box, int turns, int w, int h) {
    var b = box;
    var cw = w;
    var ch = h;
    final n = ((turns % 4) + 4) % 4;
    for (var i = 0; i < n; i++) {
      b = Box(ch - b.bottom, b.left, ch - b.top, b.right);
      final t = cw;
      cw = ch;
      ch = t;
    }
    return b;
  }

  /// Letakkan [src] di tengah kanvas putih selebar [targetWidth]
  /// (tinggi tetap). Dipakai setelah rotasi barcode vertikal.
  ///
  /// Menjamin invariant "hasil SELALU selebar [targetWidth]": bila [src]
  /// lebih lebar (mis. barcode vertikal dengan slider tinggi maksimal),
  /// ia dikecilkan dulu — kalau tidak, lebar bagian tidak sama dengan
  /// lebar header raster ESC/POS dan hasil cetak artefak.
  static img.Image padToWidth(img.Image src, int targetWidth) {
    if (src.width == targetWidth) return src.clone();
    if (src.width > targetWidth) {
      return img.copyResize(src, width: targetWidth);
    }
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
  /// Melempar [InvalidImageFile] bila byte bukan gambar yang valid.
  static img.Image decode(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const InvalidImageFile();
    }
    return decoded;
  }

  /// Ubah gambar menjadi byte raster 1-bit memakai dithering
  /// Floyd-Steinberg — jauh lebih bagus untuk foto/gambar bergradasi
  /// dibanding threshold keras (teks & barcode murni hitam-putih
  /// praktis tidak berubah).
  ///
  /// Lebar [src] HARUS kelipatan 8. Piksel paling signifikan = piksel
  /// paling kiri, siap dikirim lewat perintah ESC/POS `GS v 0`.
  static Uint8List toRasterBytesDithered(img.Image src) {
    assert(src.width % 8 == 0, 'lebar gambar harus kelipatan 8');
    final gray = img.grayscale(src);
    final w = src.width;
    final h = src.height;
    final buf = Float64List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        buf[y * w + x] = gray.getPixel(x, y).r.toDouble();
      }
    }
    final bytesPerRow = w ~/ 8;
    final out = Uint8List(bytesPerRow * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        final oldV = buf[i];
        final newV = oldV < 128 ? 0.0 : 255.0;
        if (newV == 0.0) {
          out[y * bytesPerRow + (x ~/ 8)] |= (0x80 >> (x % 8));
        }
        final err = oldV - newV;
        if (err != 0) {
          if (x + 1 < w) buf[i + 1] += err * 7 / 16;
          if (y + 1 < h) {
            if (x > 0) buf[i + w - 1] += err * 3 / 16;
            buf[i + w] += err * 5 / 16;
            if (x + 1 < w) buf[i + w + 1] += err * 1 / 16;
          }
        }
      }
    }
    return out;
  }

  /// Ubah byte raster 1-bit kembali menjadi gambar hitam-putih —
  /// dipakai untuk pratinjau "persis seperti hasil cetak".
  /// [widthPx] HARUS kelipatan 8.
  static img.Image rasterToImage(Uint8List raster, int widthPx) {
    assert(widthPx % 8 == 0, 'lebar harus kelipatan 8');
    final bytesPerRow = widthPx ~/ 8;
    final h = raster.length ~/ bytesPerRow;
    final out = img.Image(width: widthPx, height: h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < widthPx; x++) {
        final bit =
            (raster[y * bytesPerRow + (x ~/ 8)] >> (7 - (x % 8))) & 1;
        out.setPixel(
          x,
          y,
          bit == 1
              ? img.ColorRgb8(0, 0, 0)
              : img.ColorRgb8(255, 255, 255),
        );
      }
    }
    return out;
  }

  /// Cari area barcode 1D (garis vertikal rapat) secara heuristik.
  ///
  /// Fallback murni-Dart bila pemindai ML Kit tidak menemukan apa-apa
  /// (mis. modelnya belum terunduh di HP). Untuk fitur "barcode
  /// diperbesar" yang dibutuhkan hanya KOTAK area-nya, bukan nilai
  /// decode-nya — jadi heuristik ini cukup.
  ///
  /// Cara kerja: tiap baris dihitung jumlah transisi hitam↔putih.
  /// Baris barcode punya transisi SANGAT banyak dalam rentang x yang
  /// sempit, dan berlanjut puluhan piksel secara vertikal (teks tidak
  /// seperti ini: baris teks pendek dan transisinya tersebar lebar).
  /// Mengembalikan null bila tidak ada kandidat yang meyakinkan.
  static Box? findBarcodeRegion(img.Image src) {
    final gray = img.grayscale(src);
    final w = src.width;
    final h = src.height;
    if (w < 80 || h < 80) return null;

    const rowStep = 2; // sampling tiap 2 baris: cukup & cepat
    const minTransitions = 24; // transisi minimum per baris
    const minBandHeight = 36; // tinggi minimum pita (px)
    const minSpanWidth = 60; // lebar minimum rentang (px)
    const minDensity = 0.12; // transisi per px lebar rentang

    // Statistik per baris sampel: (transisi, x-min, x-max transisi).
    final rowCount = (h + rowStep - 1) ~/ rowStep;
    final rowTrans = List<int>.filled(rowCount, 0);
    final rowMinX = List<int>.filled(rowCount, w);
    final rowMaxX = List<int>.filled(rowCount, -1);
    for (var i = 0; i < rowCount; i++) {
      final y = i * rowStep;
      var prev = gray.getPixel(0, y).r < 128 ? 1 : 0;
      var t = 0;
      var minX = w;
      var maxX = -1;
      for (var x = 1; x < w; x++) {
        final v = gray.getPixel(x, y).r < 128 ? 1 : 0;
        if (v != prev) {
          t++;
          if (x < minX) minX = x;
          maxX = x;
          prev = v;
        }
      }
      rowTrans[i] = t;
      rowMinX[i] = minX;
      rowMaxX[i] = maxX;
    }

    // Pita vertikal TERPANJANG dari baris-baris padat.
    var bestStart = -1;
    var bestLen = 0;
    var curStart = -1;
    for (var i = 0; i <= rowCount; i++) {
      final dense = i < rowCount && rowTrans[i] >= minTransitions;
      if (dense && curStart < 0) {
        curStart = i;
      } else if (!dense && curStart >= 0) {
        final len = i - curStart;
        if (len > bestLen) {
          bestLen = len;
          bestStart = curStart;
        }
        curStart = -1;
      }
    }
    if (bestStart < 0) return null;

    final y0 = bestStart * rowStep;
    final y1 = ((bestStart + bestLen) * rowStep).clamp(0, h);
    if (y1 - y0 < minBandHeight) return null;

    // Rentang x gabungan dari semua transisi di pita itu.
    var spanL = w;
    var spanR = -1;
    var totalT = 0;
    var rows = 0;
    for (var i = bestStart; i < bestStart + bestLen; i++) {
      if (rowMinX[i] <= rowMaxX[i]) {
        if (rowMinX[i] < spanL) spanL = rowMinX[i];
        if (rowMaxX[i] > spanR) spanR = rowMaxX[i];
        totalT += rowTrans[i];
        rows++;
      }
    }
    if (rows == 0 || spanR <= spanL) return null;
    final spanW = spanR - spanL;
    if (spanW < minSpanWidth) return null;

    // Kepadatan: barcode = transisi rapat dalam rentang sempit.
    final density = (totalT / rows) / spanW;
    if (density < minDensity) return null;

    const pad = 6.0;
    return Box(
      (spanL - pad).clamp(0.0, w.toDouble()),
      (y0 - pad).clamp(0.0, h.toDouble()),
      (spanR + pad).clamp(0.0, w.toDouble()),
      (y1 + pad).clamp(0.0, h.toDouble()),
    );
  }
}
