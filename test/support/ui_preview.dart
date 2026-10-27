import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const exportUiPreviews = bool.fromEnvironment('EXPORT_UI_PREVIEWS');

Future<void> loadUiPreviewFonts() async {
  final font = FontLoader('FarmRoboto');
  for (final weight in ['regular', 'medium', 'bold']) {
    font.addFont(rootBundle.load('assets/fonts/roboto-$weight.ttf'));
  }
  await font.load();
  await (FontLoader(
    'FarmRound',
  )..addFont(rootBundle.load('assets/fonts/nunito-extra-bold.ttf'))).load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

Future<void> exportUiPreview(
  WidgetTester tester,
  GlobalKey boundary,
  String filename,
) async {
  if (!exportUiPreviews) return;
  // Image codecs run outside the fake clock. Export painted assets, rather than
  // the reserved blank boxes while a PNG is still being decoded.
  final context = boundary.currentContext!;
  final assets = tester
      .widgetList<Image>(find.byType(Image))
      .where(
        (image) =>
            image.image is AssetImage ||
            image.image is ResizeImage &&
                (image.image as ResizeImage).imageProvider is AssetImage,
      );
  await tester.runAsync(
    () => Future.wait([
      for (final image in assets) precacheImage(image.image, context),
    ]),
  );
  await tester.pump();
  final render =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await render.toImage();
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final folder = Directory(
        const String.fromEnvironment(
          'UI_PREVIEW_DIR',
          defaultValue: 'outputs/ui-refresh-20261013',
        ),
      );
      await folder.create(recursive: true);
      await File('${folder.path}/$filename')
          .writeAsBytes(png!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
