import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Gambar pratinjau hasil cetak.
///
/// PENTING: [gaplessPlayback] HARUS true. Setiap tombol opsi cetak
/// (mode/orientasi/dither/rotate) memanggil `_refreshPrintPreview()` yang
/// meng-encode PNG BARU (objek [Uint8List] baru) walau pikselnya mirip.
/// Tanpa gaplessPlayback, [Image] membuang frame lama seketika dan
/// melaporkan tinggi NOL selama byte baru di-decode (async, 1-2 frame).
/// Akibatnya kartu pratinjau di ATAS tombol opsi kolaps sesaat, lalu
/// [ScrollPosition] meng-clamp offset scroll ke atas ("loncat ke atas")
/// — dan offset TIDAK kembali walau gambar sudah muncul lagi.
/// ScrollController persisten tidak menolong karena offset-nya memang
/// di-clamp secara sah oleh penyusutan konten sesaat itu (v1.1.1).
class PrintPreviewImage extends StatelessWidget {
  final Uint8List bytes;

  const PrintPreviewImage({super.key, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      bytes,
      gaplessPlayback: true,
    );
  }
}
