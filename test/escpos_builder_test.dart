import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:thermal_print/services/escpos_builder.dart';

void main() {
  test('buildImageJob: gambar 8x8 hitam penuh -> byte sesuai spek', () {
    final raster = Uint8List.fromList(List.filled(8, 0xFF));
    final job = EscPosBuilder.buildImageJob(
      raster: raster,
      widthBytes: 1,
      height: 8,
    );
    expect(job, [
      0x1B, 0x40, // INIT
      0x1D, 0x76, 0x30, 0x00, // GS v 0 m=0
      0x01, 0x00, // xL xH = 1 byte
      0x08, 0x00, // yL yH = 8 baris
      0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, // data
      0x1B, 0x64, 0x04, // feed 4
      0x1D, 0x56, 0x00, // full cut
    ]);
  });

  test('buildImageJob: 300 baris di-chunk 255 + 45', () {
    final raster = Uint8List(300); // 1 byte/baris
    final job = EscPosBuilder.buildImageJob(
      raster: raster,
      widthBytes: 1,
      height: 300,
    );
    // Perintah kedua mulai setelah: INIT(2) + header(8) + 255 data
    const second = 2 + 8 + 255;
    expect(
      job.sublist(second, second + 8),
      [0x1D, 0x76, 0x30, 0x00, 0x01, 0x00, 0x2D, 0x00], // yL=0x2D=45
    );
    // Total = 2 + (8+255) + (8+45) + 3 + 3
    expect(job.length, 2 + 263 + 53 + 3 + 3);
  });

  test('REGRESI v1.8: header xL/xH = byte per baris, BUKAN dots', () {
    // Gambar 16 dots lebar = 2 byte/baris, 4 baris. Kalau xL/xH diisi
    // dots (16), printer membaca 16 byte/baris dari stream 2 byte/baris
    // -> hasil cetak bergeser/duplikat ke kanan.
    final raster = Uint8List.fromList(List.filled(2 * 4, 0xAA));
    final job = EscPosBuilder.buildImageJob(
      raster: raster,
      widthBytes: 2,
      height: 4,
    );
    expect(
      job,
      [
        0x1B, 0x40, // INIT
        0x1D, 0x76, 0x30, 0x00, // GS v 0 m=0
        0x02, 0x00, // xL xH = 2 BYTE (bukan 16 dots!)
        0x04, 0x00, // yL yH = 4 baris
        0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, // data: 2*4
        0x1B, 0x64, 0x04, // feed 4
        0x1D, 0x56, 0x00, // full cut
      ],
    );
  });

  test('REGRESI v1.8: panjang data raster == bytesPerRow * rows', () {
    // Simulasi alur cetak asli: lebar = PaperSize printable dots.
    for (final dots in [384, 576, 832]) {
      final widthBytes = dots ~/ 8;
      final height = 10;
      final raster = Uint8List(widthBytes * height);
      final job = EscPosBuilder.buildImageJob(
        raster: raster,
        widthBytes: widthBytes,
        height: height,
      );
      // header: INIT(2) + GS v 0(8); data = widthBytes*height; tail = 6
      expect(job.sublist(2, 10),
          [0x1D, 0x76, 0x30, 0x00, widthBytes & 0xFF, 0x00, 0x0A, 0x00]);
      expect(job.length, 2 + 8 + widthBytes * height + 3 + 3);
    }
  });
}
