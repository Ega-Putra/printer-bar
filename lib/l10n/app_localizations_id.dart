// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get tabPrint => 'Cetak';

  @override
  String get tabSettings => 'Pengaturan';

  @override
  String get appVersion => 'Printer Bar v1.2.0';

  @override
  String get privacyTitle => 'Kebijakan Privasi';

  @override
  String get privacySubtitle => 'Bagaimana aplikasi ini menangani data Anda';

  @override
  String get privacyOpenFailed => 'Tidak bisa membuka kebijakan privasi';

  @override
  String get paperTitle => 'Ukuran Kertas';

  @override
  String printWidth(int dots) {
    return 'Lebar cetak: $dots dots @ 203 dpi';
  }

  @override
  String get sourceTitle => 'Sumber Resi';

  @override
  String get sourceHint =>
      'Bisa juga via Share > Printer Bar dari aplikasi lain.';

  @override
  String get pickPdf => 'Pilih PDF';

  @override
  String get pickImage => 'Pilih Gambar';

  @override
  String get singleImage => '1 gambar';

  @override
  String pageCount(int count) {
    return '$count halaman';
  }

  @override
  String get previewCropTitle => 'Pratinjau & Crop';

  @override
  String get reset => 'Reset';

  @override
  String get cropHint =>
      'Seret sudut/sisi untuk ubah area • seret tengah untuk pindah';

  @override
  String get detectingBarcode => 'Mendeteksi barcode...';

  @override
  String barcodeNotFoundPage(int page) {
    return 'Barcode tidak ditemukan di halaman $page';
  }

  @override
  String barcodeOutsideCrop(int page) {
    return 'Barcode di luar area crop halaman $page';
  }

  @override
  String barcodeFoundRewritten(String value) {
    return 'Barcode ditemukan ✓\n$value (ditulis ulang tajam)';
  }

  @override
  String get barcodeFoundImageCrop =>
      'Barcode ditemukan ✓\nNilai tak terbaca — memakai crop gambar';

  @override
  String get printPreviewTitle => 'Pratinjau Hasil Cetak';

  @override
  String printPreviewSubtitle(int page) {
    return 'Persis seperti yang keluar dari printer — halaman $page.';
  }

  @override
  String get printPreviewUnavailable =>
      'Belum bisa dipratinjau (mis. barcode belum terdeteksi).';

  @override
  String get printOptionsTitle => 'Opsi Cetak';

  @override
  String get modeOriginal => 'Asli';

  @override
  String get modeOriginalTooltip =>
      'Cetak asli: resi apa adanya selebar kertas';

  @override
  String get modeBarcode => 'Barcode';

  @override
  String get modeBarcodeTooltip =>
      'Barcode diperbesar: barcode terbesar dicetak ulang selebar kertas di bawah resi';

  @override
  String get orientationVertical => 'Vertikal';

  @override
  String get orientationHorizontal => 'Horisontal';

  @override
  String get orientationVerticalTooltip =>
      'Barcode vertikal (diputar 90°) — ketuk untuk horizontal';

  @override
  String get orientationHorizontalTooltip =>
      'Barcode horizontal — ketuk untuk vertikal';

  @override
  String get dither => 'Dither';

  @override
  String get ditherTooltip =>
      'Dithering: foto & gambar bergradasi tercetak lebih halus';

  @override
  String get barcodeHeight => 'Tinggi barcode:';

  @override
  String get bluetoothTitle => 'Printer Bluetooth';

  @override
  String get connected => 'Terhubung';

  @override
  String get bluetoothHint =>
      'Perangkat yang sudah di-pairing tampil di \"Tersimpan\". Nyalakan printer lalu pindai untuk menemukan perangkat baru di sekitar.';

  @override
  String stopScanning(int count) {
    return 'Berhenti ($count)';
  }

  @override
  String get scanDevices => 'Pindai Perangkat';

  @override
  String get scanningHint =>
      'Memindai perangkat di sekitar... tap \"Berhenti\" bila printer sudah muncul.';

  @override
  String get disconnect => 'Putuskan koneksi';

  @override
  String get savedDevices => 'Perangkat tersimpan';

  @override
  String get availableDevices => 'Perangkat tersedia';

  @override
  String get printButton => 'Cetak';

  @override
  String get printingButton => 'Mencetak...';

  @override
  String get progressOpeningPicker => 'Membuka pemilih berkas...';

  @override
  String get progressRenderingPdf => 'Me-render PDF...';

  @override
  String get progressLoadingImage => 'Memuat gambar...';

  @override
  String get progressRotatingImage => 'Memutar gambar...';

  @override
  String get progressPreparing => 'Menyiapkan...';

  @override
  String progressPrintingPage(int page, int total) {
    return 'Mencetak halaman $page/$total...';
  }

  @override
  String shareFailed(String error) {
    return 'Gagal menerima share: $error';
  }

  @override
  String get sharedPdfUnreadable =>
      'Berkas PDF yang di-share tidak bisa dibaca.';

  @override
  String get pickerTimeout => 'Pemilih berkas tidak merespons dalam 60 detik.';

  @override
  String get pickerUnresponsivePdf =>
      'Pemilih berkas tidak merespons. Coba lagi, atau buka PDF dari File Manager lalu Share > Printer Bar.';

  @override
  String get pickerUnresponsiveShort =>
      'Pemilih berkas tidak merespons. Coba lagi.';

  @override
  String openPickerFailed(String error) {
    return 'Gagal membuka pemilih berkas: $error';
  }

  @override
  String get pdfRenderTimeout =>
      'Render PDF terlalu lama (90 detik). Berkas mungkin rusak atau tidak didukung.';

  @override
  String renderPdfFailed(String error) {
    return 'Gagal me-render PDF: $error';
  }

  @override
  String loadPdfFailed(String error) {
    return 'Gagal memuat PDF: $error';
  }

  @override
  String get imageUnreadable => 'Berkas gambar tidak bisa dibaca.';

  @override
  String get invalidImage => 'Berkas bukan gambar yang valid.';

  @override
  String loadImageFailed(String error) {
    return 'Gagal memuat gambar: $error';
  }

  @override
  String rotateFailed(String error) {
    return 'Gagal memutar gambar: $error';
  }

  @override
  String detectBarcodeFailed(int page, String error) {
    return 'Deteksi barcode halaman $page gagal: $error';
  }

  @override
  String get bluetoothOff =>
      'Bluetooth HP mati. Nyalakan Bluetooth dulu, lalu pindai lagi.';

  @override
  String readBondedFailed(String error) {
    return 'Gagal membaca perangkat tersimpan: $error';
  }

  @override
  String scanFailed(String error) {
    return 'Gagal memindai: $error';
  }

  @override
  String get scanStartFailed =>
      'Gagal memulai pemindaian Bluetooth. Pastikan Bluetooth menyala.';

  @override
  String get noDevicesFound =>
      'Tidak ada perangkat terdeteksi. Pastikan printer menyala dan berada di dekat HP.';

  @override
  String connectedTo(String name) {
    return 'Terhubung ke \"$name\"';
  }

  @override
  String get disconnected => 'Koneksi printer diputus';

  @override
  String barcodeNotFoundThrow(int page) {
    return 'Barcode tidak ditemukan di halaman $page.';
  }

  @override
  String barcodeOutsideCropThrow(int page) {
    return 'Barcode di luar area crop halaman $page.';
  }

  @override
  String get printerDisconnected => 'Printer terputus. Hubungkan ulang dulu.';

  @override
  String get printSuccess => 'Berhasil dicetak 🎉';

  @override
  String printFailed(String error) {
    return 'Gagal mencetak: $error';
  }

  @override
  String get btPermissionDenied =>
      'Izin Bluetooth tidak diberikan. Aktifkan di Pengaturan > Aplikasi > Printer Bar > Izin, lalu coba lagi.';

  @override
  String btConnectFailed(String name) {
    return 'Gagal terhubung ke \"$name\". Pastikan printer menyala, berada di dekat HP, dan tidak dipakai aplikasi lain. Jika diminta, setujui pairing di HP.';
  }

  @override
  String btWriteFailed(int count) {
    return 'Gagal mengirim $count byte ke printer. Periksa koneksi lalu coba lagi.';
  }

  @override
  String get pdfUnreadable =>
      'Berkas PDF tidak bisa dibaca dari penyimpanan HP. Coba pilih lagi dari aplikasi File Manager.';

  @override
  String pdfNotFound(String path) {
    return 'Berkas PDF tidak ditemukan di: $path';
  }

  @override
  String pdfRenderPageFailed(int page) {
    return 'Gagal me-render halaman $page';
  }
}
