import 'package:flutter/material.dart';

import 'free_text_document.dart';

/// TextEditingController yang menampilkan [StyledDocument] sebagai
/// TextSpan berformat, sambil menjaga segmen tetap sinkron dengan teks.
///
/// Cara kerja:
/// - Setiap perubahan teks dihitung diff-nya (prefix/suffix bersama)
///   lalu dokumen di-patch lewat [StyledDocument.replaceRange].
///   Sisipan baru memakai gaya "pending" = gaya di posisi kursor.
/// - Toggle toolbar pada seleksi tak kosong memanggil [toggleAttribute]
///   yang meng-update dokumen + notifyListeners agar tampilan refresh.
/// - Bila seleksi kosong, toggle hanya mengubah gaya pending untuk
///   ketikan berikutnya (seperti editor pada umumnya).
///
/// Catatan: wilayah composing IME tidak ditangani khusus — teks
/// composing tetap tampil, hanya saja tanpa garis bawah IME.
/// Itu trade-off yang dapat diterima untuk v1.
class StyledTextController extends TextEditingController {
  StyledDocument _doc = StyledDocument.empty();
  FreeTextStyle _pending = const FreeTextStyle();

  /// true selama notifyListeners() dari [toggleAttribute] berjalan:
  /// listener sinkronisasi tidak boleh menimpa gaya pending yang baru
  /// saja di-toggle kembali ke gaya di posisi kursor.
  bool _suppressPendingUpdate = false;

  StyledTextController() {
    addListener(_syncDocument);
  }

  /// Dokumen berformat saat ini (teks polosnya == [text]).
  StyledDocument get document => _doc;

  /// Gaya untuk ketikan berikutnya saat kursor tidak menyeleksi apa-apa.
  FreeTextStyle get pendingStyle => _pending;

  void _syncDocument() {
    final newText = value.text;
    final oldText = _doc.plainText;
    if (newText == oldText) {
      // Hanya seleksi/kursor yang berubah → refresh gaya pending.
      _updatePendingFromSelection();
      return;
    }
    // Diff minimal: prefix bersama + suffix bersama.
    var start = 0;
    while (start < oldText.length &&
        start < newText.length &&
        oldText[start] == newText[start]) {
      start++;
    }
    var oldEnd = oldText.length;
    var newEnd = newText.length;
    while (oldEnd > start &&
        newEnd > start &&
        oldText[oldEnd - 1] == newText[newEnd - 1]) {
      oldEnd--;
      newEnd--;
    }
    final inserted = newText.substring(start, newEnd);
    _doc = _doc.replaceRange(start, oldEnd, inserted, _pending);
  }

  void _updatePendingFromSelection() {
    if (_suppressPendingUpdate) return;
    final sel = value.selection;
    if (!sel.isValid || !sel.isCollapsed) return;
    final pos = sel.baseOffset;
    if (_doc.isEmpty) {
      _pending = const FreeTextStyle();
    } else if (pos > 0) {
      _pending = _doc.styleAt(pos - 1);
    } else {
      _pending = _doc.styleAt(0);
    }
  }

  /// Apakah [attr] sedang aktif untuk toolbar:
  /// - seleksi tak kosong → aktif bila SEMUA karakter seleksi punya attr,
  /// - kursor saja → aktif bila gaya pending punya attr.
  bool isActive(FreeTextAttribute attr) {
    final sel = value.selection;
    if (sel.isValid && !sel.isCollapsed) {
      final s = sel.start < sel.end ? sel.start : sel.end;
      final e = sel.start < sel.end ? sel.end : sel.start;
      return _doc.allHave(s, e, attr);
    }
    return _pending.has(attr);
  }

  /// Toggle [attr]: pada seleksi (ubah dokumen) atau pada gaya pending
  /// (bila seleksi kosong, untuk ketikan berikutnya).
  void toggleAttribute(FreeTextAttribute attr) {
    final sel = value.selection;
    if (sel.isValid && !sel.isCollapsed) {
      final s = sel.start < sel.end ? sel.start : sel.end;
      final e = sel.start < sel.end ? sel.end : sel.start;
      _doc = _doc.toggleRange(s, e, attr);
    } else {
      _pending = _pending.withAttr(attr, !_pending.has(attr));
    }
    _suppressPendingUpdate = true;
    notifyListeners();
    _suppressPendingUpdate = false;
  }

  /// Hapus seluruh dokumen dan teks.
  void clearDocument() {
    _doc = StyledDocument.empty();
    _pending = const FreeTextStyle();
    clear();
  }

  @override
  TextSpan buildTextSpan(
      {required BuildContext context,
      TextStyle? style,
      required bool withComposing}) {
    final base = style ?? const TextStyle();
    if (_doc.isEmpty) {
      return TextSpan(style: base, text: value.text);
    }
    return TextSpan(
      style: base,
      children: _doc.segments
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
    );
  }
}
