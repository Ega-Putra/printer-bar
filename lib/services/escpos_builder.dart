import 'dart:typed_data';

/// Membangun byte stream ESC/POS universal untuk mencetak gambar raster.
///
/// Hanya memakai perintah standar yang dipahami semua printer thermal
/// kompatibel ESC/POS (XPrinter, Epson, maupun generik):
/// - `ESC @` (0x1B 0x40): inisialisasi printer
/// - `GS v 0` (0x1D 0x76 0x30 0x00): cetak gambar raster, dipotong per
///   [maxChunkHeight] baris agar aman untuk buffer printer kecil
/// - `ESC d n` (0x1B 0x64 0x04): feed 4 baris
/// - `GS V 0` (0x1D 0x56 0x00): potong penuh (diabaikan printer tanpa cutter)
class EscPosBuilder {
  /// Tinggi maksimum tiap perintah raster (batas aman buffer printer).
  static const int maxChunkHeight = 255;

  /// [raster]: byte 1-bit hasil [ImagePipeline.toRasterBytes].
  /// [widthBytes]: jumlah byte per baris (= dots / 8).
  /// [height]: jumlah baris gambar.
  static List<int> buildImageJob({
    required Uint8List raster,
    required int widthBytes,
    required int height,
  }) {
    assert(raster.length == widthBytes * height,
        'panjang raster tidak cocok dengan dimensi');
    final out = <int>[0x1B, 0x40]; // INIT

    var y = 0;
    while (y < height) {
      final chunkH = (height - y).clamp(1, maxChunkHeight);
      out.addAll([
        0x1D, 0x76, 0x30, 0x00, // GS v 0, m = 0 (normal)
        widthBytes & 0xFF, (widthBytes >> 8) & 0xFF, // xL xH
        chunkH & 0xFF, (chunkH >> 8) & 0xFF, // yL yH
      ]);
      out.addAll(raster.sublist(y * widthBytes, (y + chunkH) * widthBytes));
      y += chunkH;
    }

    out.addAll([0x1B, 0x64, 0x04]); // feed 4 baris
    out.addAll([0x1D, 0x56, 0x00]); // full cut
    return out;
  }
}
