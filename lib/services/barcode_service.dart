import 'dart:io';

import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import 'image_pipeline.dart';

/// Barcode yang terdeteksi pada sebuah gambar.
class DetectedBarcode {
  /// Kotak pembatas dalam koordinat piksel gambar sumber.
  final Box box;

  /// Nilai hasil decode (bisa null bila tak terbaca, kotak tetap valid).
  final String? rawValue;

  const DetectedBarcode({required this.box, this.rawValue});
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

  Future<void> dispose() => _scanner.close();
}
