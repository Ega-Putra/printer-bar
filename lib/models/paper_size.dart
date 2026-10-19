/// Ukuran kertas thermal yang didukung aplikasi.
enum PaperSize {
  mm58(58),
  mm80(80),
  mm112(112);

  const PaperSize(this.mm);

  /// Lebar kertas dalam milimeter.
  final int mm;

  /// Lebar area CETAK (printable) dalam dots pada 203 dpi.
  ///
  /// PENTING: ini lebar head printer, BUKAN lebar kertas. Head selalu
  /// lebih sempit dari kertasnya:
  /// - kertas 58 mm → head 384 dots (48 byte/baris)
  /// - kertas 80 mm → head 576 dots (72 byte/baris)
  /// - kertas 112 mm → head 832 dots (104 byte/baris)
  ///
  /// Mengirim raster SELEBAR KERTAS (mis. 464 dots untuk kertas 58 mm)
  /// membuat firmware printer salah menafsirkan aliran byte `GS v 0`:
  /// tiap baris kelebihan byte yang "bocor" ke baris berikutnya,
  /// sehingga hasil cetak fisik bergeser/duplikat ke kanan.
  /// Semua nilai kelipatan 8 (syarat perintah raster ESC/POS:
  /// 1 byte = 8 dots horizontal).
  int get dots => switch (this) {
        PaperSize.mm58 => 384,
        PaperSize.mm80 => 576,
        PaperSize.mm112 => 832,
      };

  String get label => '$mm mm';
}
