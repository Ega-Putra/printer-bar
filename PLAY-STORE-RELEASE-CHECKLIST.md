# Checklist Rilis Play Store — Printer Bar (com.egaputra.thermal_print)

Target: goal due 2026-10-20 23:59 UTC. Urutan kerja: QA v1.8 kelar → signing → listing → upload.
Koreksi penting (verifikasi 2026-10-18): **"Production" tidak bisa tanggal 20 Okt.** Kalau akun developer kamu akun personal BARU (dibuat setelah 13 Nov 2023), Google mewajibkan **closed testing: minimal 12 tester opt-in terus-menerus selama 14 hari** SEBELUM tombol "apply for production" kebuka — internal testing TIDAK dihitung. Jadi target realistis 20 Okt = AAB signed + listing lengkap + closed test jalan dengan 12+ tester; Production = +14 hari + review Google (~7 hari). (Sumber: Play Console Help; dikecualikan kalau akunmu organisasi atau personal lama pra-Nov 2023 — cek dulu kamu masuk yang mana.)

## 1. Gerbang QA (di tangan kamu, sebelum signing)

- [ ] Install v1.8, status barcode HIJAU "004614605180 (ditulis ulang tajam)" di resi test
- [ ] Test print fisik: HP Xiaomi + printer RPP02N (cetak asli & barcode diperbesar)
- [ ] Crop drag mulus, tab Cetak/Pengaturan via tombol saja

## 2. Release signing (bareng Paimon)

- [ ] Generate upload keystore (1x saja — **backup file .jks + password di tempat aman**; hilang = tidak bisa update aplikasi lagi)
- [ ] `flutter build appbundle --release` (Play Store wajib AAB, bukan APK)
- [ ] **Uninstall dulu** semua build debug/test di HP sebelum install versi release (signature beda → konflik)

## 3. Akun & listing Play Console

- [ ] Akun developer Google Play (sekali bayar $25 — cek dulu kamu sudah punya atau belum)
- [ ] Nama aplikasi, deskripsi singkat + lengkap (ID), kategori, email kontak
- [ ] Ikon: 512x512 (pilih dari 3 opsi yang kemarin — belum ada keputusan final)
- [ ] Feature graphic 1024x500 + minimal 2 screenshot HP
- [ ] Kuesioner rating konten + formulir keamanan data (aplikasi: Bluetooth + proses lokal, tanpa akun/pengumpulan data)

## 4. Upload & testing (jalur yang benar)

- [ ] Upload AAB ke track **"Closed testing"** (BUKAN internal — internal tidak dihitung untuk syarat 14 hari)
- [ ] Kumpulkan **12+ tester** (undang 15–16 buat cadangan; yang dihitung = opt-in via link, bukan cuma install)
- [ ] 14 hari berturut-turut opt-in → baru "Apply for production" kebuka → isi kuesioner → review Google (~7 hari)
- [ ] Internal testing tetap boleh dipakai paralel buat QA tim sendiri, tapi tidak menggantikan closed test

Status teknis terverifikasi (2026-10-18, dari repo):
- targetSdk = 36 (default Flutter 3.47.7) ✓ — memenuhi syarat Play per 31 Agu 2026 (API 36 untuk aplikasi baru)
- compileSdk = 37; applicationId = com.egaputra.thermal_print; version saat ini 1.0.8+9
- AAB BELUM PERNAH dibuild (folder goal cuma berisi APK v1.2–v1.8); release build masih pakai debug signing → keystore wajib dibuat sebelum upload
- Ikon: 3 opsi di `assets/icon-options/` (printer / receipt / barcode) + `assets/icon/icon.png` saat ini — keputusan final di tangan kamu

Catatan: Native PrintService tetap eksperimen v3 terpisah — TIDAK menghambat rilis v1.
