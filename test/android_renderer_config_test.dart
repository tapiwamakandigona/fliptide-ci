import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release selects the conservative renderer at application scope', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync()
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
    final application = RegExp(
      r'<application\b[^>]*>([\s\S]*?)</application>',
    ).firstMatch(manifest);
    expect(application, isNotNull);
    final metadata = RegExp(r'<meta-data\b[^>]*>')
        .allMatches(application!.group(1)!)
        .map((match) => match.group(0)!)
        .where(
          (tag) => tag.contains(
            'android:name="io.flutter.embedding.android.EnableImpeller"',
          ),
        )
        .toList();
    expect(
      metadata,
      hasLength(1),
      reason: 'Keep the Android startup compatibility choice explicit.',
    );
    expect(metadata.single, contains('android:value="false"'));
  });
}
