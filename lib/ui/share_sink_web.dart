import 'package:flutter/services.dart';

/// Web: clipboard (owner directive 2026-09-02e — pastes clean into WhatsApp).
Future<String> shareTextOut(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  return 'Copied — paste it anywhere';
}
