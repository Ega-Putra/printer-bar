import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @tabPrint.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get tabPrint;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Printer Bar v1.2.0'**
  String get appVersion;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyTitle;

  /// No description provided for @privacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How this app handles your data'**
  String get privacySubtitle;

  /// No description provided for @privacyOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the privacy policy'**
  String get privacyOpenFailed;

  /// No description provided for @paperTitle.
  ///
  /// In en, this message translates to:
  /// **'Paper Size'**
  String get paperTitle;

  /// No description provided for @printWidth.
  ///
  /// In en, this message translates to:
  /// **'Print width: {dots} dots @ 203 dpi'**
  String printWidth(int dots);

  /// No description provided for @sourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt Source'**
  String get sourceTitle;

  /// No description provided for @sourceHint.
  ///
  /// In en, this message translates to:
  /// **'You can also open it via Share > Printer Bar from another app.'**
  String get sourceHint;

  /// No description provided for @pickPdf.
  ///
  /// In en, this message translates to:
  /// **'Pick PDF'**
  String get pickPdf;

  /// No description provided for @pickImage.
  ///
  /// In en, this message translates to:
  /// **'Pick Image'**
  String get pickImage;

  /// No description provided for @singleImage.
  ///
  /// In en, this message translates to:
  /// **'1 image'**
  String get singleImage;

  /// No description provided for @pageCount.
  ///
  /// In en, this message translates to:
  /// **'{count} pages'**
  String pageCount(int count);

  /// No description provided for @previewCropTitle.
  ///
  /// In en, this message translates to:
  /// **'Preview & Crop'**
  String get previewCropTitle;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @cropHint.
  ///
  /// In en, this message translates to:
  /// **'Drag corners/edges to resize • drag the center to move'**
  String get cropHint;

  /// No description provided for @detectingBarcode.
  ///
  /// In en, this message translates to:
  /// **'Detecting barcode...'**
  String get detectingBarcode;

  /// No description provided for @barcodeNotFoundPage.
  ///
  /// In en, this message translates to:
  /// **'Barcode not found on page {page}'**
  String barcodeNotFoundPage(int page);

  /// No description provided for @barcodeOutsideCrop.
  ///
  /// In en, this message translates to:
  /// **'Barcode is outside the crop area on page {page}'**
  String barcodeOutsideCrop(int page);

  /// No description provided for @barcodeFoundRewritten.
  ///
  /// In en, this message translates to:
  /// **'Barcode found ✓\n{value} (redrawn sharp)'**
  String barcodeFoundRewritten(String value);

  /// No description provided for @barcodeFoundImageCrop.
  ///
  /// In en, this message translates to:
  /// **'Barcode found ✓\nValue unreadable — using image crop'**
  String get barcodeFoundImageCrop;

  /// No description provided for @printPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Print Preview'**
  String get printPreviewTitle;

  /// No description provided for @printPreviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Exactly as it will come out of the printer — page {page}.'**
  String printPreviewSubtitle(int page);

  /// No description provided for @printPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Preview not available yet (e.g. barcode not detected).'**
  String get printPreviewUnavailable;

  /// No description provided for @printOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Print Options'**
  String get printOptionsTitle;

  /// No description provided for @modeOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get modeOriginal;

  /// No description provided for @modeOriginalTooltip.
  ///
  /// In en, this message translates to:
  /// **'Original print: the receipt as-is, full paper width'**
  String get modeOriginalTooltip;

  /// No description provided for @modeBarcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get modeBarcode;

  /// No description provided for @modeBarcodeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Enlarged barcode: the largest barcode is reprinted full-width below the receipt'**
  String get modeBarcodeTooltip;

  /// No description provided for @orientationVertical.
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get orientationVertical;

  /// No description provided for @orientationHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Horizontal'**
  String get orientationHorizontal;

  /// No description provided for @orientationVerticalTooltip.
  ///
  /// In en, this message translates to:
  /// **'Vertical barcode (rotated 90°) — tap for horizontal'**
  String get orientationVerticalTooltip;

  /// No description provided for @orientationHorizontalTooltip.
  ///
  /// In en, this message translates to:
  /// **'Horizontal barcode — tap for vertical'**
  String get orientationHorizontalTooltip;

  /// No description provided for @dither.
  ///
  /// In en, this message translates to:
  /// **'Dither'**
  String get dither;

  /// No description provided for @ditherTooltip.
  ///
  /// In en, this message translates to:
  /// **'Dithering: photos and gradients print smoother'**
  String get ditherTooltip;

  /// No description provided for @barcodeHeight.
  ///
  /// In en, this message translates to:
  /// **'Barcode height:'**
  String get barcodeHeight;

  /// No description provided for @bluetoothTitle.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth Printer'**
  String get bluetoothTitle;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @bluetoothHint.
  ///
  /// In en, this message translates to:
  /// **'Already-paired devices appear under \"Saved\". Turn the printer on, then scan to find nearby new devices.'**
  String get bluetoothHint;

  /// No description provided for @stopScanning.
  ///
  /// In en, this message translates to:
  /// **'Stop ({count})'**
  String stopScanning(int count);

  /// No description provided for @scanDevices.
  ///
  /// In en, this message translates to:
  /// **'Scan Devices'**
  String get scanDevices;

  /// No description provided for @scanningHint.
  ///
  /// In en, this message translates to:
  /// **'Scanning for nearby devices... tap \"Stop\" once your printer appears.'**
  String get scanningHint;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @savedDevices.
  ///
  /// In en, this message translates to:
  /// **'Saved devices'**
  String get savedDevices;

  /// No description provided for @availableDevices.
  ///
  /// In en, this message translates to:
  /// **'Available devices'**
  String get availableDevices;

  /// No description provided for @printButton.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get printButton;

  /// No description provided for @printingButton.
  ///
  /// In en, this message translates to:
  /// **'Printing...'**
  String get printingButton;

  /// No description provided for @progressOpeningPicker.
  ///
  /// In en, this message translates to:
  /// **'Opening file picker...'**
  String get progressOpeningPicker;

  /// No description provided for @progressRenderingPdf.
  ///
  /// In en, this message translates to:
  /// **'Rendering PDF...'**
  String get progressRenderingPdf;

  /// No description provided for @progressLoadingImage.
  ///
  /// In en, this message translates to:
  /// **'Loading image...'**
  String get progressLoadingImage;

  /// No description provided for @progressRotatingImage.
  ///
  /// In en, this message translates to:
  /// **'Rotating image...'**
  String get progressRotatingImage;

  /// No description provided for @progressPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing...'**
  String get progressPreparing;

  /// No description provided for @progressPrintingPage.
  ///
  /// In en, this message translates to:
  /// **'Printing page {page}/{total}...'**
  String progressPrintingPage(int page, int total);

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to receive share: {error}'**
  String shareFailed(String error);

  /// No description provided for @sharedPdfUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The shared PDF file couldn\'t be read.'**
  String get sharedPdfUnreadable;

  /// No description provided for @pickerTimeout.
  ///
  /// In en, this message translates to:
  /// **'The file picker didn\'t respond within 60 seconds.'**
  String get pickerTimeout;

  /// No description provided for @pickerUnresponsivePdf.
  ///
  /// In en, this message translates to:
  /// **'The file picker didn\'t respond. Try again, or open the PDF from File Manager and Share > Printer Bar.'**
  String get pickerUnresponsivePdf;

  /// No description provided for @pickerUnresponsiveShort.
  ///
  /// In en, this message translates to:
  /// **'The file picker didn\'t respond. Try again.'**
  String get pickerUnresponsiveShort;

  /// No description provided for @openPickerFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open the file picker: {error}'**
  String openPickerFailed(String error);

  /// No description provided for @pdfRenderTimeout.
  ///
  /// In en, this message translates to:
  /// **'PDF rendering took too long (90 seconds). The file may be corrupt or unsupported.'**
  String get pdfRenderTimeout;

  /// No description provided for @renderPdfFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to render PDF: {error}'**
  String renderPdfFailed(String error);

  /// No description provided for @loadPdfFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load PDF: {error}'**
  String loadPdfFailed(String error);

  /// No description provided for @imageUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The image file couldn\'t be read.'**
  String get imageUnreadable;

  /// No description provided for @invalidImage.
  ///
  /// In en, this message translates to:
  /// **'Not a valid image file.'**
  String get invalidImage;

  /// No description provided for @loadImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image: {error}'**
  String loadImageFailed(String error);

  /// No description provided for @rotateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to rotate image: {error}'**
  String rotateFailed(String error);

  /// No description provided for @detectBarcodeFailed.
  ///
  /// In en, this message translates to:
  /// **'Barcode detection failed on page {page}: {error}'**
  String detectBarcodeFailed(int page, String error);

  /// No description provided for @bluetoothOff.
  ///
  /// In en, this message translates to:
  /// **'Phone Bluetooth is off. Turn Bluetooth on first, then scan again.'**
  String get bluetoothOff;

  /// No description provided for @readBondedFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to read saved devices: {error}'**
  String readBondedFailed(String error);

  /// No description provided for @scanFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {error}'**
  String scanFailed(String error);

  /// No description provided for @scanStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start Bluetooth scanning. Make sure Bluetooth is on.'**
  String get scanStartFailed;

  /// No description provided for @noDevicesFound.
  ///
  /// In en, this message translates to:
  /// **'No devices found. Make sure the printer is on and near your phone.'**
  String get noDevicesFound;

  /// No description provided for @connectedTo.
  ///
  /// In en, this message translates to:
  /// **'Connected to \"{name}\"'**
  String connectedTo(String name);

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Printer disconnected'**
  String get disconnected;

  /// No description provided for @barcodeNotFoundThrow.
  ///
  /// In en, this message translates to:
  /// **'Barcode not found on page {page}.'**
  String barcodeNotFoundThrow(int page);

  /// No description provided for @barcodeOutsideCropThrow.
  ///
  /// In en, this message translates to:
  /// **'Barcode is outside the crop area on page {page}.'**
  String barcodeOutsideCropThrow(int page);

  /// No description provided for @printerDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Printer disconnected. Reconnect first.'**
  String get printerDisconnected;

  /// No description provided for @printSuccess.
  ///
  /// In en, this message translates to:
  /// **'Printed successfully 🎉'**
  String get printSuccess;

  /// No description provided for @printFailed.
  ///
  /// In en, this message translates to:
  /// **'Print failed: {error}'**
  String printFailed(String error);

  /// No description provided for @btPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth permission not granted. Enable it in Settings > Apps > Printer Bar > Permissions, then try again.'**
  String get btPermissionDenied;

  /// No description provided for @btConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect to \"{name}\". Make sure the printer is on, near your phone, and not in use by another app. If prompted, approve pairing on your phone.'**
  String btConnectFailed(String name);

  /// No description provided for @btWriteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send {count} bytes to the printer. Check the connection and try again.'**
  String btWriteFailed(int count);

  /// No description provided for @pdfUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The PDF couldn\'t be read from your phone\'s storage. Try picking it again from File Manager.'**
  String get pdfUnreadable;

  /// No description provided for @pdfNotFound.
  ///
  /// In en, this message translates to:
  /// **'PDF file not found at: {path}'**
  String pdfNotFound(String path);

  /// No description provided for @pdfRenderPageFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to render page {page}'**
  String pdfRenderPageFailed(int page);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
