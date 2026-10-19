import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// Perangkat Bluetooth (printer maupun bukan).
class PrinterDevice {
  final String name;
  final String mac;

  /// Major device class Bluetooth
  /// (android.bluetooth.BluetoothClass.Device.Major), atau null bila
  /// tidak diketahui.
  final int? deviceClass;

  const PrinterDevice({
    required this.name,
    required this.mac,
    this.deviceClass,
  });
}

/// Jenis perangkat untuk ikon daftar, diturunkan dari Bluetooth
/// Class of Device (dan nama sebagai cadangan).
enum DeviceKind { printer, headset, laptop, phone, gamepad, other }

/// Layanan koneksi Bluetooth SPP ke printer thermal.
///
/// Memakai package `print_bluetooth_thermal` untuk koneksi & tulis data,
/// dan kode native (lihat MainActivity.kt) untuk:
/// - daftar perangkat tersimpan (bonded) beserta kelas perangkatnya,
/// - discovery Bluetooth klasik agar perangkat baru yang aktif di sekitar
///   ikut tampil — mirip daftar Bluetooth bawaan HP.
class BluetoothPrinterService {
  static const _method =
      MethodChannel('com.printer.bar/bt_discovery');
  static const _events =
      EventChannel('com.printer.bar/bt_discovery_events');

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
        'Printer Bar > Izin, lalu coba lagi.',
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

  /// Tentukan [DeviceKind] dari [PrinterDevice].
  ///
  /// Nama yang mengandung "print" selalu dianggap printer (banyak printer
  /// thermal murah melaporkan class generik). Selain itu dipakai major
  /// device class: IMAGING (0x600) → printer, AUDIO_VIDEO (0x400) →
  /// headset, COMPUTER (0x100) → laptop, PHONE (0x200) → HP,
  /// TOY (0x800) → gamepad. Murni-Dart, bisa di-unit-test.
  static DeviceKind deviceKindFor(PrinterDevice device) {
    if (device.name.toLowerCase().contains('print')) {
      return DeviceKind.printer;
    }
    switch (device.deviceClass) {
      case 1536: // IMAGING
        return DeviceKind.printer;
      case 1024: // AUDIO_VIDEO
        return DeviceKind.headset;
      case 256: // COMPUTER
        return DeviceKind.laptop;
      case 512: // PHONE
        return DeviceKind.phone;
      case 2048: // TOY
        return DeviceKind.gamepad;
      default:
        return DeviceKind.other;
    }
  }

  /// Urutkan printer paling atas, sisanya alfabetis. Murni-Dart,
  /// bisa di-unit-test.
  static List<PrinterDevice> sortPrintersFirst(List<PrinterDevice> devices) {
    final sorted = [...devices];
    sorted.sort((a, b) {
      final pa = deviceKindFor(a) == DeviceKind.printer ? 0 : 1;
      final pb = deviceKindFor(b) == DeviceKind.printer ? 0 : 1;
      if (pa != pb) return pa.compareTo(pb);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  /// Bangun [PrinterDevice] dari map native. Null bila MAC kosong.
  static PrinterDevice? deviceFromMap(Map<String, dynamic> m) {
    final mac = (m['mac'] ?? '').toString();
    if (mac.isEmpty) return null;
    var name = (m['name'] ?? '').toString();
    if (name.isEmpty) name = mac;
    final dc = m['deviceClass'];
    final deviceClass =
        dc is int ? dc : int.tryParse(dc?.toString() ?? '');
    return PrinterDevice(name: name, mac: mac, deviceClass: deviceClass);
  }

  /// Stream perangkat yang ditemukan selama discovery aktif.
  ///
  /// Tiap event = satu perangkat (MAC bisa duplikat → pakai [dedupe]).
  /// Event `null` = discovery selesai (timeout sistem).
  Stream<PrinterDevice?> discoveryStream() {
    return _events.receiveBroadcastStream().map((event) {
      final m = Map<String, dynamic>.from(event as Map);
      if (m['event'] == 'finished') return null;
      return deviceFromMap(m);
    });
  }

  /// Perangkat yang sudah di-pairing ("tersimpan") beserta kelas
  /// perangkatnya, via kode native (lihat MainActivity.kt).
  ///
  /// Butuh izin BLUETOOTH_CONNECT — panggil setelah [ensurePermissions].
  /// Melempar [Exception] bila channel native gagal.
  Future<List<PrinterDevice>> bondedDevices() async {
    final list = await _method.invokeMethod<List>('getBondedDevices');
    if (list == null) return [];
    return [
      for (final e in list)
        deviceFromMap(Map<String, dynamic>.from(e as Map)),
    ].whereType<PrinterDevice>().toList();
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

  /// Kirim [bytes] ke printer dalam SATU panggilan method channel.
  ///
  /// PENTING — jangan dipecah jadi beberapa panggilan: kode native
  /// `print_bluetooth_thermal` (`handleWriteBytes`) menyisipkan satu byte
  /// 0x0A (line feed) di AWAL setiap pemanggilan `writeBytes`. Bila job
  /// raster `GS v 0` dipecah jadi N panggilan, potongan ke-2..N mendapat
  /// 0x0A di TENGAH aliran raster → tiap baris setelahnya bergeser
  /// 1 byte (= 8 dots) ke kanan, terakumulasi tiap potongan. Itulah
  /// artefak "stair-step" di cetakan fisik (satu 0x0A di awal job tidak
  /// masalah: dieksekusi sebagai line feed kosong sebelum `ESC @`).
  /// Melempar [Exception] bila pengiriman gagal.
  Future<void> writeBytes(List<int> bytes) async {
    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    if (!ok) {
      throw Exception(
        'Gagal mengirim ${bytes.length} byte ke printer. '
        'Periksa koneksi lalu coba lagi.',
      );
    }
  }
}
