/// Model dokumen teks berformat untuk tab "Teks Bebas".
///
/// Dokumen = daftar segmen, tiap segmen punya gaya seragam
/// (bold/italic/underline). Invarian yang dijaga:
/// - segmen tidak pernah kosong,
/// - dua segmen bersebelahan selalu berbeda gaya (digabung bila sama).
/// Teks polos = gabungan semua segmen.
///
/// File ini murni-Dart (tanpa Flutter) supaya bisa di-unit-test penuh.
/// Perataan adalah setelan satu dokumen (bukan per paragraf) — lebih
/// sederhana dan hasilnya mudah diprediksi di kertas thermal.
enum FreeTextAttribute { bold, italic, underline }

/// Gaya satu karakter: tiga flag on/off.
class FreeTextStyle {
  final bool bold;
  final bool italic;
  final bool underline;

  const FreeTextStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
  });

  bool has(FreeTextAttribute attr) => switch (attr) {
        FreeTextAttribute.bold => bold,
        FreeTextAttribute.italic => italic,
        FreeTextAttribute.underline => underline,
      };

  FreeTextStyle withAttr(FreeTextAttribute attr, bool value) =>
      switch (attr) {
        FreeTextAttribute.bold => FreeTextStyle(
            bold: value, italic: italic, underline: underline),
        FreeTextAttribute.italic => FreeTextStyle(
            bold: bold, italic: value, underline: underline),
        FreeTextAttribute.underline => FreeTextStyle(
            bold: bold, italic: italic, underline: value),
      };

  @override
  bool operator ==(Object other) =>
      other is FreeTextStyle &&
      bold == other.bold &&
      italic == other.italic &&
      underline == other.underline;

  @override
  int get hashCode => Object.hash(bold, italic, underline);
}

/// Satu potong teks bergaya seragam.
class StyledSegment {
  final String text;
  final FreeTextStyle style;

  const StyledSegment(this.text, [this.style = const FreeTextStyle()]);
}

/// Perataan seluruh dokumen.
enum FreeTextAlign { left, center, right }

/// Dokumen teks berformat. Semua operasi mengembalikan dokumen BARU
/// (immutable) — controller yang memakainya tinggal menukar referensi.
class StyledDocument {
  final List<StyledSegment> segments;

  const StyledDocument([this.segments = const []]);

  factory StyledDocument.empty() => const StyledDocument([]);

  factory StyledDocument.plain(String text,
          [FreeTextStyle style = const FreeTextStyle()]) =>
      text.isEmpty
          ? const StyledDocument([])
          : StyledDocument([StyledSegment(text, style)]);

  String get plainText => segments.map((s) => s.text).join();

  bool get isEmpty => plainText.isEmpty;

  /// Gaya karakter di [index]. Indeks di luar rentang dijepit ke
  /// segmen terdekat (ujung dokumen = gaya karakter terakhir).
  FreeTextStyle styleAt(int index) {
    if (segments.isEmpty) return const FreeTextStyle();
    var pos = 0;
    for (final s in segments) {
      if (index < pos + s.text.length) return s.style;
      pos += s.text.length;
    }
    return segments.last.style;
  }

  /// true bila SEMUA karakter dalam [start, end) punya [attr].
  /// Rentang kosong → false (tidak ada yang bisa di-toggle).
  bool allHave(int start, int end, FreeTextAttribute attr) {
    final len = plainText.length;
    var s = start.clamp(0, len);
    var e = end.clamp(0, len);
    if (s > e) {
      final t = s;
      s = e;
      e = t;
    }
    if (s >= e) return false;
    var pos = 0;
    for (final seg in segments) {
      final segStart = pos;
      final segEnd = pos + seg.text.length;
      if (segEnd > s && segStart < e && !seg.style.has(attr)) {
        return false;
      }
      pos = segEnd;
    }
    return true;
  }

  /// Toggle [attr] pada [start, end): bila semua karakter dalam rentang
  /// sudah punya atribut → hapus dari semua; bila tidak → tambah ke
  /// semua. Rentang kosong → dokumen tak berubah.
  StyledDocument toggleRange(int start, int end, FreeTextAttribute attr) {
    final len = plainText.length;
    var s = start.clamp(0, len);
    var e = end.clamp(0, len);
    if (s > e) {
      final t = s;
      s = e;
      e = t;
    }
    if (s >= e) return this;
    final setTo = !allHave(s, e, attr);
    return _mapRange(s, e, (style) => style.withAttr(attr, setTo));
  }

  /// Ganti [start, end) dengan [newText] bergaya [style].
  /// Dipakai untuk sinkronisasi ketikan: sisipan baru mendapat gaya
  /// "pending" (gaya di posisi kursor).
  StyledDocument replaceRange(
      int start, int end, String newText, FreeTextStyle style) {
    final len = plainText.length;
    var s = start.clamp(0, len);
    var e = end.clamp(0, len);
    if (s > e) {
      final t = s;
      s = e;
      e = t;
    }
    final before = <StyledSegment>[];
    final after = <StyledSegment>[];
    var pos = 0;
    for (final seg in segments) {
      final segStart = pos;
      final segEnd = pos + seg.text.length;
      if (segEnd <= s) {
        before.add(seg);
      } else if (segStart >= e) {
        after.add(seg);
      } else {
        // Segmen terpotong rentang: sisakan kepala/ekornya.
        if (segStart < s) {
          before.add(StyledSegment(
              seg.text.substring(0, s - segStart), seg.style));
        }
        if (segEnd > e) {
          after.add(
              StyledSegment(seg.text.substring(e - segStart), seg.style));
        }
      }
      pos = segEnd;
    }
    final merged = [...before];
    if (newText.isNotEmpty) merged.add(StyledSegment(newText, style));
    merged.addAll(after);
    return StyledDocument(_merge(merged));
  }

  /// Terapkan [f] pada gaya segmen yang bersinggungan dengan [s, e),
  /// dengan segmen dibelah tepat di batas rentang.
  StyledDocument _mapRange(
      int s, int e, FreeTextStyle Function(FreeTextStyle) f) {
    final out = <StyledSegment>[];
    var pos = 0;
    for (final seg in segments) {
      final segStart = pos;
      final segEnd = pos + seg.text.length;
      if (segEnd <= s || segStart >= e) {
        out.add(seg);
      } else {
        if (segStart < s) {
          out.add(StyledSegment(
              seg.text.substring(0, s - segStart), seg.style));
        }
        final midStart = (s - segStart).clamp(0, seg.text.length);
        final midEnd = (e - segStart).clamp(0, seg.text.length);
        out.add(StyledSegment(
            seg.text.substring(midStart, midEnd), f(seg.style)));
        if (segEnd > e) {
          out.add(
              StyledSegment(seg.text.substring(e - segStart), seg.style));
        }
      }
      pos = segEnd;
    }
    return StyledDocument(_merge(out));
  }

  /// Buang segmen kosong dan gabung segmen bersebelahan yang gayanya sama.
  static List<StyledSegment> _merge(List<StyledSegment> segs) {
    final out = <StyledSegment>[];
    for (final s in segs) {
      if (s.text.isEmpty) continue;
      if (out.isNotEmpty && out.last.style == s.style) {
        final last = out.removeLast();
        out.add(StyledSegment(last.text + s.text, last.style));
      } else {
        out.add(s);
      }
    }
    return out;
  }
}
