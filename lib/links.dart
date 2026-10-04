import 'package:url_launcher/url_launcher.dart';

import 'utils.dart';

Future<void> openGmaps(double lat, double lng) async {
  final uri = Uri.parse(gmapsUrl(lat, lng));
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {}
}

Future<void> openUrl(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}