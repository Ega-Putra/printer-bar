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
    final input = InputImage.fromFilePath(imagePath);
    final barcodes = await _scanner.processImage(input);
    final out = <DetectedBarcode>[];
    for (final b in barcodes) {
      final rect = b.boundingBox;
      out.add(DetectedBarcode(
        box: Box(rect.left, rect.top, rect.right, rect.bottom),
        rawValue: b.rawValue,
      ));
    }
    return out;
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
