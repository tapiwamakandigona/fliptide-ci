import 'dart:convert';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<bool> saveImage(Uint8List png, String filename) async {
  final url = 'data:image/png;base64,${base64Encode(png)}';
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body!.append(a);
  a.click();
  a.remove();
  return true;
}
