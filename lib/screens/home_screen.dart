import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../models/paper_size.dart';
import '../services/barcode_service.dart';
import '../services/bluetooth_printer_service.dart';
import '../services/escpos_builder.dart';
import '../services/image_pipeline.dart';
import '../services/pdf_service.dart';
import '../widgets/crop_overlay.dart';
import '../widgets/device_tile.dart';
import '../widgets/print_preview_image.dart';

/// Dua mode cetak yang tersedia.
enum PrintMode {
  /// Cetak tiap halaman apa adanya, diskala selebar kertas.
  asli,

  /// Cetak tiap halaman + barcode terbesarnya diperbesar selebar kertas
  /// di bawah gambar halaman.
  barcodeDiperbesar,
}

/// Dimensi + path ASLI (belum diputar) sebuah halaman.
///
/// Deteksi barcode selalu dijalankan pada gambar asli; saat pengguna
/// memutar, bbox hasil deteksi di-transform matematis (lihat
/// [ImagePipeline.rotateBox]) mengikuti rotasi — tidak pernah
/// dideteksi ulang pada gambar putaran.
class _OriginalPage {
  final String path;
  final int width;
  final int height;
  const _OriginalPage({
    required this.path,
    required this.width,
    required this.height,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _pdf = PdfService();
  final _barcodes = BarcodeService();
  final _bt = BluetoothPrinterService();
  StreamSubscription<List<SharedMediaFile>>? _intentSub;

  /// Tab "Cetak" (0) vs "Pengaturan" (1).
  late final TabController _tabController;

  PaperSize _paper = PaperSize.mm58;
  PrintMode _mode = PrintMode.asli;

  /// Dithering Floyd-Steinberg saat rasterisasi — hasil foto/gambar
  /// bergradasi jauh lebih halus. Teks & barcode murni hitam-putih
  /// praktis tidak berubah.
  bool _dithering = true;

  /// true = barcode dicetak vertikal (diputar 90°), false = horizontal.
  bool _barcodeVertical = false;

  /// Tinggi barcode yang di-generate ulang, dalam mm (lebar selalu
  /// penuh selebar kertas).
  double _barcodeHeightMm = 25;

  String? _pdfPath;
  String? _pdfName;

  /// true bila sumber yang dimuat adalah gambar (bukan PDF) — render
  /// ulang saat ganti kertas tidak diperlukan untuk gambar.
  bool _sourceIsImage = false;

  /// Rotasi per halaman dalam putaran 90° searah jarum jam (0..3).
  /// Diterapkan ke byte gambar halaman (baked-in) untuk pratinjau &
  /// cetak. DETEKSI barcode tidak ikut: ia selalu memakai gambar asli
  /// (lihat [_originals]) dan bbox-nya di-transform matematis.
  final Map<int, int> _rotations = {};

  /// Gambar asli (belum diputar) per halaman — hanya terisi bila
  /// halaman pernah diputar. Kunci deteksi barcode yang stabil.
  final Map<int, _OriginalPage> _originals = {};

  /// ScrollController tetap agar posisi scroll TIDAK me-reset ke atas
  /// setiap setState (mis. saat tombol rotate ditekan).
  late final ScrollController _printScrollController;
  late final ScrollController _settingsScrollController;

  List<RenderedPage> _pages = [];
  int _previewIndex = 0;
  bool _loadingPdf = false;

  /// Byte PNG pratinjau "persis seperti hasil cetak" untuk halaman
  /// aktif (sudah termasuk barcode yang diperbesar + dithering).
  /// null = belum bisa dihitung (mis. barcode belum terdeteksi).
  Uint8List? _printPreviewBytes;

  /// true saat jari sedang drag di editor crop → scroll halaman dikunci
  /// supaya halaman tidak ikut terscroll saat box digerakkan.
  bool _cropDragging = false;

  /// Area crop per indeks halaman (koordinat piksel gambar render).
  /// Default = seluruh halaman.
  final Map<int, Box> _crops = {};

  /// Hasil deteksi per indeks halaman dalam koordinat gambar render
  /// PENUH (sebelum crop): barcode terbesar, atau null bila tak ada.
  final Map<int, DetectedBarcode?> _detections = {};
  bool _detecting = false;

  List<PrinterDevice> _devices = [];

  /// Perangkat yang sudah di-pairing ("tersimpan"), dimuat saat pemindaian
  /// dimulai (butuh izin BLUETOOTH_CONNECT).
  List<PrinterDevice> _bonded = [];
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
    _tabController = TabController(length: 2, vsync: this);
    _printScrollController = ScrollController();
    _settingsScrollController = ScrollController();
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
    _tabController.dispose();
    _printScrollController.dispose();
    _settingsScrollController.dispose();
    _intentSub?.cancel();
    _discoverySub?.cancel();
    _scanTimer?.cancel();
    _bt.cancelDiscovery();
    _barcodes.dispose();
    super.dispose();
  }

  /// Deteksi efektif untuk halaman [pageIndex]: hasil deteksi yang sudah
  /// di-transform mengikuti rotasi halaman, lalu digeser ke koordinat
  /// gambar ter-crop. Null bila halaman tak punya barcode ATAU
  /// barcode-nya di luar area crop.
  ///
  /// Deteksi selalu dalam koordinat gambar ASLI ([_originals]); bila
  /// halaman diputar, bbox dihitung ulang secara matematis via
  /// [ImagePipeline.rotateBox] — tidak pernah dideteksi ulang.
  DetectedBarcode? _effectiveDetection(int pageIndex) {
    final det = _detections[pageIndex];
    if (det == null) return null;
    final turns = _rotations[pageIndex] ?? 0;
    final orig = _originals[pageIndex];
    final Box rotatedBox;
    if (orig != null && turns % 4 != 0) {
      rotatedBox =
          ImagePipeline.rotateBox(det.box, turns, orig.width, orig.height);
    } else {
      rotatedBox = det.box;
    }
    final crop = _crops[pageIndex];
    if (crop == null) {
      return DetectedBarcode(
          box: rotatedBox, rawValue: det.rawValue, format: det.format);
    }
    final tb = ImagePipeline.translateBox(rotatedBox, crop);
    if (tb == null) return null;
    return DetectedBarcode(
        box: tb, rawValue: det.rawValue, format: det.format);
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
    } on TimeoutException {
      // Pemilih berkas menggantung (pernah terjadi di MIUI) — jangan
      // biarkan UI stuck di status loading selamanya.
      if (mounted) {
        setState(() {
          _loadingPdf = false;
          _progress = null;
        });
        _snack(
          'Pemilih berkas tidak merespons. Coba lagi, atau buka PDF '
          'dari File Manager lalu Share > Printer Bar.',
          error: true,
        );
      }
      return;
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
    // Lepas guard loading: _loadPdfFromPath punya guard re-entrancy
    // sendiri dan mengatur _loadingPdf-nya sendiri. Tanpa ini ia langsung
    // return di awal dan UI stuck "Membuka pemilih berkas..." selamanya.
    if (mounted) {
      setState(() => _loadingPdf = false);
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
      // Timeout pengaman: pdfx kadang menggantung di PDF tertentu —
      // jangan biarkan UI stuck "Me-render PDF..." selamanya.
      final pages = await _pdf
          .renderPages(path, renderWidth: _paper.dots * 2)
          .timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw TimeoutException(
          'Render PDF terlalu lama (90 detik). Berkas mungkin rusak '
          'atau tidak didukung.',
        ),
      );
      if (!mounted) return;
      setState(() {
        _pdfPath = path;
        _pdfName = name;
        _sourceIsImage = false;
        _rotations.clear();
        _originals.clear();
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
      // PDF masuk -> langsung ke tab Cetak.
      _tabController.animateTo(0);
      if (_mode == PrintMode.barcodeDiperbesar) {
        await _detectBarcodes(); // diakhiri _refreshPrintPreview()
      } else {
        _refreshPrintPreview();
      }
    } on TimeoutException catch (e) {
      _snack('Gagal me-render PDF: ${e.message}', error: true);
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

  // ---------- Gambar ----------

  /// Pilih berkas gambar (JPG/PNG) sebagai sumber resi. Gambar
  /// diperlakukan sebagai SATU halaman dan melewati pipeline yang sama
  /// persis seperti halaman PDF: pratinjau → crop → rotate → cetak.
  Future<void> _pickImage() async {
    if (_loadingPdf) return;
    setState(() {
      _loadingPdf = true;
      _progress = 'Membuka pemilih berkas...';
    });
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.image,
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException(
          'Pemilih berkas tidak merespons dalam 60 detik.',
        ),
      );
      if (files.isEmpty) {
        // Pengguna batal.
        if (mounted) {
          setState(() {
            _loadingPdf = false;
            _progress = null;
          });
        }
        return;
      }
      final file = files.first;
      final Uint8List bytes;
      final p = file.path;
      if (p != null && File(p).existsSync()) {
        bytes = await File(p).readAsBytes();
      } else {
        bytes = await file.readAsBytes();
      }
      if (bytes.isEmpty) {
        throw Exception('Berkas gambar tidak bisa dibaca.');
      }
      if (mounted) setState(() => _loadingPdf = false);
      await _loadImageFromBytes(bytes, file.name);
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _loadingPdf = false;
          _progress = null;
        });
        _snack(
          'Pemilih berkas tidak merespons. Coba lagi.',
          error: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingPdf = false;
          _progress = null;
        });
        _snack('Gagal memuat gambar: ${_errMsg(e)}', error: true);
      }
    }
  }

  /// Muat [bytes] gambar sebagai satu halaman sumber.
  Future<void> _loadImageFromBytes(Uint8List bytes, String name) async {
    if (_loadingPdf) return;
    setState(() {
      _loadingPdf = true;
      _progress = 'Memuat gambar...';
    });
    try {
      late img.Image decoded;
      try {
        decoded = ImagePipeline.decode(bytes);
      } catch (_) {
        throw Exception('Berkas bukan gambar yang valid.');
      }
      // Normalisasi ke PNG + simpan ke cache agar deteksi barcode
      // (yang bekerja via path berkas) bisa dipakai.
      final png = Uint8List.fromList(img.encodePng(decoded));
      final tmp = await getTemporaryDirectory();
      final out = File(
          '${tmp.path}/img_${DateTime.now().millisecondsSinceEpoch}.png');
      await out.writeAsBytes(png, flush: true);
      if (!mounted) return;
      setState(() {
        _pdfPath = out.path;
        _pdfName = name;
        _sourceIsImage = true;
        _rotations.clear();
        _originals.clear();
        _pages = [
          RenderedPage(
            path: out.path,
            width: decoded.width,
            height: decoded.height,
            bytes: png,
          ),
        ];
        _previewIndex = 0;
        _detections.clear();
        _crops.clear();
        _crops[0] = Box(
          0,
          0,
          decoded.width.toDouble(),
          decoded.height.toDouble(),
        );
      });
      _tabController.animateTo(0);
      if (_mode == PrintMode.barcodeDiperbesar) {
        await _detectBarcodes();
      } else {
        _refreshPrintPreview();
      }
    } catch (e) {
      _snack('Gagal memuat gambar: ${_errMsg(e)}', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _loadingPdf = false;
          _progress = null;
        });
      }
    }
  }

  /// Putar halaman pratinjau aktif 90° searah jarum jam. Rotasi di-bake
  /// ke byte gambar halaman untuk pratinjau & cetak, TAPI deteksi
  /// barcode TIDAK ikut: ia tetap memakai gambar asli ([_originals])
  /// dan bbox-nya di-transform matematis (lihat [_effectiveDetection]).
  /// Deteksi ulang pada gambar putaran sering gagal ("tidak ketemu"),
  /// jadi tidak pernah dilakukan.
  Future<void> _rotatePreviewPage() async {
    if (_pages.isEmpty || _loadingPdf) return;
    final i = _previewIndex;
    setState(() {
      _loadingPdf = true;
      _progress = 'Memutar gambar...';
    });
    try {
      final page = _pages[i];
      // Simpan gambar asli SEKALI (untuk deteksi barcode yang stabil).
      _originals.putIfAbsent(
        i,
        () => _OriginalPage(
            path: page.path, width: page.width, height: page.height),
      );
      final rotated =
          ImagePipeline.rotate90Clockwise(ImagePipeline.decode(page.bytes));
      final png = Uint8List.fromList(img.encodePng(rotated));
      final tmp = await getTemporaryDirectory();
      final out = File(
          '${tmp.path}/rot_${DateTime.now().millisecondsSinceEpoch}_p$i.png');
      await out.writeAsBytes(png, flush: true);
      if (!mounted) return;
      setState(() {
        _pages[i] = RenderedPage(
          path: out.path,
          width: rotated.width,
          height: rotated.height,
          bytes: png,
        );
        _crops[i] = Box(
          0,
          0,
          rotated.width.toDouble(),
          rotated.height.toDouble(),
        );
        _rotations[i] = ((_rotations[i] ?? 0) + 1) % 4;
      });
      // SENGAJA tidak memanggil _detectBarcodes(): deteksi tetap pada
      // gambar asli; _effectiveDetection mentransform bbox-nya.
      _refreshPrintPreview();
    } catch (e) {
      _snack('Gagal memutar gambar: ${_errMsg(e)}', error: true);
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
    // Gambar tidak perlu di-render ulang (resolusinya tetap) — cukup
    // hitung ulang pratinjau. PDF di-render ulang mengikuti kertas.
    if (_sourceIsImage) {
      _refreshPrintPreview();
      return;
    }
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
    _refreshPrintPreview();
  }

  void _setPreviewIndex(int i) {
    if (i == _previewIndex) return;
    setState(() => _previewIndex = i);
    _refreshPrintPreview();
  }

  // ---------- Mode & deteksi barcode ----------

  Future<void> _onModeChanged(PrintMode mode) async {
    setState(() => _mode = mode);
    if (mode == PrintMode.barcodeDiperbesar &&
        _pages.isNotEmpty &&
        _detections.isEmpty &&
        !_detecting) {
      await _detectBarcodes(); // diakhiri _refreshPrintPreview()
    } else {
      _refreshPrintPreview();
    }
  }

  /// Jalankan deteksi barcode pada gambar ASLI tiap halaman yang belum
  /// terdeteksi. Tidak pernah dijalankan pada gambar yang sudah diputar
  /// (lihat [_rotatePreviewPage]).
  Future<void> _detectBarcodes() async {
    setState(() {
      _detecting = true;
    });
    try {
      for (var i = 0; i < _pages.length; i++) {
        if (_detections.containsKey(i)) continue; // sudah ada: jangan ulang
        // Selalu deteksi pada gambar asli, bukan hasil putaran.
        final srcPath = _originals[i]?.path ?? _pages[i].path;
        List<DetectedBarcode> found;
        try {
          found = await _barcodes.detect(srcPath);
        } catch (e) {
          if (!mounted) return;
          _snack('Deteksi barcode halaman ${i + 1} gagal: ${_errMsg(e)}',
              error: true);
          found = [];
        }
        if (!mounted) return;
        var best = _barcodes.largest(found);
        // Kotak ketemu tapi nilai tak terbaca ML Kit -> coba decode manual.
        if (best != null && best.rawValue == null) {
          best = await _barcodes.decodeValue(srcPath, best) ?? best;
        }
        if (!mounted) return;
        setState(() => _detections[i] = best);
      }
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
    _refreshPrintPreview();
  }

  // ---------- Bluetooth ----------

  /// Pindai perangkat Bluetooth ala pengaturan bawaan HP:
  /// "Perangkat tersimpan" (sudah di-pairing) + "Perangkat tersedia"
  /// (discovery aktif di sekitar). Tap lagi untuk berhenti; berhenti
  /// otomatis setelah 15 detik.
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
      // Perangkat tersimpan — gagal dimuat tak menggagalkan pemindaian.
      try {
        final bonded = await _bt.bondedDevices();
        if (mounted) {
          setState(() {
            _bonded =
                BluetoothPrinterService.sortPrintersFirst(bonded);
          });
        }
      } catch (e) {
        _snack('Gagal membaca perangkat tersimpan: ${_errMsg(e)}',
            error: true);
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
    // 1. Generate ulang yang tajam & full-width bila ada nilai decode.
    final barHpx = (_barcodeHeightMm / 25.4 * 203).round();
    img.Image? barcodeImg = BarcodeService.regenerateBarcode(
      det: det,
      widthPx: dots,
      barHeightPx: barHpx,
    );
    // 2. Fallback: crop + skala dari gambar asli (mis. format tak
    //    didukung atau nilai tak ter-decode).
    barcodeImg ??= ImagePipeline.cropAndScaleToWidth(
      cropped,
      ImagePipeline.paddedCrop(det.box, cropped.width, cropped.height),
      dots,
    );
    if (_barcodeVertical) {
      barcodeImg = ImagePipeline.padToWidth(
        ImagePipeline.rotate90Clockwise(barcodeImg),
        dots,
      );
    }
    return ImagePipeline.composeVertical([pageForPrint, barcodeImg]);
  }

  /// Rasterisasi [finalImg] sesuai pilihan dithering.
  Uint8List _rasterize(img.Image finalImg) => _dithering
      ? ImagePipeline.toRasterBytesDithered(finalImg)
      : ImagePipeline.toRasterBytes(finalImg);

  /// Hitung ulang pratinjau "persis seperti hasil cetak" untuk halaman
  /// aktif: compose → raster (sesuai mode dithering) → gambar 1-bit.
  /// Dipanggil pada setiap perubahan diskrit (bukan tiap frame drag).
  void _refreshPrintPreview() {
    if (_pages.isEmpty || !mounted) {
      _printPreviewBytes = null;
      return;
    }
    try {
      final composed = _composePage(_previewIndex, _paper.dots);
      final raster = _rasterize(composed);
      final previewImg = ImagePipeline.rasterToImage(raster, _paper.dots);
      _printPreviewBytes =
          Uint8List.fromList(img.encodePng(previewImg));
    } catch (_) {
      // Mis. mode barcode tapi deteksi belum ada → preview kosong.
      _printPreviewBytes = null;
    }
    if (mounted) setState(() {});
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
        final raster = _rasterize(finalImg);
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
      appBar: AppBar(title: const Text('Printer Bar')),
      body: TabBarView(
        controller: _tabController,
        // Geser tab dimatikan: pindah tab HANYA via tombol di bawah.
        // (Geser horizontal TabBarView berkonflik dengan drag kotak crop.)
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _printTab(),
          _settingsTab(),
        ],
      ),
      bottomNavigationBar: Material(
        color: Theme.of(context).colorScheme.surface,
        child: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.print), text: 'Cetak'),
            Tab(icon: Icon(Icons.settings), text: 'Pengaturan'),
          ],
        ),
      ),
    );
  }

  /// Tab "Cetak": pilih PDF -> atur crop -> pratinjau -> cetak.
  Widget _printTab() {
    return SingleChildScrollView(
      key: const PageStorageKey('printTab'),
      controller: _printScrollController,
      physics:
          _cropDragging ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pdfCard(),
          if (_pages.isNotEmpty) ...[
            const SizedBox(height: 12),
            _previewCard(),
            const SizedBox(height: 12),
            _printPreviewCard(),
            const SizedBox(height: 12),
            _printOptionsCard(),
            if (_mode == PrintMode.barcodeDiperbesar) ...[
              const SizedBox(height: 12),
              _barcodeHeightCard(),
            ],
          ],
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
    );
  }

  /// Tab "Pengaturan": kertas dan koneksi printer.
  /// (Mode cetak / orientasi / dithering / tinggi barcode sudah pindah
  /// ke tab Cetak sebagai kontrol kompak.)
  Widget _settingsTab() {
    return SingleChildScrollView(
      key: const PageStorageKey('settingsTab'),
      controller: _settingsScrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _paperCard(),
          const SizedBox(height: 12),
          _bluetoothCard(),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Printer Bar v1.1.2',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
        ],
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
            const Text('Sumber Resi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              'Bisa juga via Share > Printer Bar dari aplikasi lain.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loadingPdf ? null : _pickPdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Pilih PDF'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loadingPdf ? null : _pickImage,
                    icon: const Icon(Icons.image),
                    label: const Text('Pilih Gambar'),
                  ),
                ),
              ],
            ),
            if (_pdfName != null) ...[
              const SizedBox(height: 8),
              Text('📄 $_pdfName'),
              Text(
                  _sourceIsImage
                      ? '1 gambar'
                      : '${_pages.length} halaman',
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
                // Putar 90° searah jarum jam (berlaku untuk PDF & gambar).
                TextButton.icon(
                  onPressed:
                      (_loadingPdf || _pages.isEmpty) ? null : _rotatePreviewPage,
                  icon: const Icon(Icons.rotate_right, size: 18),
                  label: Text(
                      '${((_rotations[_previewIndex] ?? 0) * 90)}°'),
                ),
                TextButton.icon(
                  onPressed: _resetCrop,
                  icon: const Icon(Icons.crop_free, size: 18),
                  label: const Text('Reset'),
                ),
              ],
            ),
            const Text(
              'Seret sudut/sisi untuk ubah area • seret tengah untuk pindah',
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
                onDragging: (dragging) {
                  if (mounted && dragging != _cropDragging) {
                    setState(() => _cropDragging = dragging);
                  }
                  // Drag selesai (jari diangkat) → perbarui pratinjau
                  // hasil cetak. Selama drag tidak dihitung ulang agar
                  // geseran tetap mulus.
                  if (!dragging) _refreshPrintPreview();
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  GestureDetector(
                    onTap: () => _setPreviewIndex(i),
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
    final det = _effectiveDetection(pageIndex)!;
    final rewritten = det.rawValue != null;
    return Row(
      children: [
        Icon(
          rewritten ? Icons.check_circle_outline : Icons.warning_amber_outlined,
          color: rewritten ? Colors.green : Colors.orange,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            rewritten
                ? 'Barcode ditemukan ✓\n${det.rawValue} (ditulis ulang tajam)'
                : 'Barcode ditemukan ✓\nNilai tak terbaca — memakai crop gambar',
            style: TextStyle(
                color: rewritten ? Colors.green : Colors.orange),
          ),
        ),
      ],
    );
  }

  /// Pratinjau WYSIWYG: persis seperti yang keluar dari printer
  /// (crop + skala kertas + barcode diperbesar + dithering).
  Widget _printPreviewCard() {
    final bytes = _printPreviewBytes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pratinjau Hasil Cetak',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              'Persis seperti yang keluar dari printer — halaman '
              '${_previewIndex + 1}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (bytes != null)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.white,
                ),
                child: PrintPreviewImage(bytes: bytes),
              )
            else
              const Text(
                'Belum bisa dipratinjau (mis. barcode belum terdeteksi).',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  /// Opsi cetak kompak: deretan tombol ikon BERUKURAN TETAP pada posisi
  /// tetap (tidak pernah bergeser/hilang — yang tak berlaku tampil
  /// redup/nonaktif). Satu tombol toggle untuk orientasi barcode yang
  /// ikonnya ikut berubah mengikuti orientasi aktif.
  Widget _printOptionsCard() {
    final scheme = Theme.of(context).colorScheme;
    final inBarcodeMode = _mode == PrintMode.barcodeDiperbesar;

    Widget toggle({
      required Widget icon,
      required String label,
      required String tooltip,
      required bool selected,
      required VoidCallback? onTap,
    }) {
      final enabled = onTap != null;
      final fg = selected ? scheme.onPrimary : scheme.onSurfaceVariant;
      final bg = selected ? scheme.primary : scheme.surfaceContainerHighest;
      // Lebar TETAP agar tombol tidak pernah bergeser posisi.
      return SizedBox(
        width: 76,
        child: Tooltip(
          message: tooltip,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.4,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    const SizedBox(height: 2),
                    Text(label,
                        style: TextStyle(fontSize: 10, color: fg),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget tIcon(IconData d, Color c) => Icon(d, size: 22, color: c);

    // Ikon orientasi: barcode horizontal = bilah vertikal; saat mode
    // vertikal ikonnya diputar 90° sehingga ikut menampilkan bilah
    // horizontal. Satu tombol toggle, bukan dua tombol terpisah.
    final orientIcon = RotatedBox(
      quarterTurns: _barcodeVertical ? 1 : 0,
      child: tIcon(
        Icons.view_week,
        inBarcodeMode
            ? (_barcodeVertical
                ? scheme.onPrimary
                : scheme.onSurfaceVariant)
            : scheme.onSurfaceVariant,
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Opsi Cetak',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                toggle(
                  icon: tIcon(
                    Icons.receipt_long,
                    _mode == PrintMode.asli
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                  ),
                  label: 'Asli',
                  tooltip: 'Cetak asli: resi apa adanya selebar kertas',
                  selected: _mode == PrintMode.asli,
                  onTap: () => _onModeChanged(PrintMode.asli),
                ),
                toggle(
                  icon: tIcon(
                    Icons.qr_code,
                    inBarcodeMode
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                  ),
                  label: 'Barcode',
                  tooltip:
                      'Barcode diperbesar: barcode terbesar dicetak ulang selebar kertas di bawah resi',
                  selected: inBarcodeMode,
                  onTap: () => _onModeChanged(PrintMode.barcodeDiperbesar),
                ),
                toggle(
                  icon: orientIcon,
                  label: _barcodeVertical ? 'Vertikal' : 'Horisontal',
                  tooltip: _barcodeVertical
                      ? 'Barcode vertikal (diputar 90°) — ketuk untuk horizontal'
                      : 'Barcode horizontal — ketuk untuk vertikal',
                  selected: inBarcodeMode && _barcodeVertical,
                  onTap: inBarcodeMode
                      ? () {
                          setState(
                              () => _barcodeVertical = !_barcodeVertical);
                          _refreshPrintPreview();
                        }
                      : null,
                ),
                toggle(
                  icon: tIcon(
                    Icons.gradient,
                    _dithering
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                  ),
                  label: 'Dither',
                  tooltip:
                      'Dithering: foto & gambar bergradasi tercetak lebih halus',
                  selected: _dithering,
                  onTap: () {
                    setState(() => _dithering = !_dithering);
                    _refreshPrintPreview();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Slider tinggi barcode — di tab Cetak, di bawah kartu Opsi Cetak;
  /// hanya tampil pada mode "Barcode diperbesar".
  Widget _barcodeHeightCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            const Text('Tinggi barcode:'),
            Expanded(
              child: Slider(
                value: _barcodeHeightMm,
                min: 10,
                max: 50,
                divisions: 8,
                label: '${_barcodeHeightMm.round()} mm',
                onChanged: (v) => setState(() => _barcodeHeightMm = v),
                onChangeEnd: (_) => _refreshPrintPreview(),
              ),
            ),
            SizedBox(
              width: 52,
              child: Text('${_barcodeHeightMm.round()} mm',
                  textAlign: TextAlign.end),
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
              'Perangkat yang sudah di-pairing tampil di "Tersimpan". '
              'Nyalakan printer lalu pindai untuk menemukan perangkat '
              'baru di sekitar.',
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
              if (_bonded.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Perangkat tersimpan',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                for (final d in _bonded)
                  DeviceTile(
                    device: d,
                    busy: _connectingMac,
                    onTap: () => _connect(d),
                  ),
              ],
              if (_devices.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Perangkat tersedia',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                for (final d in BluetoothPrinterService.sortPrintersFirst(
                    _devices))
                  DeviceTile(
                    device: d,
                    busy: _connectingMac,
                    onTap: () => _connect(d),
                  ),
              ],
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
