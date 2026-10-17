import 'package:flutter/material.dart';

import '../services/bluetooth_printer_service.dart';

/// Ikon untuk [DeviceKind] — mirip daftar Bluetooth bawaan HP.
IconData deviceIconFor(PrinterDevice device) {
  switch (BluetoothPrinterService.deviceKindFor(device)) {
    case DeviceKind.printer:
      return Icons.print;
    case DeviceKind.headset:
      return Icons.headset;
    case DeviceKind.laptop:
      return Icons.laptop;
    case DeviceKind.phone:
      return Icons.smartphone;
    case DeviceKind.gamepad:
      return Icons.gamepad;
    case DeviceKind.other:
      return Icons.bluetooth;
  }
}

/// Baris daftar perangkat Bluetooth.
class DeviceTile extends StatelessWidget {
  final PrinterDevice device;
  final bool connected;
  final bool busy;
  final VoidCallback onTap;

  const DeviceTile({
    super.key,
    required this.device,
    this.connected = false,
    this.busy = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(deviceIconFor(device)),
      title: Text(device.name),
      subtitle: Text(device.mac),
      trailing: connected
          ? const Icon(Icons.check_circle, color: Colors.green)
          : busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
      onTap: connected ? null : onTap,
    );
  }
}
