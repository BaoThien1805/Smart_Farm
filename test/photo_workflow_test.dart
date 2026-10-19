import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/core/photo_picker.dart';
import 'package:smart_farm/core/photo_view.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/animal_editor.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';

import 'farm_test.dart' as fixture;

class ImagePicker extends FileSelectorPlatform {
  final Uint8List bytes;
  ImagePicker(this.bytes);
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => XFile.fromData(bytes, name: 'camera.png', mimeType: 'image/png');
}

Future<Uint8List> cameraPhoto() async {
  final random = Random(42);
  final pixels = Uint8List(800 * 800 * 4);
  for (var i = 0; i < pixels.length; i += 4) {
    pixels[i] = random.nextInt(256);
    pixels[i + 1] = random.nextInt(256);
    pixels[i + 2] = random.nextInt(256);
    pixels[i + 3] = 255;
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: 800,
    height: 800,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final image = (await codec.getNextFrame()).image;
  try {
    return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();
  } finally {
    image.dispose();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
  }
}

void main() {
  testWidgets(
    'camera image over 1MB previews in editor and is uploaded under limit',
    (t) async {
      fixture.mobileSize(t);
      final bytes = (await t.runAsync(cameraPhoto))!;
      expect(bytes.length, greaterThan(1024 * 1024));
      final previous = FileSelectorPlatform.instance;
      FileSelectorPlatform.instance = ImagePicker(bytes);
      addTearDown(() => FileSelectorPlatform.instance = previous);
      Map<String, dynamic>? saved;
      final api = ApiClient(
        client: MockClient((r) async {
          if (r.method == 'PATCH') {
            saved = jsonDecode(r.body) as Map<String, dynamic>;
            return fixture.response({});
          }
          return fixture.response(fixture.catalogs);
        }),
      );
      addTearDown(api.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => animalForm(
                  context,
                  FarmRepository(api),
                  {},
                  FarmRecord(fixture.animal),
                  true,
                ),
                child: const Text('Sửa'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Sửa'));
      await t.pumpAndSettle();
      final pick = find.text('Chọn ảnh từ thiết bị');
      await t.ensureVisible(pick);
      await t.runAsync(() async {
        await t.tap(pick);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await t.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      await t.tap(find.text('Lưu'));
      await t.pumpAndSettle();
      expect(saved, isNotNull);
      final uploaded = base64Decode(saved!['photoBase64'] as String);
      expect(uploaded.length, lessThanOrEqualTo(1024 * 1024));
      final codec = await t.runAsync(() => ui.instantiateImageCodec(uploaded));
      final frame = await t.runAsync(codec!.getNextFrame);
      expect(frame!.image.width, 400);
      expect(frame.image.height, 400);
      frame.image.dispose();
      codec.dispose();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhotoView(
              data: 'data:image/png;base64,${saved!['photoBase64']}',
              size: 112,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'malformed saved image has a safe fallback; unsupported upload is rejected',
    (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PhotoView(data: '%%%')),
        ),
      );
      expect(find.byIcon(Icons.pets_outlined), findsOneWidget);
      expect(t.takeException(), isNull);
      await expectLater(
        preparePhotoForUpload(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<ApiException>()),
      );
    },
  );
}
