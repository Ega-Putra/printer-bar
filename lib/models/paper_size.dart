/// Ukuran kertas thermal yang didukung aplikasi.
enum PaperSize {
  mm58(58),
  mm80(80),
  mm112(112);

  const PaperSize(this.mm);

  /// Lebar kertas dalam milimeter.
  final int mm;

  /// Lebar area cetak dalam dots pada 203 dpi.
  ///
  /// Rumus: round(mm / 25.4 * 203 / 8) * 8 — hasil SELALU kelipatan 8
  /// karena perintah raster ESC/POS (`GS v 0`) mengirim data per byte
  /// (1 byte = 8 dots horizontal).
  int get dots => (mm / 25.4 * 203 / 8).round() * 8;

  String get label => '$mm mm';
}
