import 'dart:io';

import 'package:barcode_image/barcode_image.dart' as bc;
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image/image.dart' as img;

import 'code128_decoder.dart';
import 'image_pipeline.dart';

/// Barcode yang terdeteksi pada sebuah gambar.
class DetectedBarcode {
  /// Kotak pembatas dalam koordinat piksel gambar sumber.
  final Box box;

  /// Nilai hasil decode (bisa null bila tak terbaca, kotak tetap valid).
  final String? rawValue;

  /// Format menurut ML Kit (null bila dari fallback heuristik).
  final BarcodeFormat? format;

  const DetectedBarcode({required this.box, this.rawValue, this.format});
}

/// Deteksi barcode memakai Google ML Kit (on-device, semua format standar).
class BarcodeService {
  final BarcodeScanner _scanner = BarcodeScanner();

  /// Deteksi semua barcode pada berkas gambar [imagePath].
  ///
  /// Mengembalikan daftar kosong bila tidak ada barcode yang ditemukan
  /// (bukan error — pemanggil yang memutuskan pesannya).
  Future<List<DetectedBarcode>> detect(String imagePath) async {
    // 1. Coba ML Kit dulu (akurat + bisa decode nilai).
    try {
      final input = InputImage.fromFilePath(imagePath);
      final barcodes = await _scanner.processImage(input);
      if (barcodes.isNotEmpty) {
        return barcodes.map((b) {
          final rect = b.boundingBox;
          return DetectedBarcode(
            box: Box(rect.left, rect.top, rect.right, rect.bottom),
            rawValue: b.rawValue,
            format: b.format,
          );
        }).toList();
      }
    } catch (_) {
      // Jatuh ke fallback heuristik di bawah.
    }
    // 2. Fallback murni-Dart: cari area garis vertikal rapat khas
    //    barcode 1D. Tanpa butuh model ML — jalan di semua HP.
    //    Untuk fitur "diperbesar" yang penting hanya kotaknya.
    try {
      final bytes = await File(imagePath).readAsBytes();
      final region =
          ImagePipeline.findBarcodeRegion(ImagePipeline.decode(bytes));
      if (region != null) {
        return [DetectedBarcode(box: region)];
      }
    } catch (_) {
      // Abaikan — kembalikan daftar kosong seperti semula.
    }
    return [];
  }

  /// Barcode dengan area terbesar (yang paling layak diperbesar).
  DetectedBarcode? largest(List<DetectedBarcode> barcodes) {
    if (barcodes.isEmpty) return null;
    var best = barcodes.first;
    for (final b in barcodes.skip(1)) {
      if (b.box.area > best.box.area) best = b;
    }
    return best;
  }

  /// Coba baca nilai Code128 langsung dari piksel pada [det.box].
  ///
  /// Dipakai bila [det] punya kotak tapi [DetectedBarcode.rawValue]-nya null
  /// (ML Kit gagal decode). Mengembalikan deteksi baru dengan rawValue dan
  /// format terisi, atau null bila decode gagal.
  Future<DetectedBarcode?> decodeValue(String imagePath, DetectedBarcode det) async {
    if (det.rawValue != null) return det;
    try {
      final bytes = await File(imagePath).readAsBytes();
      final image = ImagePipeline.decode(bytes);
      final value = Code128Decoder.decode(image, det.box);
      if (value == null) return null;
      return DetectedBarcode(
        box: det.box,
        rawValue: value,
        format: BarcodeFormat.code128,
      );
    } catch (_) {
      return null;
    }
  }

  /// Petakan format ML Kit ke generator package:barcode.
  /// null = tidak didukung (mis. QR / 2D) → pemanggil pakai fallback crop.
  static bc.Barcode? _toBarcode(BarcodeFormat? format) {
    switch (format) {
      case BarcodeFormat.code128:
        return bc.Barcode.code128();
      case BarcodeFormat.code39:
        return bc.Barcode.code39();
      case BarcodeFormat.code93:
        return bc.Barcode.code93();
      case BarcodeFormat.codabar:
        return bc.Barcode.codabar();
      case BarcodeFormat.ean13:
        return bc.Barcode.ean13();
      case BarcodeFormat.ean8:
        return bc.Barcode.ean8();
      case BarcodeFormat.itf:
        return bc.Barcode.itf();
      case BarcodeFormat.upca:
        return bc.Barcode.upcA();
      case BarcodeFormat.upce:
        return bc.Barcode.upcE();
      default:
        return null;
    }
  }

  /// Generate ulang barcode yang TAJAM dari nilai hasil decode,
  /// selebar [widthPx] piksel penuh dengan tinggi bilah [barHeightPx].
  /// Nilai dicetak di bawah bilah seperti label resi asli.
  ///
  /// Mengembalikan null bila tidak ada nilai decode atau format tidak
  /// didukung — pemanggil memakai fallback crop+skala dari gambar asli.
  static img.Image? regenerateBarcode({
    required DetectedBarcode det,
    required int widthPx,
    required int barHeightPx,
  }) {
    final value = det.rawValue;
    if (value == null || value.isEmpty) return null;
    final generator = _toBarcode(det.format);
    if (generator == null) return null;
    try {
      // Validasi dulu: make() melempar bila data tak cocok formatnya
      // (mis. EAN-13 dengan digit salah).
      generator.make(value,
          width: widthPx.toDouble(), height: barHeightPx.toDouble());
    } catch (_) {
      return null;
    }
    try {
      final font = widthPx < 500 ? img.arial14 : img.arial24;
      final textH = font.lineHeight + 10;
      final out =
          img.Image(width: widthPx, height: barHeightPx + textH);
      img.fill(out, color: img.ColorRgb8(255, 255, 255));
      // Bilah di atas (tanpa teks bawaan — kita gambar sendiri agar
      // posisinya pasti). Disisakan quiet zone (margin putih) di
      // kiri-kanan selebar ±5% agar barcode tetap kebaca scanner —
      // standar: minimal 10x lebar modul tersempit per sisi.
      final qz = (widthPx * 0.05).round().clamp(16, 48);
      bc.drawBarcode(
        out,
        generator,
        value,
        x: qz,
        width: widthPx - 2 * qz,
        height: barHeightPx,
      );
      // Nilai di bawah, rata tengah.
      final tw = font.getMetrics(value).width;
      img.drawString(
        out,
        value,
        font: font,
        x: ((widthPx - tw) ~/ 2).clamp(0, widthPx),
        y: barHeightPx + 4,
        color: img.ColorRgb8(0, 0, 0),
      );
      return out;
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() => _scanner.close();
}
