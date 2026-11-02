import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/app_errors.dart';
import '../services/bluetooth_printer_service.dart';
import '../services/escpos_builder.dart';
import '../services/free_text_controller.dart';
import '../services/free_text_document.dart';
import '../services/free_text_render.dart';
import '../services/image_pipeline.dart';

/// Tab "Teks Bebas": editor teks sederhana (bold/italic/underline,
/// perataan, ukuran huruf) dengan tombol cetak langsung.
///
/// State dipertahankan saat pindah tab (AutomaticKeepAliveClientMixin)
/// supaya ketikan tidak hilang. Teks hanya hidup di memori selama
/// aplikasi berjalan (tanpa simpan/muat di v1).
class FreeTextTab extends StatefulWidget {
  const FreeTextTab({super.key, required this.paperDots, required this.bt});

  /// Lebar cetak kertas aktif dalam dots (dari tab Pengaturan).
  final int paperDots;

  final BluetoothPrinterService bt;

  @override
  State<FreeTextTab> createState() => _FreeTextTabState();
}

class _FreeTextTabState extends State<FreeTextTab>
    with AutomaticKeepAliveClientMixin {
  late final StyledTextController _controller;
  double _fontSize = 28;
  FreeTextAlign _alignment = FreeTextAlign.left;
  bool _printing = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = StyledTextController();
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  AppLocalizations get l => AppLocalizations.of(context)!;

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  /// Pesan error siap tampil (subset dari _localizedError home_screen:
  /// hanya error yang mungkin terjadi saat cetak teks bebas).
  String _localizedError(Object e) {
    return switch (e) {
      BluetoothWriteFailed f => l.btWriteFailed(f.byteCount),
      BluetoothPermissionDenied _ => l.btPermissionDenied,
      _ => e.toString().replaceFirst(RegExp(r'^Exception: '), ''),
    };
  }

  Future<void> _printFreeText() async {
    final doc = _controller.document;
    if (doc.plainText.trim().isEmpty) {
      _snack(l.freeTextEmpty, error: true);
      return;
    }
    setState(() => _printing = true);
    try {
      if (!await widget.bt.isConnected) {
        throw Exception(l.printerDisconnected);
      }
      final image = await FreeTextRenderer.render(
        doc: doc,
        widthPx: widget.paperDots,
        fontSize: _fontSize,
        alignment: _alignment,
      );
      // Teks murni hitam-putih: threshold keras sudah cukup, tanpa
      // dithering (dithering hanya membantu foto/gambar bergradasi).
      final raster = ImagePipeline.toRasterBytes(image);
      final job = EscPosBuilder.buildImageJob(
        raster: raster,
        widthBytes: widget.paperDots ~/ 8,
        height: image.height,
      );
      await widget.bt.writeBytes(job);
      _snack(l.printSuccess);
    } catch (e) {
      _snack(l.printFailed(_localizedError(e)), error: true);
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // wajib untuk AutomaticKeepAliveClientMixin
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlign: switch (_alignment) {
                FreeTextAlign.left => TextAlign.left,
                FreeTextAlign.center => TextAlign.center,
                FreeTextAlign.right => TextAlign.right,
              },
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(fontSize: _fontSize),
              decoration: InputDecoration(
                hintText: l.freeTextHint,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _printing ? null : _printFreeText,
                  icon: const Icon(Icons.print),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _printing ? l.printingButton : l.freeTextPrintButton,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed:
                    _printing ? null : _controller.clearDocument,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(l.freeTextClear),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Toolbar: B/I/U + perataan + slider ukuran huruf.
  Widget _toolbar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _formatToggle(
                  FreeTextAttribute.bold,
                  'B',
                  const TextStyle(fontWeight: FontWeight.bold),
                  l.freeTextBold,
                ),
                _formatToggle(
                  FreeTextAttribute.italic,
                  'I',
                  const TextStyle(fontStyle: FontStyle.italic),
                  l.freeTextItalic,
                ),
                _formatToggle(
                  FreeTextAttribute.underline,
                  'U',
                  const TextStyle(decoration: TextDecoration.underline),
                  l.freeTextUnderline,
                ),
                const SizedBox(width: 8),
                _alignButton(
                  FreeTextAlign.left,
                  Icons.format_align_left,
                  l.freeTextAlignLeft,
                ),
                _alignButton(
                  FreeTextAlign.center,
                  Icons.format_align_center,
                  l.freeTextAlignCenter,
                ),
                _alignButton(
                  FreeTextAlign.right,
                  Icons.format_align_right,
                  l.freeTextAlignRight,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(l.freeTextFontSize),
                Expanded(
                  child: Slider(
                    value: _fontSize,
                    min: 20,
                    max: 48,
                    divisions: 28,
                    label: _fontSize.round().toString(),
                    onChanged: (v) => setState(() => _fontSize = v),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    _fontSize.round().toString(),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Tombol toggle format (B/I/U) dengan status aktif yang terlihat.
  Widget _formatToggle(FreeTextAttribute attr, String label,
      TextStyle labelStyle, String tooltip) {
    final active = _controller.isActive(attr);
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: InkWell(
          onTap: () => _controller.toggleAttribute(attr),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: active ? scheme.primaryContainer : null,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(label,
                style: labelStyle.copyWith(fontSize: 18)),
          ),
        ),
      ),
    );
  }

  /// Tombol perataan (satu setelan untuk seluruh dokumen).
  Widget _alignButton(
      FreeTextAlign align, IconData icon, String tooltip) {
    final active = _alignment == align;
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: InkWell(
          onTap: () => setState(() => _alignment = align),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: active ? scheme.primaryContainer : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 22),
          ),
        ),
      ),
    );
  }
}
