import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'free_text_document.dart';

/// Render [StyledDocument] menjadi gambar hitam-putih selebar [widthPx]
/// (dots kertas), siap masuk pipeline raster ESC/POS yang sama dengan
/// cetak resi.
///
/// Memakai TextPainter (mesin layout teks Flutter) sehingga word wrap
/// dan gaya (bold/italic/underline) di hasil cetak persis seperti
/// tampilan di layar. Satu unit fontSize = satu dot (render 1:1).
class FreeTextRenderer {
  static Future<img.Image> render({
    required StyledDocument doc,
    required int widthPx,
    required double fontSize,
    required FreeTextAlign alignment,
  }) async {
    assert(widthPx % 8 == 0, 'lebar harus kelipatan 8');
    final textAlign = switch (alignment) {
      FreeTextAlign.left => TextAlign.left,
      FreeTextAlign.center => TextAlign.center,
      FreeTextAlign.right => TextAlign.right,
    };
    final painter = TextPainter(
      text: TextSpan(
        style: TextStyle(fontSize: fontSize, color: const Color(0xFF000000)),
        children: doc.segments
            .map((seg) => TextSpan(
                  text: seg.text,
                  style: TextStyle(
                    fontWeight:
                        seg.style.bold ? FontWeight.bold : null,
                    fontStyle:
                        seg.style.italic ? FontStyle.italic : null,
                    decoration: seg.style.underline
                        ? TextDecoration.underline
                        : null,
                  ),
                ))
            .toList(),
      ),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    );
    // minWidth = maxWidth = lebar kertas: paragraf dipaksa selebar
    // penuh sehingga textAlign (tengah/kanan) benar-benar menggeser
    // baris. Tanpa minWidth, paragraf menyusut selebar konten dan
    // perataan menjadi no-op.
    painter.layout(
        minWidth: widthPx.toDouble(), maxWidth: widthPx.toDouble());
    // Dokumen kosong tetap menghasilkan 1 baris putih (UI sudah
    // menjaga agar render tidak dipanggil untuk dokumen kosong).
    final height = painter.height.ceil().clamp(1, 100000);
    final size = Size(widthPx.toDouble(), height.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & size);
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFFFFFFF));
    painter.paint(canvas, Offset.zero);
    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(widthPx, height);
    final byteData =
        await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rgba = byteData!.buffer.asUint8List();
    final out = img.Image(width: widthPx, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < widthPx; x++) {
        final i = (y * widthPx + x) * 4;
        out.setPixel(x, y, img.ColorRgb8(rgba[i], rgba[i + 1], rgba[i + 2]));
      }
    }
    return out;
  }
}
