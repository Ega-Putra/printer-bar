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
  /// Buka pemilih berkas sistem, kembalikan path PDF atau null bila batal.
  Future<String?> pickPdf() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (files.isEmpty) return null;
    return files.single.path;
  }

  /// Render semua halaman [pdfPath] menjadi PNG selebar [renderWidth] piksel.
  ///
  /// Resolusi render 2x lipat dari lebar cetak memberi hasil deteksi
  /// barcode yang jauh lebih akurat.
  Future<List<RenderedPage>> renderPages(
    String pdfPath, {
    required int renderWidth,
  }) async {
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
