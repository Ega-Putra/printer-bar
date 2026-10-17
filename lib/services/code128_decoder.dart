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

  /// Decode dari area [box]. Bila gagal, cari ke seluruh gambar.
  static String? decode(img.Image src, Box box) {
    // Varian box: asli, diperlebar 25%, masing-masing 1x dan 2x upscale.
    final boxes = <Box>[box];
    final ex = box.width * 0.25, ey = box.height * 0.25;
    boxes.add(Box(
      (box.left - ex).clamp(0.0, src.width.toDouble()),
      (box.top - ey).clamp(0.0, src.height.toDouble()),
      (box.right + ex).clamp(0.0, src.width.toDouble()),
      (box.bottom + ey).clamp(0.0, src.height.toDouble()),
    ));
    for (final upscale in [false, true]) {
      for (final b in boxes) {
        final value = _decodeBox(src, b, upscale: upscale);
        if (value != null) return value;
      }
    }
    // Fallback terakhir: cari ke seluruh gambar (box bisa salah).
    return decodeFullImage(src);
  }

  /// Cari & decode Code128 di seluruh [src] tanpa mengandalkan box.
  static String? decodeFullImage(img.Image src) {
    final gray = img.grayscale(src);
    final w = gray.width, h = gray.height;
    if (w < 100 || h < 40) return null;
    // Pindai tiap 12px; prioritaskan area tengah dulu.
    for (var y0 = h ~/ 4; y0 < h * 3 ~/ 4; y0 += 12) {
      final value = _searchLine(gray, w, h, y0);
      if (value != null) return value;
    }
    for (var y0 = 8; y0 < h ~/ 4; y0 += 12) {
      final value = _searchLine(gray, w, h, y0);
      if (value != null) return value;
    }
    for (var y0 = h * 3 ~/ 4; y0 < h - 8; y0 += 12) {
      final value = _searchLine(gray, w, h, y0);
      if (value != null) return value;
    }
    return null;
  }

  /// Cari pola start pada baris [y0] di seluruh lebar gambar.
  static String? _searchLine(img.Image gray, int w, int h, int y0) {
    final lum = List<double>.filled(w, 0);
    var rows = 0;
    for (var y = y0 - 1; y <= y0 + 1; y++) {
      if (y < 0 || y >= h) continue;
      rows++;
      for (var x = 0; x < w; x++) {
        lum[x] += gray.getPixel(x, y).r.toDouble();
      }
    }
    if (rows == 0) return null;
    var minL = double.infinity, maxL = 0.0;
    for (var x = 0; x < w; x++) {
      lum[x] /= rows;
      if (lum[x] < minL) minL = lum[x];
      if (lum[x] > maxL) maxL = lum[x];
    }
    if (maxL - minL < 40) return null;
    final thr = (minL + maxL) / 2;

    // Semua run pada baris ini.
    final runs = <int>[];
    final blacks = <bool>[];
    var isBlack = lum[0] < thr;
    var len = 0;
    for (var x = 0; x < w; x++) {
      final black = lum[x] < thr;
      if (black == isBlack) {
        len++;
      } else {
        runs.add(len);
        blacks.add(isBlack);
        isBlack = black;
        len = 1;
      }
    }
    runs.add(len);
    blacks.add(isBlack);
    if (runs.length < 20) return null;

    // Coba tiap posisi run hitam sebagai awal start.
    for (var s = 0; s < runs.length - 12; s++) {
      if (!blacks[s]) continue;
      final m6 = runs.sublist(s, s + 6).reduce((a, b) => a + b) / 11.0;
      if (m6 < 1.5) continue;
      final q = <int>[];
      for (var i = s; i < runs.length; i++) {
        q.add((runs[i] / m6).round());
      }
      final startCode = _lookup(q, 0);
      if (startCode == null ||
          (startCode != _startA &&
              startCode != _startB &&
              startCode != _startC)) {
        continue;
      }
      final value = _decodeSymbols(q, startCode);
      if (value != null) return value;
    }
    return null;
  }

  static String? _decodeBox(img.Image src, Box box, {required bool upscale}) {
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
    for (final fy in [0.35, 0.5, 0.65]) {
      final value = _decodeScanline(gray, w, h, fy);
      if (value != null) return value;
    }
    return null;
  }

  static String? _decodeScanline(img.Image gray, int w, int h, double fy) {
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
    if (maxL - minL < 40) return null;
    final thr = (minL + maxL) / 2;

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
    if (!isBlack) runs.removeLast(); // buang quiet zone kanan
    if (runs.length < 20) return null;

    for (final module in [
      runs.sublist(0, 6).reduce((a, b) => a + b) / 11.0,
      runs.reduce((a, b) => a < b ? a : b).toDouble(),
    ]) {
      if (module < 1.0) continue;
      final q = runs.map((e) => (e / module).round()).toList();
      final startCode = _lookup(q, 0);
      if (startCode == null ||
          (startCode != _startA &&
              startCode != _startB &&
              startCode != _startC)) {
        continue;
      }
      final value = _decodeSymbols(q, startCode);
      if (value != null) return value;
    }
    return null;
  }

  /// Parse simbol dari [q] (ter-quantize) mulai dengan [start] yang valid.
  /// Verifikasi checksum lalu konversi ke string.
  static String? _decodeSymbols(List<int> q, int start) {
    final values = <int>[start];
    var pos = 6;
    while (true) {
      if (_isStop(q, pos)) break;
      if (pos + 6 > q.length) return null;
      final v = _lookup(q, pos);
      if (v == null || v == _stop) return null;
      values.add(v);
      pos += 6;
      if (values.length > 60) return null;
    }
    // Checksum: (start + Σ nilai_i × posisi_i) mod 103.
    var sum = values[0];
    for (var i = 1; i < values.length - 1; i++) {
      sum += values[i] * i;
    }
    if (sum % 103 != values.last) return null;

    final sb = StringBuffer();
    var curSet = start == _startA ? 'A' : (start == _startB ? 'B' : 'C');
    var shift = false;
    for (var i = 1; i < values.length - 1; i++) {
      final v = values[i];
      final useSet = shift ? (curSet == 'A' ? 'B' : 'A') : curSet;
      shift = false;
      if (useSet == 'C') {
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
        sb.write('{1}');
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

  static int? _lookup(List<int> q, int pos) {
    if (pos + 6 > q.length) return null;
    return _patternToValue[q.sublist(pos, pos + 6).join(',')];
  }

  static bool _isStop(List<int> q, int pos) {
    if (pos + 7 > q.length) return false;
    final want = kCode128Patterns[_stop];
    for (var i = 0; i < 7; i++) {
      if (q[pos + i] != want[i]) return false;
    }
    return true;
  }
}
