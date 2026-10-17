# Cetak Thermal 🖨️

Aplikasi Android untuk mencetak resi PDF ke printer thermal Bluetooth.

## Fitur

- **Ukuran kertas**: 58mm / 80mm / 112mm (otomatis dihitung ke dots @203dpi)
- **Pilih PDF resi** + pratinjau per halaman
- **Crop drag-box**: seret sudut untuk resize, seret tengah untuk pindah
- **Mode cetak**:
  - *Cetak asli* — halaman diskala selebar kertas
  - *Barcode diperbesar* — barcode terbesar dideteksi (ML Kit), di-crop, diperbesar selebar kertas, dicetak di bawah resi; bisa flip horizontal/vertikal
- **Bluetooth**: pindai perangkat yang sudah di-pairing, konek via SPP, cetak dengan ESC/POS raster (universal untuk printer ESC/POS)
- **Share target**: muncul di menu Share untuk file PDF

## Teknologi

Flutter 3.47.7 · pdfx (render PDF) · google_mlkit_barcode_scanning (deteksi barcode)
· print_bluetooth_thermal (Bluetooth SPP) · ESC/POS dirakit manual di Dart

## Build

```bash
source ~/workspace/bin/flutter-env.sh   # di mesin dev Paimon
flutter pub get
flutter analyze && flutter test
flutter build apk --debug               # atau --split-per-abi
```

## Catatan

- Test cetak fisik hanya bisa di HP + printer thermal sungguhan (tidak tersedia di mesin dev).
- Signing release / upload key Play Store belum disiapkan.
