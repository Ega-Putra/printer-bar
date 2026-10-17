import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

/// Satu halaman PDF yang sudah di-render menjadi berkas PNG.
class RenderedPage {
  final String path;
  final int width;
  final int height;

  /// Byte PNG hasil render (disimpan agar pratinjau/crop tak perlu
  /// baca ulang berkas).
  final Uint8List bytes;

  const RenderedPage({
    required this.path,
    required this.width,
    required this.height,
    required this.bytes,
  });
}

/// Memilih berkas PDF resi dan me-render tiap halamannya menjadi gambar PNG.
class PdfService {
  /// Buka pemilih berkas sistem, kembalikan path PDF yang BISA DIBACA,
  /// atau null bila pengguna batal memilih.
  ///
  /// Melempar [Exception] berbahasa Indonesia bila berkas dipilih tapi
  /// tidak bisa dibaca (mis. content URI yang path-nya null — penyebab
  /// umum "preview tidak muncul tanpa error" di sebagian HP Android).
  Future<String?> pickPdf() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    // Dibatalkan pengguna → list kosong (BUKAN error).
    if (files.isEmpty) return null;
    final file = files.single;
    // Jalur 1: path langsung yang bisa dibaca (umumnya dari File Manager).
    final p = file.path;
    if (p != null && File(p).existsSync()) return p;
    // Jalur 2: URI non-file (mis. content://) yang path-nya null →
    // baca bytes-nya lalu salin ke direktori cache.
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) {
        final tmp = await getTemporaryDirectory();
        final out = File(
            '${tmp.path}/resi_${DateTime.now().millisecondsSinceEpoch}.pdf');
        await out.writeAsBytes(bytes, flush: true);
        return out.path;
      }
    } catch (_) {
      // Jatuh ke Exception di bawah dengan pesan yang jelas.
    }
    throw Exception(
      'Berkas PDF tidak bisa dibaca dari penyimpanan HP. '
      'Coba pilih lagi dari aplikasi File Manager.',
    );
  }

  /// Render semua halaman [pdfPath] menjadi PNG selebar [renderWidth] piksel.
  ///
  /// Resolusi render 2x lipat dari lebar cetak memberi hasil deteksi
  /// barcode yang jauh lebih akurat.
  Future<List<RenderedPage>> renderPages(
    String pdfPath, {
    required int renderWidth,
  }) async {
    if (!File(pdfPath).existsSync()) {
      throw Exception('Berkas PDF tidak ditemukan di: $pdfPath');
    }
    final document = await PdfDocument.openFile(pdfPath);
    try {
      final tmp = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final pages = <RenderedPage>[];
      for (var i = 1; i <= document.pagesCount; i++) {
        final page = await document.getPage(i);
        try {
          final rendered = await page.render(
            width: renderWidth.toDouble(),
            height: renderWidth.toDouble() * page.height / page.width,
            format: PdfPageImageFormat.png,
            backgroundColor: '#FFFFFF',
          );
          if (rendered == null) {
            throw Exception('Gagal me-render halaman $i');
          }
          final file = File('${tmp.path}/resi_p${i}_$stamp.png');
          await file.writeAsBytes(rendered.bytes);
          pages.add(RenderedPage(
            path: file.path,
            width: rendered.width ?? renderWidth,
            height: rendered.height ??
                (renderWidth * page.height / page.width).round(),
            bytes: rendered.bytes,
          ));
        } finally {
          await page.close();
        }
      }
      return pages;
    } finally {
      await document.close();
    }
  }
}
