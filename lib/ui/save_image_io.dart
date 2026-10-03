import 'dart:io';
import 'dart:typed_data';

/// Android/desktop: write to the app's cache dir. Sharing to other apps lands
/// in phase 2 (share_plus). Returns the path via [lastSavedPath].
String? lastSavedPath;

Future<bool> saveImage(Uint8List png, String filename) async {
  final dir = Directory.systemTemp;
  final f = File('${dir.path}/$filename');
  await f.writeAsBytes(png, flush: true);
  lastSavedPath = f.path;
  return true;
}
