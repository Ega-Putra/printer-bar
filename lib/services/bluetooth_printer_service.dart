import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// Perangkat yang terdeteksi via Bluetooth (aktif di sekitar HP).
class PrinterDevice {
  final String name;
  final String mac;

  const PrinterDevice({required this.name, required this.mac});
}

/// Layanan koneksi Bluetooth SPP ke printer thermal.
///
/// Memakai package `print_bluetooth_thermal` untuk koneksi & tulis data,
/// dan discovery Bluetooth klasik via MethodChannel native
/// (lihat MainActivity.kt) agar daftar hanya berisi perangkat yang AKTIF
/// terdeteksi di sekitar — bukan seluruh riwayat pairing HP.
class BluetoothPrinterService {
  static const _method =
      MethodChannel('com.egaputra.thermal_print/bt_discovery');
  static const _events =
      EventChannel('com.egaputra.thermal_print/bt_discovery_events');

  /// Minta izin runtime yang dibutuhkan Bluetooth.
  ///
  /// Melempar [Exception] berbahasa Indonesia bila ada izin yang ditolak.
  Future<void> ensurePermissions() async {
    final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    final wanted = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ];
    // Discovery Bluetooth di Android 11 ke bawah masih butuh izin lokasi.
    if (sdkInt <= 30) wanted.add(Permission.location);

    final statuses = await wanted.request();
    final denied =
        statuses.entries.where((e) => !e.value.isGranted).toList();
    if (denied.isNotEmpty) {
      throw Exception(
        'Izin Bluetooth tidak diberikan. Aktifkan di Pengaturan > Aplikasi > '
        'Cetak Thermal > Izin, lalu coba lagi.',
      );
    }
  }

  Future<bool> get bluetoothOn => PrintBluetoothThermal.bluetoothEnabled;

  /// Hilangkan duplikat berdasarkan MAC (discovery bisa melaporkan
  /// perangkat yang sama berkali-kali). Murni-Dart, bisa di-unit-test.
  static List<PrinterDevice> dedupe(List<PrinterDevice> devices) {
    final seen = <String>{};
    return [
      for (final d in devices)
        if (seen.add(d.mac)) d,
    ];
  }

  /// Stream perangkat yang ditemukan selama discovery aktif.
  ///
  /// Tiap event = satu perangkat (MAC bisa duplikat → pakai [dedupe]).
  /// Event `null` = discovery selesai (timeout sistem).
  Stream<PrinterDevice?> discoveryStream() {
    return _events.receiveBroadcastStream().map((event) {
      final m = Map<String, dynamic>.from(event as Map);
      if (m['event'] == 'finished') return null;
      final mac = (m['mac'] ?? '').toString();
      if (mac.isEmpty) return null;
      var name = (m['name'] ?? '').toString();
      if (name.isEmpty) name = mac;
      return PrinterDevice(name: name, mac: mac);
    });
  }

  /// Mulai discovery Bluetooth klasik. True bila berhasil dimulai.
  Future<bool> startDiscovery() async {
    final ok = await _method.invokeMethod<bool>('startDiscovery');
    return ok == true;
  }

  /// Hentikan discovery yang sedang berjalan.
  Future<void> cancelDiscovery() async {
    try {
      await _method.invokeMethod<bool>('cancelDiscovery');
    } catch (_) {
      // Abaikan: channel mungkin belum siap (mis. saat dispose awal).
    }
  }

  /// Hubungkan ke [device] via SPP. Melempar [Exception] bila gagal.
  ///
  /// Untuk perangkat yang belum di-pairing, Android biasanya menampilkan
  /// dialog pairing saat pertama kali terhubung — setujui di HP.
  Future<void> connect(PrinterDevice device) async {
    final ok =
        await PrintBluetoothThermal.connect(macPrinterAddress: device.mac);
    if (!ok) {
      throw Exception(
        'Gagal terhubung ke "${device.name}". Pastikan printer menyala, '
        'berada di dekat HP, dan tidak dipakai aplikasi lain. Jika diminta, '
        'setujui pairing di HP.',
      );
    }
  }

  Future<void> disconnect() async {
    await PrintBluetoothThermal.disconnect;
  }

  Future<bool> get isConnected => PrintBluetoothThermal.connectionStatus;

  /// Kirim [bytes] ke printer dalam potongan 2 KB agar aman di semua
  /// perangkat. Melempar [Exception] bila ada potongan yang gagal.
  Future<void> writeBytes(List<int> bytes) async {
    const chunkSize = 2048;
    for (var i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, bytes.length);
      final ok =
          await PrintBluetoothThermal.writeBytes(bytes.sublist(i, end));
      if (!ok) {
        throw Exception(
          'Gagal mengirim data ke printer (byte ke-$i dari ${bytes.length}). '
          'Periksa koneksi lalu coba lagi.',
        );
      }
    }
  }
}
