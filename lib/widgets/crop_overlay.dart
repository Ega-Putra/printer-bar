import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/image_pipeline.dart';

/// Editor crop: menampilkan gambar + overlay persegi yang bisa
/// digeser (seret bagian tengah) dan diubah ukurannya (seret sudut).
/// Seret di luar kotak untuk menggambar kotak baru.
///
/// [box] dalam koordinat piksel gambar asli. [onBoxChanged] dipanggil
/// setiap ada perubahan selama gesture.
class CropEditor extends StatefulWidget {
  final Uint8List imageBytes;
  final int imageWidth;
  final int imageHeight;
  final Box box;
  final ValueChanged<Box> onBoxChanged;

  /// Dipanggil true saat drag crop dimulai, false saat selesai.
  /// Induk memakai ini untuk mengunci scroll halaman selama drag,
  /// supaya halaman tidak ikut terscroll saat box digerakkan.
  final ValueChanged<bool>? onDragging;

  const CropEditor({
    super.key,
    required this.imageBytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.box,
    required this.onBoxChanged,
    this.onDragging,
  });

  @override
  State<CropEditor> createState() => _CropEditorState();
}

enum _DragMode { none, move, corner0, corner1, corner2, corner3, draw }

class _CropEditorState extends State<CropEditor> {
  /// Box live dalam koordinat piksel gambar.
  late Box _live;
  _DragMode _mode = _DragMode.none;

  // State gesture (dalam piksel layar).
  Offset _grabOffset = Offset.zero;
  Offset _moveAnchor = Offset.zero;
  Box _moveStart = const Box(0, 0, 0, 0);
  Offset _drawAnchor = Offset.zero;

  // Pemetaan gambar -> layar, dihitung tiap build.
  double _scale = 1;
  double _dx = 0;
  double _dy = 0;

  static const double _minBox = 24; // ukuran box minimum (px gambar)
  static const double _hitRadius = 28; // radius sentuh handle (px layar)

  @override
  void initState() {
    super.initState();
    _live = widget.box;
  }

  int get _iw => widget.imageWidth;
  int get _ih => widget.imageHeight;

  Offset _toDisplay(Offset img) =>
      Offset(_dx + img.dx * _scale, _dy + img.dy * _scale);

  Offset _toImage(Offset disp) =>
      Offset((disp.dx - _dx) / _scale, (disp.dy - _dy) / _scale);

  Offset _clampImage(Offset p) => Offset(
        p.dx.clamp(0.0, _iw.toDouble()),
        p.dy.clamp(0.0, _ih.toDouble()),
      );

  List<Offset> _cornersDisplay() => [
        _toDisplay(Offset(_live.left, _live.top)),
        _toDisplay(Offset(_live.right, _live.top)),
        _toDisplay(Offset(_live.right, _live.bottom)),
        _toDisplay(Offset(_live.left, _live.bottom)),
      ];

  Box _normalized(Offset a, Offset b) => Box(
        math.min(a.dx, b.dx),
        math.min(a.dy, b.dy),
        math.max(a.dx, b.dx),
        math.max(a.dy, b.dy),
      );

  Box _resizeCorner(int corner, Offset imgPt) {
    var l = _live.left, t = _live.top, r = _live.right, b = _live.bottom;
    switch (corner) {
      case 0: // kiri-atas
        l = math.min(imgPt.dx, r - _minBox);
        t = math.min(imgPt.dy, b - _minBox);
      case 1: // kanan-atas
        r = math.max(imgPt.dx, l + _minBox);
        t = math.min(imgPt.dy, b - _minBox);
      case 2: // kanan-bawah
        r = math.max(imgPt.dx, l + _minBox);
        b = math.max(imgPt.dy, t + _minBox);
      case 3: // kiri-bawah
        l = math.min(imgPt.dx, r - _minBox);
        b = math.max(imgPt.dy, t + _minBox);
    }
    return Box(
      l.clamp(0.0, _iw.toDouble()),
      t.clamp(0.0, _ih.toDouble()),
      r.clamp(0.0, _iw.toDouble()),
      b.clamp(0.0, _ih.toDouble()),
    );
  }

  void _onPointerDown(PointerDownEvent e) {
    final p = e.localPosition;
    final corners = _cornersDisplay();
    for (var i = 0; i < 4; i++) {
      if ((p - corners[i]).distance <= _hitRadius) {
        _mode = _DragMode.values[_DragMode.corner0.index + i];
        _grabOffset = corners[i] - p;
        widget.onDragging?.call(true);
        return;
      }
    }
    final tl = corners[0];
    final br = corners[2];
    final inside = p.dx >= tl.dx &&
        p.dx <= br.dx &&
        p.dy >= tl.dy &&
        p.dy <= br.dy;
    if (inside) {
      _mode = _DragMode.move;
      _moveAnchor = p;
      _moveStart = _live;
    } else {
      _mode = _DragMode.draw;
      _drawAnchor = _clampImage(_toImage(p));
      _live = Box(
          _drawAnchor.dx, _drawAnchor.dy, _drawAnchor.dx, _drawAnchor.dy);
      _notify();
    }
    widget.onDragging?.call(true);
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_mode == _DragMode.none) return;
    final p = e.localPosition;
    switch (_mode) {
      case _DragMode.none:
        return;
      case _DragMode.move:
        final delta = (p - _moveAnchor) / _scale;
        final w = _moveStart.width;
        final h = _moveStart.height;
        final nl =
            (_moveStart.left + delta.dx).clamp(0.0, _iw.toDouble() - w);
        final nt =
            (_moveStart.top + delta.dy).clamp(0.0, _ih.toDouble() - h);
        _live = Box(nl, nt, nl + w, nt + h);
      case _DragMode.corner0:
      case _DragMode.corner1:
      case _DragMode.corner2:
      case _DragMode.corner3:
        final corner = _mode.index - _DragMode.corner0.index;
        _live = _resizeCorner(corner, _clampImage(_toImage(p + _grabOffset)));
      case _DragMode.draw:
        _live = _normalized(_drawAnchor, _clampImage(_toImage(p)));
    }
    _notify();
  }

  void _onPointerEnd(PointerEvent _) {
    if (_mode != _DragMode.none) {
      _mode = _DragMode.none;
      widget.onDragging?.call(false);
    }
  }

  @override
  void dispose() {
    // Pengaman: jangan biarkan scroll induk terkunci bila widget
    // dilepas di tengah drag.
    if (_mode != _DragMode.none) widget.onDragging?.call(false);
    super.dispose();
  }

  void _notify() {
    setState(() {});
    widget.onBoxChanged(_live);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availW = constraints.maxWidth;
        final availH = constraints.maxHeight;
        _scale = math.min(availW / _iw, availH / _ih);
        final dw = _iw * _scale;
        final dh = _ih * _scale;
        _dx = (availW - dw) / 2;
        _dy = (availH - dh) / 2;

        final c = _cornersDisplay();
        final displayBox =
            Rect.fromPoints(c[0], c[2]);

        // Listener (bukan GestureDetector): event pointer mentah tidak
        // berkompetisi di gesture arena dengan SingleChildScrollView
        // induk, jadi drag crop selalu responsif. Scroll induk dikunci
        // via onDragging selama jari menyentuh area ini.
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerEnd,
          onPointerCancel: _onPointerEnd,
          child: Stack(
            children: [
              Positioned(
                left: _dx,
                top: _dy,
                width: dw,
                height: dh,
                child: Image.memory(
                  widget.imageBytes,
                  width: dw,
                  height: dh,
                  fit: BoxFit.fill,
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _CropPainter(displayBox),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Menggambar area gelap di luar kotak + bingkai + handle sudut.
class _CropPainter extends CustomPainter {
  final Rect box;

  _CropPainter(this.box);

  @override
  void paint(Canvas canvas, Size size) {
    // Gelapkan luar kotak.
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(box)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      path,
      Paint()..color = Colors.black54,
    );
    // Bingkai putih.
    canvas.drawRect(
      box,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
    // Handle sudut.
    const hs = 16.0;
    final fill = Paint()..color = Colors.white;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.black87;
    for (final c in [
      box.topLeft,
      box.topRight,
      box.bottomRight,
      box.bottomLeft,
    ]) {
      final r = Rect.fromCenter(center: c, width: hs, height: hs);
      canvas.drawRect(r, fill);
      canvas.drawRect(r, stroke);
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.box != box;
}
