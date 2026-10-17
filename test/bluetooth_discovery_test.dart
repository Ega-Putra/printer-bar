import 'package:flutter_test/flutter_test.dart';
import 'package:thermal_print/services/bluetooth_printer_service.dart';

void main() {
  group('BluetoothPrinterService.dedupe', () {
    test('menghilangkan duplikat MAC, mempertahankan kemunculan pertama', () {
      final devices = [
        const PrinterDevice(name: 'Printer', mac: 'AA:BB:CC:DD:EE:01'),
        const PrinterDevice(name: 'Printer (1)', mac: 'AA:BB:CC:DD:EE:01'),
        const PrinterDevice(name: 'Lain', mac: 'AA:BB:CC:DD:EE:02'),
      ];
      final out = BluetoothPrinterService.dedupe(devices);
      expect(out.length, 2);
      expect(out[0].name, 'Printer');
      expect(out[1].mac, 'AA:BB:CC:DD:EE:02');
    });

    test('list kosong tetap kosong', () {
      expect(BluetoothPrinterService.dedupe([]), isEmpty);
    });

    test('tanpa duplikat, urutan tetap sama', () {
      final devices = [
        const PrinterDevice(name: 'A', mac: '11'),
        const PrinterDevice(name: 'B', mac: '22'),
      ];
      final out = BluetoothPrinterService.dedupe(devices);
      expect(out.map((d) => d.mac).toList(), ['11', '22']);
    });
  });

  group('BluetoothPrinterService.deviceKindFor', () {
    test('nama mengandung print selalu dianggap printer', () {
      const d = PrinterDevice(name: 'RPP02N Printer', mac: '11');
      expect(BluetoothPrinterService.deviceKindFor(d), DeviceKind.printer);
    });

    test('IMAGING (1536) → printer', () {
      const d = PrinterDevice(name: 'X', mac: '11', deviceClass: 1536);
      expect(BluetoothPrinterService.deviceKindFor(d), DeviceKind.printer);
    });

    test('AUDIO_VIDEO (1024) → headset', () {
      const d = PrinterDevice(name: 'Buds', mac: '11', deviceClass: 1024);
      expect(BluetoothPrinterService.deviceKindFor(d), DeviceKind.headset);
    });

    test('COMPUTER (256) → laptop', () {
      const d = PrinterDevice(name: 'PC', mac: '11', deviceClass: 256);
      expect(BluetoothPrinterService.deviceKindFor(d), DeviceKind.laptop);
    });

    test('PHONE (512) → phone', () {
      const d = PrinterDevice(name: 'HP', mac: '11', deviceClass: 512);
      expect(BluetoothPrinterService.deviceKindFor(d), DeviceKind.phone);
    });

    test('TOY (2048) → gamepad', () {
      const d =
          PrinterDevice(name: 'Controller', mac: '11', deviceClass: 2048);
      expect(BluetoothPrinterService.deviceKindFor(d), DeviceKind.gamepad);
    });

    test('tak dikenal → other', () {
      const d = PrinterDevice(name: 'X', mac: '11');
      expect(BluetoothPrinterService.deviceKindFor(d), DeviceKind.other);
      const d2 = PrinterDevice(name: 'Y', mac: '22', deviceClass: 9999);
      expect(BluetoothPrinterService.deviceKindFor(d2), DeviceKind.other);
    });
  });

  group('BluetoothPrinterService.sortPrintersFirst', () {
    test('printer di atas, sisanya alfabetis', () {
      final devices = [
        const PrinterDevice(name: 'Xbox', mac: '1', deviceClass: 2048),
        const PrinterDevice(name: 'Zebra Print', mac: '2'),
        const PrinterDevice(name: 'Buds', mac: '3', deviceClass: 1024),
        const PrinterDevice(name: 'A Printer', mac: '4', deviceClass: 1536),
      ];
      final out = BluetoothPrinterService.sortPrintersFirst(devices);
      expect(out.map((d) => d.mac).toList(), ['4', '2', '3', '1']);
    });

    test('tanpa printer, urutan alfabetis', () {
      final devices = [
        const PrinterDevice(name: 'Zebra', mac: '1'),
        const PrinterDevice(name: 'apel', mac: '2'),
      ];
      final out = BluetoothPrinterService.sortPrintersFirst(devices);
      expect(out.map((d) => d.mac).toList(), ['2', '1']);
    });
  });

  group('BluetoothPrinterService.deviceFromMap', () {
    test('mem-parsing name, mac, deviceClass', () {
      final d = BluetoothPrinterService.deviceFromMap({
        'name': 'RPP02N',
        'mac': 'AA:BB:CC:DD:EE:FF',
        'deviceClass': 1536,
      });
      expect(d, isNotNull);
      expect(d!.name, 'RPP02N');
      expect(d.mac, 'AA:BB:CC:DD:EE:FF');
      expect(d.deviceClass, 1536);
    });

    test('MAC kosong → null', () {
      expect(
          BluetoothPrinterService.deviceFromMap({'name': 'X', 'mac': ''}),
          isNull);
    });

    test('nama kosong → pakai MAC sebagai nama', () {
      final d = BluetoothPrinterService
          .deviceFromMap({'name': '', 'mac': 'AA:BB'});
      expect(d!.name, 'AA:BB');
    });
  });
}
