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
}
