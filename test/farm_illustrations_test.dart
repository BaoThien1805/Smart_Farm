import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/core/farm_illustrations.dart';
import 'package:smart_farm/core/theme.dart';

import 'support/illustrations_fixture.dart';
import 'support/ui_preview.dart';

class _MissingArtBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key.startsWith('assets/illustrations/')) {
      return Future<ByteData>.error(
        FlutterError('Missing illustration fixture'),
      );
    }
    return rootBundle.load(key);
  }
}

Widget _app(Widget child) => MaterialApp(
  theme: farmTheme(),
  home: Scaffold(body: child),
);

// Image codecs run outside the fake clock. Wait for the actual providers so
// exported PNGs cannot capture the reserved image boxes before pixels arrive.
Future<void> _waitForImagePixels(WidgetTester t) async {
  final context = t.element(find.byType(Scaffold).first);
  final images = t.widgetList<Image>(find.byType(Image)).toList();
  await t.runAsync(
    () =>
        Future.wait(images.map((image) => precacheImage(image.image, context))),
  );
  await t.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (exportUiPreviews) setUpAll(loadUiPreviewFonts);

  test(
    'species aliases use real catalog fields and never infer from pen IDs',
    () {
      expect(
        FarmSpeciesArt.fromSpecies(code: 'custom-id', name: '  Bò   sữa  '),
        FarmSpeciesArt.cow,
      );
      expect(FarmSpeciesArt.fromSpecies(name: 'Lợn'), FarmSpeciesArt.pig);
      expect(FarmSpeciesArt.fromSpecies(code: 'DE'), FarmSpeciesArt.goat);
      expect(FarmSpeciesArt.fromSpecies(name: 'Gà'), FarmSpeciesArt.chicken);
      for (final value in [
        'A1',
        'B1',
        'BO-001',
        'Lạc đà',
        'Vật nuôi mới',
        '',
      ]) {
        expect(FarmSpeciesArt.fromSpecies(code: value, name: value), isNull);
      }
    },
  );

  test(
    'bundled illustrations decode; stickers preserve transparent padding',
    () async {
      for (final art in FarmSpeciesArt.values) {
        final data = await rootBundle.load(art.asset);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 512);
        expect(frame.image.height, 512);
        final rgba = await frame.image.toByteData();
        expect(rgba!.getUint8(3), 0); // Top-left padding must be transparent.
        frame.image.dispose();
        codec.dispose();
      }
      final data = await rootBundle.load(FarmWelcomeBanner.asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      expect(frame.image.width / frame.image.height, 3);
      frame.image.dispose();
      codec.dispose();
    },
  );

  test('all twelve demo species have distinct art by real name and code', () {
    for (final (code, name, art) in [
      ('BO', 'Bò', FarmSpeciesArt.cow),
      ('HE', 'Heo', FarmSpeciesArt.pig),
      ('DE', 'Dê', FarmSpeciesArt.goat),
      ('GA', 'Gà', FarmSpeciesArt.chicken),
      ('TR', 'Trâu', FarmSpeciesArt.buffalo),
      ('CU', 'Cừu', FarmSpeciesArt.sheep),
      ('VI', 'Vịt', FarmSpeciesArt.duck),
      ('NG', 'Ngan', FarmSpeciesArt.muscovy),
      ('NO', 'Ngỗng', FarmSpeciesArt.goose),
      ('CA', 'Cá', FarmSpeciesArt.fish),
      ('TO', 'Tôm', FarmSpeciesArt.shrimp),
      ('TH', 'Thỏ', FarmSpeciesArt.rabbit),
    ]) {
      expect(FarmSpeciesArt.fromSpecies(name: '  $name  '), art);
      expect(FarmSpeciesArt.fromSpecies(code: code), art);
    }
    expect(
      FarmSpeciesArt.fromSpecies(name: 'Vịt xiêm'),
      FarmSpeciesArt.muscovy,
    );
    expect(FarmSpeciesArt.fromSpecies(name: 'Cừu'), isNot(FarmSpeciesArt.goat));
  });

  testWidgets('new species work in pen cards with no uploaded photo', (
    t,
  ) async {
    const species = ['Trâu', 'Cừu', 'Vịt', 'Ngan', 'Ngỗng', 'Cá', 'Tôm', 'Thỏ'];
    await t.pumpWidget(
      _app(
        Wrap(
          children: [
            for (final name in species)
              FarmPenIllustration(speciesNames: [name]),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(FarmSpeciesIllustration), findsNWidgets(species.length));
    expect(find.byIcon(Icons.pets_outlined), findsNothing);
    expect(find.byIcon(Icons.home_work_outlined), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('valid uploaded photo wins over the species illustration', (
    t,
  ) async {
    await t.pumpWidget(
      _app(
        const FarmAnimalImage(
          photoData: previewPhoto,
          speciesCode: 'BO',
          semanticLabel: 'Ảnh của Bông',
        ),
      ),
    );
    await t.pumpAndSettle();
    await _waitForImagePixels(t);
    final image = t.widget<Image>(find.byType(Image));
    expect(image.image, isA<MemoryImage>());
    expect(find.byType(FarmSpeciesIllustration), findsNothing);
    expect(find.bySemanticsLabel('Ảnh của Bông'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  for (final data in ['', '%%%', 'data:image/png;base64,AQID']) {
    testWidgets('empty or invalid photo safely uses the known species: $data', (
      t,
    ) async {
      await t.pumpWidget(
        _app(FarmAnimalImage(photoData: data, speciesCode: 'HEO')),
      );
      await t.pumpAndSettle();
      final image = t.widget<Image>(
        find.descendant(
          of: find.byType(FarmSpeciesIllustration),
          matching: find.byType(Image),
        ),
      );
      final provider = image.image is ResizeImage
          ? (image.image as ResizeImage).imageProvider
          : image.image;
      expect(provider, isA<AssetImage>());
      expect((provider as AssetImage).assetName, FarmSpeciesArt.pig.asset);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets(
    'unknown species and mixed pens have neutral accessible fallbacks',
    (t) async {
      await t.pumpWidget(
        _app(
          const Column(
            children: [
              FarmSpeciesIllustration(speciesName: 'Lạc đà'),
              FarmPenIllustration(key: ValueKey('neutral-pen')),
              FarmSpeciesIllustration(speciesName: 'Bò', decorative: true),
            ],
          ),
        ),
      );
      await t.pumpAndSettle();
      final semantics = t.ensureSemantics();
      expect(find.byIcon(Icons.pets_outlined), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('neutral-pen')),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Vật nuôi'), findsOneWidget);
      expect(find.bySemanticsLabel('Chuồng trại'), findsOneWidget);
      expect(find.bySemanticsLabel('Bò'), findsNothing);
      semantics.dispose();
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('missing packaged images fall back without an error surface', (
    t,
  ) async {
    await t.pumpWidget(
      _app(
        DefaultAssetBundle(
          bundle: _MissingArtBundle(),
          child: const Column(
            children: [
              FarmSpeciesIllustration(speciesCode: 'BO'),
              FarmWelcomeBanner(),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.pets_outlined), findsNothing);
    expect(find.byIcon(Icons.home_work_outlined), findsNWidgets(2));
    expect(find.byIcon(Icons.landscape_outlined), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'pen art follows actual residents, mixed and empty pens stay barns',
    (t) async {
      await t.pumpWidget(
        _app(
          const Column(
            children: [
              FarmPenIllustration(
                key: ValueKey('single'),
                speciesNames: ['Heo'],
              ),
              FarmPenIllustration(
                key: ValueKey('mixed'),
                speciesNames: ['Bò', 'Heo'],
              ),
              FarmPenIllustration(key: ValueKey('empty')),
            ],
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('single')),
          matching: find.byType(FarmSpeciesIllustration),
        ),
        findsOneWidget,
      );
      for (final key in ['mixed', 'empty']) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(FarmSpeciesIllustration),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(Image),
          ),
          findsOneWidget,
        );
      }
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('unknown species and missing pen art fall back to a barn', (
    t,
  ) async {
    await t.pumpWidget(
      _app(
        Column(
          children: [
            const FarmPenIllustration(
              key: ValueKey('unknown-pen'),
              speciesNames: ['Lạc đà'],
            ),
            DefaultAssetBundle(
              bundle: _MissingArtBundle(),
              child: const FarmPenIllustration(speciesNames: ['Bò']),
            ),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    final unknownImage = t.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('unknown-pen')),
        matching: find.byType(Image),
      ),
    );
    expect(
      (unknownImage.image as ResizeImage).imageProvider,
      isA<AssetImage>().having(
        (image) => image.assetName,
        'asset',
        FarmPenIllustration.asset,
      ),
    );
    expect(find.byIcon(Icons.home_work_outlined), findsOneWidget);
    expect(find.byIcon(Icons.pets_outlined), findsNothing);
    expect(t.takeException(), isNull);
  });

  for (final width in [360.0, 412.0, 1200.0]) {
    testWidgets(
      'illustration preview renders and scrolls at $width, scale 1.3',
      (t) async {
        t.view.physicalSize = Size(width, 1100);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        await t.pumpWidget(
          MaterialApp(
            theme: farmTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: RepaintBoundary(key: boundary, child: child!),
            ),
            home: const IllustrationsPreview(),
          ),
        );
        await t.pumpAndSettle();
        await _waitForImagePixels(t);
        expect(t.takeException(), isNull);
        expect(find.byIcon(Icons.pets_outlined), findsNothing);
        expect(find.byIcon(Icons.landscape_outlined), findsNothing);
        await exportUiPreview(
          t,
          boundary,
          'illustrations-${width.toInt()}.png',
        );
        await t.ensureVisible(find.text('Ảnh hợp lệ được ưu tiên'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      },
    );
  }
}
