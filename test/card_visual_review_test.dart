import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fliptide/main.dart';
import 'package:fliptide/sim/course_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/Inter-Variable.ttf').readAsBytesSync()))))
        .load();
  });
  for (final size in [const Size(300, 640), const Size(360, 640)]) {
    testWidgets('real card plates $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark().copyWith(
              textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Inter'),
            ),
            home: PlayScreen(seed: codeToSeed('400C1S')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      Future<void> plate(String state) async {
        final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await tester.runAsync(() => b.toImage(pixelRatio: 2));
        final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
        final name = '${state}_${size.width.toInt()}';
        File('build/visual-review/$name.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes!.buffer.asUint8List());
        if (Platform.environment['GITHUB_HEAD_REF'] == 'feat/visual-polish-20260905') {
          final encoded = base64Encode(bytes.buffer.asUint8List());
          for (var start = 0; start < encoded.length; start += 512) {
            final end = (start + 512).clamp(0, encoded.length);
            // ignore: avoid_print
            print('VISUAL_PNG:$name:$start:${encoded.substring(start, end)}');
          }
        }
        image!.dispose();
      }
      await plate('title');
      await tester.tapAt(Offset(size.width / 2, size.height / 2));
      for (var i = 0; i < 2400 && find.byKey(const Key('death-card')).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.byKey(const Key('death-card')), findsOneWidget);
      await plate('death');
      expect(tester.takeException(), isNull);
    });

    testWidgets('wordmark stays one line at ${size.width}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'Inter'),
        home: PlayScreen(seed: codeToSeed('400C1S')),
      ));
      await tester.pump();
      await tester.pump();
      final wordmark = find.text('Fliptide');
      final text = tester.widget<Text>(wordmark);
      expect(text.maxLines, 1, reason: 'wordmark/result must never wrap on a narrow phone');
      final paragraph = tester.renderObject<RenderParagraph>(wordmark);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
