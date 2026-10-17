import 'package:image/image.dart' as img;

import 'code128_table.dart';
import 'image_pipeline.dart';

/// Decode barcode Code128 langsung dari piksel gambar (murni Dart).
///
/// Dipakai sebagai cadangan bila ML Kit menemukan kotak barcode tapi gagal
/// men-decode nilainya. Dirancang untuk render PDF yang bersih: kontras
/// tinggi, bar vertikal, tanpa rotasi (bukan foto kamera).
///
/// Cara pakai: [decode] mengembalikan nilai string bila pola + checksum
/// valid, atau null bila tidak.
class Code128Decoder {
  // Nilai simbol khusus Code128.
  static const int _fnc3 = 96;
  static const int _fnc2 = 97;
  static const int _shift = 98;
  static const int _codeC = 99;
  static const int _codeB = 100;
  static const int _codeA = 101;
  static const int _fnc1 = 102;
  static const int _startA = 103;
  static const int _startB = 104;
  static const int _startC = 105;
  static const int _stop = 106;

  /// Peta pola (6 run) -> nilai simbol, untuk 0..105.
  static final Map<String, int> _patternToValue = {
    for (var v = 0; v <= 105; v++) kCode128Patterns[v].join(','): v,
  };

  /// Decode nilai Code128 dari area [box] pada [src].
  /// Mengembalikan null bila tidak ada pola valid / checksum salah.
  ///
  /// Mencoba beberapa varian bila gagal: box diperlebar (heuristik kadang
  /// terlalu ketat) dan upscale 2x (modul < 3px sulit di-quantize).
  static String? decode(img.Image src, Box box) {
    // Varian 1: box asli. Varian 2: box diperlebar 25% tiap sisi.
    final boxes = <Box>[box];
    final ex = box.width * 0.25, ey = box.height * 0.25;
    boxes.add(Box(
      (box.left - ex).clamp(0.0, src.width.toDouble()),
      (box.top - ey).clamp(0.0, src.height.toDouble()),
      (box.right + ex).clamp(0.0, src.width.toDouble()),
      (box.bottom + ey).clamp(0.0, src.height.toDouble()),
    ));
    for (final b in boxes) {
      final value = _decodeBox(src, b, upscale: false);
      if (value != null) return value;
    }
    // Varian 3-4: upscale 2x untuk barcode kecil.
    for (final b in boxes) {
      final value = _decodeBox(src, b, upscale: true);
      if (value != null) return value;
    }
    return null;
  }

  static String? _decodeBox(img.Image src, Box box, {required bool upscale}) {
    // Beri margin agar quiet zone ikut ke-crop.
    final m = (box.width * 0.08).clamp(4.0, 20.0);
    final l = (box.left - m).clamp(0.0, src.width.toDouble()).round();
    final t = (box.top - m).clamp(0.0, src.height.toDouble()).round();
    final r = (box.right + m).clamp(0.0, src.width.toDouble()).round();
    final b = (box.bottom + m).clamp(0.0, src.height.toDouble()).round();
    if (r - l < 60 || b - t < 16) return null;
    var region = img.copyCrop(src, x: l, y: t, width: r - l, height: b - t);
    if (upscale) {
      region = img.copyResize(region,
          width: region.width * 2,
          height: region.height * 2,
          interpolation: img.Interpolation.linear);
    }
    final gray = img.grayscale(region);
    final w = gray.width, h = gray.height;

    // Coba beberapa scanline horizontal untuk ketahanan terhadap cacat baris.
    for (final fy in [0.35, 0.5, 0.65]) {
      final value = _decodeScanline(gray, w, h, fy);
      if (value != null) return value;
    }
    return null;
  }

  static String? _decodeScanline(img.Image gray, int w, int h, double fy) {
    // Rata-rata 5 baris di sekitar fy untuk meredam noise.
    final yc = (h * fy).round().clamp(2, h - 3);
    final lum = List<double>.filled(w, 0);
    for (var y = yc - 2; y <= yc + 2; y++) {
      for (var x = 0; x < w; x++) {
        lum[x] += gray.getPixel(x, y).r.toDouble();
      }
    }
    var minL = double.infinity, maxL = 0.0;
    for (var x = 0; x < w; x++) {
      lum[x] /= 5;
      if (lum[x] < minL) minL = lum[x];
      if (lum[x] > maxL) maxL = lum[x];
    }
    if (maxL - minL < 40) return null; // kontras terlalu rendah
    final thr = (minL + maxL) / 2;

    // Ekstrak run bar/spasi, mulai dari bar hitam pertama (lewati quiet zone).
    var x = 0;
    while (x < w && lum[x] >= thr) {
      x++;
    }
    if (x >= w - 10) return null;
    final runs = <int>[];
    var isBlack = true;
    var len = 0;
    for (; x < w; x++) {
      final black = lum[x] < thr;
      if (black == isBlack) {
        len++;
      } else {
        runs.add(len);
        isBlack = black;
        len = 1;
      }
    }
    runs.add(len);
    // Barcode Code128 selalu diakhiri bar hitam (bagian stop), jadi run
    // putih di ujung adalah quiet zone -> buang agar tak mengacaukan parse.
    if (!isBlack) {
      runs.removeLast();
    }
    if (runs.length < 20) return null;

    // Estimasi 1 modul dari simbol start (6 run pertama = 11 modul).
    // Jauh lebih stabil daripada min(run) yang rapuh terhadap rounding
    // 1-px saat render. Fallback: run tersempit.
    final moduleCandidates = <double>[
      runs.sublist(0, 6).reduce((a, b) => a + b) / 11.0,
      runs.reduce((a, b) => a < b ? a : b).toDouble(),
    ];
    for (final module in moduleCandidates) {
      final value = _decodeWithModule(runs: runs, module: module);
      if (value != null) return value;
    }
    return null;
  }

  static String? _decodeWithModule({
    required List<int> runs,
    required double module,
  }) {
    if (module < 1.0) return null;
    final q = runs.map((e) => (e / module).round()).toList();
    // Tidak ada cek rentang global di sini: pola yang tak valid otomatis
    // gagal di table lookup di bawah, dan checksum memverifikasi hasil akhir.

    // Simbol pertama harus Start A/B/C.
    final startCode = _lookup(q, 0);
    if (startCode == null) return null;
    if (startCode != _startA && startCode != _startB && startCode != _startC) {
      return null;
    }
    final start = startCode;

    final values = <int>[start];
    var pos = 6;
    while (true) {
      if (_isStop(q, pos)) break; // pola stop (7 run) -> selesai
      if (pos + 6 > q.length) return null;
      final v = _lookup(q, pos);
      if (v == null || v == _stop) return null;
      values.add(v);
      pos += 6;
      if (values.length > 60) return null; // terlalu panjang, pasti salah
    }

    // Verifikasi checksum: (start + Σ nilai_i × posisi_i) mod 103.
    var sum = values[0];
    for (var i = 1; i < values.length - 1; i++) {
      sum += values[i] * i;
    }
    if (sum % 103 != values.last) return null;

    // Konversi nilai -> string sesuai code set (dengan switch & shift).
    final sb = StringBuffer();
    var curSet = start == _startA ? 'A' : (start == _startB ? 'B' : 'C');
    var shift = false;
    for (var i = 1; i < values.length - 1; i++) {
      final v = values[i];
      final useSet = shift ? (curSet == 'A' ? 'B' : 'A') : curSet;
      shift = false;
      if (useSet == 'C') {
        // Di set C, 0-99 semuanya data (pasangan digit) — termasuk 96-99.
        // Fungsi yang valid di sini hanya switch set & FNC1.
        if (v == _codeB) {
          curSet = 'B';
          continue;
        }
        if (v == _codeA) {
          curSet = 'A';
          continue;
        }
        if (v == _fnc1) {
          sb.write('{1}');
          continue;
        }
        if (v < 0 || v > 99) return null;
        sb.write(v.toString().padLeft(2, '0'));
        continue;
      }
      // Set A/B: 96-102 adalah kode fungsi.
      if (v == _codeC) {
        curSet = 'C';
        continue;
      }
      if (v == _codeB) {
        curSet = 'B';
        continue;
      }
      if (v == _codeA) {
        curSet = 'A';
        continue;
      }
      if (v == _shift) {
        shift = true;
        continue;
      }
      if (v == _fnc1) {
        sb.write('{1}'); // marker FNC1 yang dimengerti package barcode
        continue;
      }
      if (v == _fnc2) {
        sb.write('{2}');
        continue;
      }
      if (v == _fnc3) {
        sb.write('{3}');
        continue;
      }
      if (useSet == 'B') {
        if (v < 0 || v > 95) return null;
        sb.writeCharCode(v + 32);
      } else {
        if (v < 0 || v > 95) return null;
        sb.writeCharCode(v < 64 ? v + 32 : v - 64);
      }
    }
    final result = sb.toString();
    return result.isEmpty ? null : result;
  }

  /// Nilai simbol dari 6 run pada [pos], atau null bila tak dikenal.
  static int? _lookup(List<int> q, int pos) {
    if (pos + 6 > q.length) return null;
    return _patternToValue[q.sublist(pos, pos + 6).join(',')];
  }

  /// true bila run pada [pos] cocok pola stop (7 run = 13 modul).
  static bool _isStop(List<int> q, int pos) {
    if (pos + 7 > q.length) return false;
    final want = kCode128Patterns[_stop];
    for (var i = 0; i < 7; i++) {
      if (q[pos + i] != want[i]) return false;
    }
    return true;
  }
}
