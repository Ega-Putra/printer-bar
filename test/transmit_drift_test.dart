import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image/image.dart' as img;
import 'package:thermal_print/services/barcode_service.dart';
import 'package:thermal_print/services/escpos_builder.dart';
import 'package:thermal_print/services/image_pipeline.dart';

/// Simulasi perilaku plugin `print_bluetooth_thermal` 1.2.5
/// (lihat `handleWriteBytes` di kode native-nya): SETIAP pemanggilan
/// `writeBytes` disisipi satu byte 0x0A (line feed) di awal data.
Uint8List pluginWire(List<List<int>> calls) {
  final out = <int>[];
  for (final c in calls) {
    out.add(0x0A);
    out.addAll(c);
  }
  return Uint8List.fromList(out);
}

/// Parser printer ESC/POS yang strict: berjalan di atas aliran byte
/// persis seperti firmware printer — mengonsumsi TEPAT widthBytes
/// per baris untuk setiap perintah `GS v 0`. Mengembalikan daftar
/// baris raster yang "dicetak". Gagal bila ada byte tak dikenal.
List<Uint8List> parseStrictPrinter(Uint8List wire, int widthBytes) {
  final rows = <Uint8List>[];
  var i = 0;
  while (i < wire.length) {
    final b = wire[i];
    if (b == 0x1B && i + 1 < wire.length && wire[i + 1] == 0x40) {
      i += 2; // ESC @
      continue;
    }
    if (b == 0x0A) {
      i += 1; // LF (mis. sisipan plugin di awal job)
      continue;
    }
    if (b == 0x1B && i + 2 < wire.length && wire[i + 1] == 0x64) {
      i += 3; // ESC d n
      continue;
    }
    if (b == 0x1D && i + 2 < wire.length && wire[i + 1] == 0x56) {
      i += 3; // GS V n
      continue;
    }
    if (b == 0x1D &&
        i + 7 < wire.length &&
        wire[i + 1] == 0x76 &&
        wire[i + 2] == 0x30) {
      final wB = wire[i + 4] | (wire[i + 5] << 8);
      final hC = wire[i + 6] | (wire[i + 7] << 8);
      expect(wB, widthBytes, reason: 'header xL/xH != $widthBytes');
      i += 8;
      for (var r = 0; r < hC; r++) {
        rows.add(wire.sublist(i, i + wB));
        i += wB;
      }
      continue;
    }
    fail('byte tak dikenal 0x${b.toRadixString(16)} di offset $i');
  }
  return rows;
}

/// Bangun job cetak persis seperti home_screen._composePage (mode
/// barcode diperbesar VERTIKAL) + _print: compose -> raster -> job.
({Uint8List raster, List<int> job, int height}) buildVerticalBarcodeJob() {
  const dots = 384;
  final det = DetectedBarcode(
    box: const Box(10, 10, 200, 80),
    rawValue: '004614605180',
    format: BarcodeFormat.code128,
  );
  final barHpx = (25 / 25.4 * 203).round();
  final regen = BarcodeService.regenerateBarcode(
      det: det, widthPx: dots, barHeightPx: barHpx)!;
  expect(regen.width, dots);
  final rotated = ImagePipeline.rotate90Clockwise(regen);
  final padded = ImagePipeline.padToWidth(rotated, dots);
  expect(padded.width, dots);
  final page = img.Image(width: dots, height: 400);
  img.fill(page, color: img.ColorRgb8(255, 255, 255));
  final composed = ImagePipeline.composeVertical([page, padded]);
  expect(composed.width, dots);
  final raster = ImagePipeline.toRasterBytesDithered(composed);
  final job = EscPosBuilder.buildImageJob(
      raster: raster, widthBytes: dots ~/ 8, height: composed.height);
  return (raster: raster, job: job, height: composed.height);
}

void main() {
  group('drift transmisi bluetooth', () {
    test('strategi LAMA (job dipecah per 2048 byte) menyisipkan 0x0A',
        () {
      final t = buildVerticalBarcodeJob();
      // Tiru kode lama: potong job jadi potongan 2048 byte.
      final calls = <List<int>>[];
      for (var i = 0; i < t.job.length; i += 2048) {
        calls.add(t.job.sublist(i, min(i + 2048, t.job.length)));
      }
      expect(calls.length, greaterThan(1));
      final wire = pluginWire(calls);
      // Setelah 0x0A pertama (sebelum ESC @, tidak masalah), aliran
      // yang diterima printer HARUS sama persis dengan job. Dengan
      // strategi lama, 0x0A tersisip di TENGAH raster (awal tiap
      // potongan ke-2..N) -> tiap baris setelahnya bergeser 1 byte
      // (= 8 dots) ke kanan: artefak stair-step di cetakan fisik.
      final received = wire.sublist(1);
      expect(listEquals(received, Uint8List.fromList(t.job)), isFalse,
          reason: 'byte 0x0A tersisip di tengah aliran raster');
      // Lokasi penyisipan pertama: tepat di batas potongan ke-2.
      var firstDiff = -1;
      for (var k = 0; k < received.length && k < t.job.length; k++) {
        if (received[k] != t.job[k]) {
          firstDiff = k;
          break;
        }
      }
      expect(firstDiff, 2048,
          reason: 'sisipan pertama harus di awal potongan ke-2');
      expect(received[firstDiff], 0x0A);
      debugPrint('terbukti: 0x0A disisipkan di offset $firstDiff '
          '(tengah aliran raster) -> stair-step 8 dots per potongan');
    });

    test('strategi BARU (satu panggilan) -> pixel-exact', () {
      final t = buildVerticalBarcodeJob();
      // Satu panggilan: satu 0x0A di awal (sebelum ESC @, dieksekusi
      // sebagai line feed kosong) — tidak mengganggu aliran raster.
      final wire = pluginWire([t.job]);
      expect(wire.sublist(1), Uint8List.fromList(t.job),
          reason: 'printer harus menerima job byte-per-byte utuh');
      final rows = parseStrictPrinter(wire, 48);
      expect(rows.length, t.height);
      final reconstructed =
          Uint8List.fromList(rows.expand((r) => r).toList());
      expect(reconstructed, t.raster,
          reason: 'hasil cetak harus sama persis dengan raster');
    });
  });
}
