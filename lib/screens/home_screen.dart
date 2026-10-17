import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../models/paper_size.dart';
import '../services/barcode_service.dart';
import '../services/bluetooth_printer_service.dart';
import '../services/escpos_builder.dart';
import '../services/image_pipeline.dart';
import '../services/pdf_service.dart';
import '../widgets/crop_overlay.dart';
import '../widgets/device_tile.dart';

/// Dua mode cetak yang tersedia.
enum PrintMode {
  /// Cetak tiap halaman apa adanya, diskala selebar kertas.
  asli,

  /// Cetak tiap halaman + barcode terbesarnya diperbesar selebar kertas
  /// di bawah gambar halaman.
  barcodeDiperbesar,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _pdf = PdfService();
  final _barcodes = BarcodeService();
  final _bt = BluetoothPrinterService();
  StreamSubscription<List<SharedMediaFile>>? _intentSub;

  PaperSize _paper = PaperSize.mm58;
  PrintMode _mode = PrintMode.asli;

  /// true = barcode dicetak vertikal (diputar 90°), false = horizontal.
  bool _barcodeVertical = false;

  String? _pdfPath;
  String? _pdfName;
  List<RenderedPage> _pages = [];
  int _previewIndex = 0;
  bool _loadingPdf = false;

  /// Area crop per indeks halaman (koordinat piksel gambar render).
  /// Default = seluruh halaman.
  final Map<int, Box> _crops = {};

  /// Hasil deteksi per indeks halaman dalam koordinat gambar render
  /// PENUH (sebelum crop): barcode terbesar, atau null bila tak ada.
  final Map<int, DetectedBarcode?> _detections = {};
  bool _detecting = false;

  List<PrinterDevice> _devices = [];
  bool _scanning = false;
  PrinterDevice? _connected;
  bool _connectingMac = false;

  /// Subscription hasil discovery + timer timeout pengaman.
  StreamSubscription<PrinterDevice?>? _discoverySub;
  Timer? _scanTimer;

  bool _printing = false;
  String? _progress;

  @override
  void initState() {
    super.initState();
    // PDF yang di-share dari aplikasi lain saat aplikasi sudah jalan.
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleSharedFiles,
      onError: (Object e) =>
          _snack('Gagal menerima share: $e', error: true),
    );
    // PDF yang di-share saat aplikasi masih tertutup (cold start).
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) _handleSharedFiles(files);
      ReceiveSharingIntent.instance.reset();
    });
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    _discoverySub?.cancel();
    _scanTimer?.cancel();
    _bt.cancelDiscovery();
    _barcodes.dispose();
    super.dispose();
  }

  /// Deteksi efektif untuk halaman [pageIndex]: hasil deteksi yang sudah
  /// digeser ke koordinat gambar ter-crop. Null bila halaman tak punya
  /// barcode ATAU barcode-nya di luar area crop.
  DetectedBarcode? _effectiveDetection(int pageIndex) {
    final det = _detections[pageIndex];
    if (det == null) return null;
    final crop = _crops[pageIndex];
    if (crop == null) return det;
    final tb = ImagePipeline.translateBox(det.box, crop);
    if (tb == null) return null;
    return DetectedBarcode(box: tb, rawValue: det.rawValue);
  }

  bool get _canPrint =>
      _pages.isNotEmpty &&
      _connected != null &&
      !_printing &&
      !_loadingPdf &&
      (_mode == PrintMode.asli ||
          (_detections.length == _pages.length &&
              List.generate(_pages.length, _effectiveDetection)
                  .every((d) => d != null)));

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  String _errMsg(Object e) {
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }

  // ---------- Share intent ----------

  void _handleSharedFiles(List<SharedMediaFile> files) {
    SharedMediaFile? pdf;
    for (final f in files) {
      if (f.path.toLowerCase().endsWith('.pdf')) {
        pdf = f;
        break;
      }
    }
    if (pdf == null) return;
    if (!File(pdf.path).existsSync()) {
      _snack('Berkas PDF yang di-share tidak bisa dibaca.', error: true);
      return;
    }
    _loadPdfFromPath(pdf.path, name: pdf.path.split('/').last);
  }

  // ---------- PDF ----------

  Future<void> _pickPdf() async {
    if (_loadingPdf) return;
    setState(() {
      _loadingPdf = true;
      _progress = 'Membuka pemilih berkas...';
    });
    String? path;
    try {
      path = await _pdf.pickPdf();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingPdf = false;
          _progress = null;
        });
        _snack('Gagal membuka pemilih berkas: ${_errMsg(e)}', error: true);
      }
      return;
    }
    if (path == null) {
      // Pengguna batal.
      if (mounted) {
        setState(() {
          _loadingPdf = false;
          _progress = null;
        });
      }
      return;
    }
    await _loadPdfFromPath(path, name: path.split('/').last);
  }

  /// Muat & render PDF dari [path] (dipakai pemilih berkas maupun share).
  Future<void> _loadPdfFromPath(String path, {required String name}) async {
    if (_loadingPdf) return;
    setState(() {
      _loadingPdf = true;
      _progress = 'Me-render PDF...';
    });
    try {
      // Render 2x lebar cetak agar deteksi barcode akurat.
      final pages =
          await _pdf.renderPages(path, renderWidth: _paper.dots * 2);
      if (!mounted) return;
      setState(() {
        _pdfPath = path;
        _pdfName = name;
        _pages = pages;
        _previewIndex = 0;
        _detections.clear();
        _crops.clear();
        for (var i = 0; i < pages.length; i++) {
          _crops[i] = Box(
            0,
            0,
            pages[i].width.toDouble(),
            pages[i].height.toDouble(),
          );
        }
      });
      if (_mode == PrintMode.barcodeDiperbesar) {
        await _detectBarcodes();
      }
    } catch (e) {
      _snack('Gagal memuat PDF: ${_errMsg(e)}', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _loadingPdf = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _onPaperChanged(PaperSize paper) async {
    if (paper == _paper) return;
    setState(() => _paper = paper);
    // Resolusi render mengikuti ukuran kertas → render ulang bila PDF ada.
    final path = _pdfPath;
    final name = _pdfName;
    if (path != null && name != null && _pages.isNotEmpty) {
      await _loadPdfFromPath(path, name: name);
    }
  }

  void _resetCrop() {
    final page = _pages[_previewIndex];
    setState(() {
      _crops[_previewIndex] = Box(
        0,
        0,
        page.width.toDouble(),
        page.height.toDouble(),
      );
    });
  }

  // ---------- Mode & deteksi barcode ----------

  Future<void> _onModeChanged(PrintMode mode) async {
    setState(() => _mode = mode);
    if (mode == PrintMode.barcodeDiperbesar &&
        _pages.isNotEmpty &&
        _detections.isEmpty &&
        !_detecting) {
      await _detectBarcodes();
    }
  }

  Future<void> _detectBarcodes() async {
    setState(() {
      _detecting = true;
      _detections.clear();
    });
    try {
      for (var i = 0; i < _pages.length; i++) {
        List<DetectedBarcode> found;
        try {
          found = await _barcodes.detect(_pages[i].path);
        } catch (e) {
          if (!mounted) return;
          _snack('Deteksi barcode halaman ${i + 1} gagal: ${_errMsg(e)}',
              error: true);
          found = [];
        }
        if (!mounted) return;
        setState(() => _detections[i] = _barcodes.largest(found));
      }
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  // ---------- Bluetooth ----------

  /// Pindai perangkat Bluetooth yang AKTIF terdeteksi di sekitar
  /// (discovery klasik) — bukan daftar riwayat pairing. Tap lagi untuk
  /// berhenti; berhenti otomatis setelah 15 detik.
  Future<void> _scanDevices() async {
    if (_scanning) {
      await _stopScan();
      return;
    }
    setState(() {
      _scanning = true;
      _devices = [];
    });
    try {
      await _bt.ensurePermissions();
      final on = await _bt.bluetoothOn;
      if (!on) {
        throw Exception(
            'Bluetooth HP mati. Nyalakan Bluetooth dulu, lalu pindai lagi.');
      }
      await _discoverySub?.cancel();
      _discoverySub = _bt.discoveryStream().listen(
        (device) {
          if (!mounted) return;
          if (device == null) {
            // Discovery selesai (timeout sistem ±12 detik).
            _finishScan();
            return;
          }
          setState(() {
            _devices = BluetoothPrinterService.dedupe([..._devices, device]);
          });
        },
        onError: (Object e) {
          _snack('Gagal memindai: ${_errMsg(e)}', error: true);
          _finishScan();
        },
      );
      final started = await _bt.startDiscovery();
      if (!started) {
        throw Exception(
            'Gagal memulai pemindaian Bluetooth. Pastikan Bluetooth menyala.');
      }
      // Timeout pengaman bila event "finished" tak kunjung datang.
      _scanTimer?.cancel();
      _scanTimer = Timer(const Duration(seconds: 15), () {
        if (mounted && _scanning) _finishScan(showEmptyHint: true);
      });
    } catch (e) {
      _snack(_errMsg(e), error: true);
      _finishScan();
    }
  }

  Future<void> _stopScan() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    await _discoverySub?.cancel();
    _discoverySub = null;
    await _bt.cancelDiscovery();
    if (mounted) setState(() => _scanning = false);
  }

  void _finishScan({bool showEmptyHint = false}) {
    _scanTimer?.cancel();
    _scanTimer = null;
    _discoverySub?.cancel();
    _discoverySub = null;
    _bt.cancelDiscovery();
    if (!mounted) return;
    setState(() => _scanning = false);
    if (_devices.isEmpty && showEmptyHint) {
      _snack('Tidak ada perangkat terdeteksi. Pastikan printer menyala '
          'dan berada di dekat HP.');
    }
  }

  Future<void> _connect(PrinterDevice device) async {
    if (_connectingMac) return;
    setState(() => _connectingMac = true);
    try {
      await _bt.connect(device);
      if (!mounted) return;
      setState(() => _connected = device);
      _snack('Terhubung ke "${device.name}"');
    } catch (e) {
      _snack(_errMsg(e), error: true);
    } finally {
      if (mounted) setState(() => _connectingMac = false);
    }
  }

  Future<void> _disconnect() async {
    await _bt.disconnect();
    if (!mounted) return;
    setState(() => _connected = null);
    _snack('Koneksi printer diputus');
  }

  // ---------- Cetak ----------

  /// Bangun gambar final siap cetak untuk halaman [pageIndex]:
  /// crop user → skala ke lebar kertas → opsional barcode diperbesar.
  img.Image _composePage(int pageIndex, int dots) {
    final pageImg = ImagePipeline.decode(_pages[pageIndex].bytes);
    final cropBox = _crops[pageIndex] ??
        Box(0, 0, pageImg.width.toDouble(), pageImg.height.toDouble());
    final cropped = ImagePipeline.crop(pageImg, cropBox);
    final pageForPrint = ImagePipeline.scaleToWidth(cropped, dots);

    if (_mode == PrintMode.asli) return pageForPrint;

    final det = _effectiveDetection(pageIndex);
    if (det == null) {
      // Seharusnya tak terjadi karena tombol Cetak dinonaktifkan,
      // tapi tetap dijaga agar tak pernah mencetak layout yang salah.
      if (_detections[pageIndex] == null) {
        throw Exception('Barcode tidak ditemukan di halaman ${pageIndex + 1}.');
      }
      throw Exception('Barcode di luar area crop halaman ${pageIndex + 1}.');
    }
    final padded =
        ImagePipeline.paddedCrop(det.box, cropped.width, cropped.height);
    var barcodeImg =
        ImagePipeline.cropAndScaleToWidth(cropped, padded, dots);
    if (_barcodeVertical) {
      barcodeImg = ImagePipeline.padToWidth(
        ImagePipeline.rotate90Clockwise(barcodeImg),
        dots,
      );
    }
    return ImagePipeline.composeVertical([pageForPrint, barcodeImg]);
  }

  Future<void> _print() async {
    if (!_canPrint) return;
    setState(() {
      _printing = true;
      _progress = 'Menyiapkan...';
    });
    try {
      if (!await _bt.isConnected) {
        throw Exception('Printer terputus. Hubungkan ulang dulu.');
      }
      final dots = _paper.dots;
      for (var i = 0; i < _pages.length; i++) {
        if (!mounted) return;
        setState(
            () => _progress = 'Mencetak halaman ${i + 1}/${_pages.length}...');
        final finalImg = _composePage(i, dots);
        final raster = ImagePipeline.toRasterBytes(finalImg);
        final job = EscPosBuilder.buildImageJob(
          raster: raster,
          widthBytes: dots ~/ 8,
          height: finalImg.height,
        );
        await _bt.writeBytes(job);
      }
      _snack('Berhasil dicetak 🎉');
    } catch (e) {
      _snack('Gagal mencetak: ${_errMsg(e)}', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _printing = false;
          _progress = null;
        });
      }
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cetak Thermal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _paperCard(),
            const SizedBox(height: 12),
            _pdfCard(),
            if (_pages.isNotEmpty) ...[
              const SizedBox(height: 12),
              _previewCard(),
            ],
            const SizedBox(height: 12),
            _modeCard(),
            const SizedBox(height: 12),
            _bluetoothCard(),
            const SizedBox(height: 16),
            _printButton(),
            if (_progress != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(_progress!),
                ],
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _paperCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ukuran Kertas',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            SegmentedButton<PaperSize>(
              segments: [
                for (final p in PaperSize.values)
                  ButtonSegment(value: p, label: Text(p.label)),
              ],
              selected: {_paper},
              onSelectionChanged: (s) => _onPaperChanged(s.first),
            ),
            const SizedBox(height: 4),
            Text(
              'Lebar cetak: ${_paper.dots} dots @ 203 dpi',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pdfCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Resi PDF',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              'Bisa juga via Share > Cetak Thermal dari aplikasi lain.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loadingPdf ? null : _pickPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Pilih PDF'),
            ),
            if (_pdfName != null) ...[
              const SizedBox(height: 8),
              Text('📄 $_pdfName'),
              Text('${_pages.length} halaman',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget _previewCard() {
    final page = _pages[_previewIndex];
    final crop = _crops[_previewIndex] ??
        Box(0, 0, page.width.toDouble(), page.height.toDouble());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Pratinjau & Crop',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _resetCrop,
                  icon: const Icon(Icons.crop_free, size: 18),
                  label: const Text('Reset'),
                ),
              ],
            ),
            const Text(
              'Seret sudut untuk ubah area • seret tengah untuk pindah • '
              'seret di luar kotak untuk gambar baru',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Container(
              height: 340,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                color: Colors.black12,
              ),
              child: CropEditor(
                key: ValueKey('crop_$_previewIndex'),
                imageBytes: page.bytes,
                imageWidth: page.width,
                imageHeight: page.height,
                box: crop,
                onBoxChanged: (b) =>
                    setState(() => _crops[_previewIndex] = b),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _previewIndex = i),
                    child: Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _previewIndex
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          color: i == _previewIndex
                              ? Colors.white
                              : Colors.black54,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _barcodeStatus(_previewIndex),
          ],
        ),
      ),
    );
  }

  Widget _barcodeStatus(int pageIndex) {
    if (_mode != PrintMode.barcodeDiperbesar) {
      return const SizedBox.shrink();
    }
    if (_detecting && !_detections.containsKey(pageIndex)) {
      return const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Mendeteksi barcode...'),
        ],
      );
    }
    if (_detections[pageIndex] == null) {
      return Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Barcode tidak ditemukan di halaman ${pageIndex + 1}',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      );
    }
    if (_effectiveDetection(pageIndex) == null) {
      return Row(
        children: [
          const Icon(Icons.warning_amber_outlined, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Barcode di luar area crop halaman ${pageIndex + 1}',
              style: const TextStyle(color: Colors.orange),
            ),
          ),
        ],
      );
    }
    return const Row(
      children: [
        Icon(Icons.check_circle_outline, color: Colors.green),
        SizedBox(width: 8),
        Text('Barcode ditemukan ✓',
            style: TextStyle(color: Colors.green)),
      ],
    );
  }

  Widget _modeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Text('Mode Cetak',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            RadioGroup<PrintMode>(
              groupValue: _mode,
              onChanged: (v) => v != null ? _onModeChanged(v) : null,
              child: Column(
                children: [
                  RadioListTile<PrintMode>(
                    title: const Text('Cetak asli'),
                    subtitle:
                        const Text('Cetak resi apa adanya selebar kertas'),
                    value: PrintMode.asli,
                  ),
                  RadioListTile<PrintMode>(
                    title: const Text('Barcode diperbesar'),
                    subtitle: const Text(
                        'Barcode terbesar tiap halaman dicetak ulang selebar kertas di bawah resi'),
                    value: PrintMode.barcodeDiperbesar,
                  ),
                ],
              ),
            ),
            if (_mode == PrintMode.barcodeDiperbesar)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                // Wrap (bukan Row) agar tak pernah overflow di layar sempit.
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Orientasi barcode:'),
                    ChoiceChip(
                      label: const Text('Horizontal'),
                      avatar: const Icon(Icons.more_horiz, size: 18),
                      selected: !_barcodeVertical,
                      onSelected: (_) =>
                          setState(() => _barcodeVertical = false),
                    ),
                    ChoiceChip(
                      label: const Text('Vertikal'),
                      avatar: const Icon(Icons.more_vert, size: 18),
                      selected: _barcodeVertical,
                      onSelected: (_) =>
                          setState(() => _barcodeVertical = true),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bluetoothCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Printer Bluetooth',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                if (_connected != null)
                  const Chip(
                    avatar: Icon(Icons.check_circle,
                        color: Colors.green, size: 18),
                    label: Text('Terhubung'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Nyalakan printer dan pastikan dalam jangkauan, lalu pindai. '
              'Hanya perangkat yang aktif terdeteksi yang ditampilkan.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _scanDevices,
              icon: const Icon(Icons.bluetooth_searching),
              label: Text(_scanning
                  ? 'Berhenti (${_devices.length})'
                  : 'Pindai Perangkat'),
            ),
            if (_scanning) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
              const SizedBox(height: 4),
              Text(
                'Memindai perangkat di sekitar... '
                'tap "Berhenti" bila printer sudah muncul.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_connected != null) ...[
              const SizedBox(height: 8),
              DeviceTile(
                device: _connected!,
                connected: true,
                onTap: () {},
              ),
              TextButton.icon(
                onPressed: _disconnect,
                icon: const Icon(Icons.bluetooth_disabled),
                label: const Text('Putuskan koneksi'),
              ),
            ] else ...[
              for (final d in _devices)
                DeviceTile(
                  device: d,
                  busy: _connectingMac,
                  onTap: () => _connect(d),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _printButton() {
    return FilledButton.icon(
      onPressed: _canPrint ? _print : null,
      icon: const Icon(Icons.print),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          _printing ? 'Mencetak...' : 'Cetak',
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
