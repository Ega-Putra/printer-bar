import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// Perangkat printer yang sudah di-pairing.
class PrinterDevice {
  final String name;
  final String mac;

  const PrinterDevice({required this.name, required this.mac});
}

/// Layanan koneksi Bluetooth SPP ke printer thermal.
///
/// Memakai package `print_bluetooth_thermal` (terawat, mendukung model izin
/// Android 12+ tanpa meminta izin lokasi yang tak perlu). Sesuai kebijakan
/// plugin, daftar perangkat = perangkat yang SUDAH di-pairing di Pengaturan
/// Bluetooth HP — pengguna wajib pairing manual lebih dulu.
class BluetoothPrinterService {
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

  /// Daftar perangkat yang sudah di-pairing di HP.
  Future<List<PrinterDevice>> pairedDevices() async {
    final list = await PrintBluetoothThermal.pairedBluetooths;
    return [
      for (final d in list)
        PrinterDevice(
          name: d.name.isEmpty ? d.macAdress : d.name,
          mac: d.macAdress,
        ),
    ];
  }

  /// Hubungkan ke [device] via SPP. Melempar [Exception] bila gagal.
  Future<void> connect(PrinterDevice device) async {
    final ok =
        await PrintBluetoothThermal.connect(macPrinterAddress: device.mac);
    if (!ok) {
      throw Exception(
        'Gagal terhubung ke "${device.name}". Pastikan printer menyala, '
        'berada di dekat HP, dan tidak dipakai aplikasi lain.',
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
