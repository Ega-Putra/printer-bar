/// Error bertipe dari lapisan service, TANPA pesan berbahasa di dalamnya.
///
/// Service tidak punya BuildContext sehingga tidak bisa mengakses
/// AppLocalizations. Sebagai gantinya service melempar exception bertipe
/// dengan data mentah saja; UI (home_screen, via `_localizedError`) yang
/// memetakan tipe ini ke string lokal sesuai bahasa sistem. Dengan begitu
/// pesan error ikut bahasa sistem, bukan menempel di bahasa Indonesia.
class BluetoothPermissionDenied implements Exception {
  const BluetoothPermissionDenied();
}

class BluetoothConnectFailed implements Exception {
  const BluetoothConnectFailed(this.deviceName);
  final String deviceName;
}

class BluetoothWriteFailed implements Exception {
  const BluetoothWriteFailed(this.byteCount);
  final int byteCount;
}

class PdfPickerTimeout implements Exception {
  const PdfPickerTimeout();
}

class PdfUnreadable implements Exception {
  const PdfUnreadable();
}

class PdfNotFound implements Exception {
  const PdfNotFound(this.path);
  final String path;
}

class PdfRenderPageFailed implements Exception {
  const PdfRenderPageFailed(this.page);
  final int page;
}

class InvalidImageFile extends FormatException {
  const InvalidImageFile() : super('Not a valid image file');
}
