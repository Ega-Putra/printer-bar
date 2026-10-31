// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabPrint => 'Print';

  @override
  String get tabSettings => 'Settings';

  @override
  String get appVersion => 'Printer Bar v1.2.0';

  @override
  String get privacyTitle => 'Privacy Policy';

  @override
  String get privacySubtitle => 'How this app handles your data';

  @override
  String get privacyOpenFailed => 'Couldn\'t open the privacy policy';

  @override
  String get paperTitle => 'Paper Size';

  @override
  String printWidth(int dots) {
    return 'Print width: $dots dots @ 203 dpi';
  }

  @override
  String get sourceTitle => 'Receipt Source';

  @override
  String get sourceHint =>
      'You can also open it via Share > Printer Bar from another app.';

  @override
  String get pickPdf => 'Pick PDF';

  @override
  String get pickImage => 'Pick Image';

  @override
  String get singleImage => '1 image';

  @override
  String pageCount(int count) {
    return '$count pages';
  }

  @override
  String get previewCropTitle => 'Preview & Crop';

  @override
  String get reset => 'Reset';

  @override
  String get cropHint =>
      'Drag corners/edges to resize • drag the center to move';

  @override
  String get detectingBarcode => 'Detecting barcode...';

  @override
  String barcodeNotFoundPage(int page) {
    return 'Barcode not found on page $page';
  }

  @override
  String barcodeOutsideCrop(int page) {
    return 'Barcode is outside the crop area on page $page';
  }

  @override
  String barcodeFoundRewritten(String value) {
    return 'Barcode found ✓\n$value (redrawn sharp)';
  }

  @override
  String get barcodeFoundImageCrop =>
      'Barcode found ✓\nValue unreadable — using image crop';

  @override
  String get printPreviewTitle => 'Print Preview';

  @override
  String printPreviewSubtitle(int page) {
    return 'Exactly as it will come out of the printer — page $page.';
  }

  @override
  String get printPreviewUnavailable =>
      'Preview not available yet (e.g. barcode not detected).';

  @override
  String get printOptionsTitle => 'Print Options';

  @override
  String get modeOriginal => 'Original';

  @override
  String get modeOriginalTooltip =>
      'Original print: the receipt as-is, full paper width';

  @override
  String get modeBarcode => 'Barcode';

  @override
  String get modeBarcodeTooltip =>
      'Enlarged barcode: the largest barcode is reprinted full-width below the receipt';

  @override
  String get orientationVertical => 'Vertical';

  @override
  String get orientationHorizontal => 'Horizontal';

  @override
  String get orientationVerticalTooltip =>
      'Vertical barcode (rotated 90°) — tap for horizontal';

  @override
  String get orientationHorizontalTooltip =>
      'Horizontal barcode — tap for vertical';

  @override
  String get dither => 'Dither';

  @override
  String get ditherTooltip => 'Dithering: photos and gradients print smoother';

  @override
  String get barcodeHeight => 'Barcode height:';

  @override
  String get bluetoothTitle => 'Bluetooth Printer';

  @override
  String get connected => 'Connected';

  @override
  String get bluetoothHint =>
      'Already-paired devices appear under \"Saved\". Turn the printer on, then scan to find nearby new devices.';

  @override
  String stopScanning(int count) {
    return 'Stop ($count)';
  }

  @override
  String get scanDevices => 'Scan Devices';

  @override
  String get scanningHint =>
      'Scanning for nearby devices... tap \"Stop\" once your printer appears.';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get savedDevices => 'Saved devices';

  @override
  String get availableDevices => 'Available devices';

  @override
  String get printButton => 'Print';

  @override
  String get printingButton => 'Printing...';

  @override
  String get progressOpeningPicker => 'Opening file picker...';

  @override
  String get progressRenderingPdf => 'Rendering PDF...';

  @override
  String get progressLoadingImage => 'Loading image...';

  @override
  String get progressRotatingImage => 'Rotating image...';

  @override
  String get progressPreparing => 'Preparing...';

  @override
  String progressPrintingPage(int page, int total) {
    return 'Printing page $page/$total...';
  }

  @override
  String shareFailed(String error) {
    return 'Failed to receive share: $error';
  }

  @override
  String get sharedPdfUnreadable => 'The shared PDF file couldn\'t be read.';

  @override
  String get pickerTimeout =>
      'The file picker didn\'t respond within 60 seconds.';

  @override
  String get pickerUnresponsivePdf =>
      'The file picker didn\'t respond. Try again, or open the PDF from File Manager and Share > Printer Bar.';

  @override
  String get pickerUnresponsiveShort =>
      'The file picker didn\'t respond. Try again.';

  @override
  String openPickerFailed(String error) {
    return 'Failed to open the file picker: $error';
  }

  @override
  String get pdfRenderTimeout =>
      'PDF rendering took too long (90 seconds). The file may be corrupt or unsupported.';

  @override
  String renderPdfFailed(String error) {
    return 'Failed to render PDF: $error';
  }

  @override
  String loadPdfFailed(String error) {
    return 'Failed to load PDF: $error';
  }

  @override
  String get imageUnreadable => 'The image file couldn\'t be read.';

  @override
  String get invalidImage => 'Not a valid image file.';

  @override
  String loadImageFailed(String error) {
    return 'Failed to load image: $error';
  }

  @override
  String rotateFailed(String error) {
    return 'Failed to rotate image: $error';
  }

  @override
  String detectBarcodeFailed(int page, String error) {
    return 'Barcode detection failed on page $page: $error';
  }

  @override
  String get bluetoothOff =>
      'Phone Bluetooth is off. Turn Bluetooth on first, then scan again.';

  @override
  String readBondedFailed(String error) {
    return 'Failed to read saved devices: $error';
  }

  @override
  String scanFailed(String error) {
    return 'Scan failed: $error';
  }

  @override
  String get scanStartFailed =>
      'Couldn\'t start Bluetooth scanning. Make sure Bluetooth is on.';

  @override
  String get noDevicesFound =>
      'No devices found. Make sure the printer is on and near your phone.';

  @override
  String connectedTo(String name) {
    return 'Connected to \"$name\"';
  }

  @override
  String get disconnected => 'Printer disconnected';

  @override
  String barcodeNotFoundThrow(int page) {
    return 'Barcode not found on page $page.';
  }

  @override
  String barcodeOutsideCropThrow(int page) {
    return 'Barcode is outside the crop area on page $page.';
  }

  @override
  String get printerDisconnected => 'Printer disconnected. Reconnect first.';

  @override
  String get printSuccess => 'Printed successfully 🎉';

  @override
  String printFailed(String error) {
    return 'Print failed: $error';
  }

  @override
  String get btPermissionDenied =>
      'Bluetooth permission not granted. Enable it in Settings > Apps > Printer Bar > Permissions, then try again.';

  @override
  String btConnectFailed(String name) {
    return 'Couldn\'t connect to \"$name\". Make sure the printer is on, near your phone, and not in use by another app. If prompted, approve pairing on your phone.';
  }

  @override
  String btWriteFailed(int count) {
    return 'Failed to send $count bytes to the printer. Check the connection and try again.';
  }

  @override
  String get pdfUnreadable =>
      'The PDF couldn\'t be read from your phone\'s storage. Try picking it again from File Manager.';

  @override
  String pdfNotFound(String path) {
    return 'PDF file not found at: $path';
  }

  @override
  String pdfRenderPageFailed(int page) {
    return 'Failed to render page $page';
  }
}
