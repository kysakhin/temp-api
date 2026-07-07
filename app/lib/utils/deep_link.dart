import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'constants.dart';

/// Opens the bond in the BondScanner mobile app via custom scheme.
/// Falls back to the platform store listing if the app isn't installed.
Future<void> openBondInApp(String isin, {String? webFallback}) async {
  final appUri = Uri.parse('$bondScannerScheme$isin');

  if (await canLaunchUrl(appUri)) {
    await launchUrl(appUri, mode: LaunchMode.externalApplication);
    return;
  }

  final storeUrl = Platform.isIOS ? bondScannerAppStore : bondScannerPlayStore;
  final fallback = webFallback ?? storeUrl;
  await launchUrl(Uri.parse(fallback), mode: LaunchMode.externalApplication);
}
