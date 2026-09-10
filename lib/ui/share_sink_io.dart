import 'package:share_plus/share_plus.dart';

/// Android: system share sheet. Returns a human label for the toast.
Future<String> shareTextOut(String text) async {
  await SharePlus.instance.share(ShareParams(text: text));
  return 'Shared';
}
