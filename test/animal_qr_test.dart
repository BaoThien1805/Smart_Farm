import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/animal_detail_page.dart';
import 'package:smart_farm/features/farm/animal_qr.dart';
import 'package:smart_farm/features/farm/animal_qr_page.dart';
import 'package:smart_farm/features/farm/animal_scanner_page.dart';
import 'package:smart_farm/features/farm/animals_page.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';
import 'package:smart_farm/features/home/workspace_page.dart';

import 'support/animal_profile_fixture.dart';
import 'support/ui_preview.dart';
import 'support/workspace_fixture.dart';

const animalId = 'd3e00002-2026-4000-8000-000000000001';
final sample = FarmRecord({
  'id': animalId,
  'code': 'BO-001',
  'name': 'Bông nhỏ',
  'speciesName': 'Bò',
});

Future<void> mount(
  WidgetTester t,
  Widget page, {
  double width = 360,
  double scale = 1.3,
  GlobalKey? boundary,
}) async {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      theme: farmTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(key: boundary, child: child!),
      ),
      home: page,
    ),
  );
  await t.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester t, Finder target) async {
  await t.ensureVisible(target);
  await t.tap(target);
  await t.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (exportUiPreviews) setUpAll(loadUiPreviewFonts);

  test('versioned QR uses only the stable UUID', () {
    final payload = animalQrData(animalId.toUpperCase());
    expect(payload, 'smartfarm://animal/v1/$animalId');
    expect(animalIdFromQr('  $payload\n'), animalId);
    expect(
      animalQrData(
        FarmRecord({...sample.values, 'name': 'Tên mới', 'penId': 'new'}).id,
      ),
      payload,
    );
    expect(() => animalQrData('BO-001'), throwsArgumentError);
  });

  test(
    'external, malformed and future-version payloads are rejected safely',
    () {
      for (final payload in [
        '',
        animalId,
        'BO-001',
        'https://example.com/$animalId',
        'smartfarm://animal/v2/$animalId',
        'smartfarm://other/v1/$animalId',
        'smartfarm://user@animal/v1/$animalId',
        'smartfarm://animal:3000/v1/$animalId',
        'smartfarm://animal/v1/$animalId?token=secret',
        'smartfarm://animal/v1/$animalId#extra',
        'smartfarm://animal/v1/$animalId/extra',
        'smartfarm://animal/v1/../../users',
        'smartfarm://animal/v1/%FF',
        'smartfarm://animal/v1/%',
        'smartfarm://animal/v1/not-a-uuid',
        'x' * 257,
      ]) {
        expect(animalIdFromQr(payload), isNull, reason: payload);
      }
    },
  );

  testWidgets(
    'camera rejects unrelated QR and handles duplicate detections once',
    (t) async {
      late ValueChanged<String> detect;
      String? result;
      await mount(
        t,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => AnimalScannerPage(
                    cameraBuilder: (_, callback) {
                      detect = callback;
                      return const ColoredBox(color: FarmColors.sky);
                    },
                  ),
                ),
              );
            },
            child: const Text('scan'),
          ),
        ),
      );
      await tapVisible(t, find.text('scan'));
      detect('https://example.com');
      await t.pumpAndSettle();
      expect(find.textContaining('không phải QR vật nuôi'), findsOneWidget);
      expect(result, isNull);
      detect(animalQrData(animalId));
      detect(animalQrData(animalId));
      await t.pumpAndSettle();
      expect(result, animalId);
      expect(find.text('scan'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  for (final role in ['ADMIN', 'STAFF', 'VET', 'ACCOUNTANT']) {
    testWidgets(
      '$role scans from animals into authenticated detail with unchanged permissions',
      (t) async {
        final fixture = AnimalProfileFixture()..animal['id'] = animalId;
        addTearDown(fixture.dispose);
        final operate = ['ADMIN', 'STAFF'].contains(role);
        final examine = ['ADMIN', 'VET'].contains(role);
        final finance = ['ADMIN', 'ACCOUNTANT'].contains(role);
        await mount(
          t,
          Scaffold(
            body: AnimalsPage(
              repository: fixture.repository,
              admin: role == 'ADMIN',
              canOperate: operate,
              canCare: role != 'ACCOUNTANT',
              canExamine: examine,
              canFinance: finance,
            ),
          ),
        );
        await tapVisible(t, find.byKey(const ValueKey('animals-scan-qr')));
        await t.enterText(
          find.byKey(const ValueKey('qr-paste-field')),
          animalQrData(animalId),
        );
        await tapVisible(t, find.byKey(const ValueKey('qr-open-pasted')));
        final detail = t.widget<AnimalDetailPage>(
          find.byType(AnimalDetailPage),
        );
        expect(detail.id, animalId);
        expect(detail.admin, role == 'ADMIN');
        expect(detail.canOperate, operate);
        expect(detail.canCare, role != 'ACCOUNTANT');
        expect(detail.canExamine, examine);
        expect(detail.canFinance, finance);
        expect(
          fixture.requests.where(
            (r) => r.url.path.endsWith('/animals/$animalId'),
          ),
          hasLength(1),
        );
        await tapVisible(t, find.byKey(const ValueKey('animal-show-qr')));
        expect(
          t.widget<AnimalQrPage>(find.byType(AnimalQrPage)).animal.id,
          animalId,
        );
        expect(fixture.requests.every((r) => r.method == 'GET'), isTrue);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    testWidgets('$role has a scanner entry in More', (t) async {
      final fixture = WorkspaceFixture(role);
      addTearDown(fixture.dispose);
      await mount(t, WorkspacePage(auth: fixture.auth));
      await tapVisible(t, find.text('Thêm').last);
      await tapVisible(t, find.byKey(const ValueKey('more-scan-qr')));
      expect(find.byType(AnimalScannerPage), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.byType(AnimalDetailPage), findsNothing);
      expect(t.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  testWidgets(
    'foreign/deleted ID shows server rejection and never exposes a QR card',
    (t) async {
      final api = ApiClient(
        client: MockClient(
          (request) async => profileResponse(
            request.url.path.endsWith('/catalogs')
                ? AnimalProfileFixture.catalogs
                : {
                    'error': {'message': 'Không tìm thấy vật nuôi.'},
                  },
            request.url.path.endsWith('/catalogs') ? 200 : 404,
          ),
        ),
      );
      addTearDown(api.dispose);
      await mount(
        t,
        AnimalDetailPage(
          repository: FarmRepository(api),
          admin: false,
          id: animalId,
          canOperate: false,
          canCare: false,
        ),
      );
      expect(find.text('Không tìm thấy vật nuôi.'), findsOneWidget);
      expect(find.byKey(const ValueKey('animal-show-qr')), findsNothing);
    },
  );

  for (final status in ['SOLD', 'DEAD']) {
    testWidgets('$status retains its stable printable QR', (t) async {
      final fixture = AnimalProfileFixture()
        ..animal['id'] = animalId
        ..animal['status'] = status;
      addTearDown(fixture.dispose);
      await mount(
        t,
        AnimalDetailPage(
          repository: fixture.repository,
          admin: true,
          id: animalId,
        ),
      );
      await tapVisible(t, find.byKey(const ValueKey('animal-show-qr')));
      expect(find.byType(AnimalQrPage), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets(
    'PDF share failure can retry; busy state prevents duplicate export',
    (t) async {
      var calls = 0;
      final pending = Completer<void>();
      await mount(
        t,
        AnimalQrPage(
          animal: sample,
          sharePdf: (bytes, filename) async {
            calls++;
            expect(ascii.decode(bytes.take(4).toList()), '%PDF');
            expect(filename, 'smart-farm-$animalId.pdf');
            if (calls == 1) throw StateError('native share unavailable');
            await pending.future;
          },
        ),
      );
      final share = find.byKey(const ValueKey('qr-share-pdf'));
      await tapVisible(t, share);
      expect(find.text('Chưa xuất được thẻ QR. Hãy thử lại.'), findsOneWidget);
      await tapVisible(t, share);
      expect(calls, 2);
      expect(t.widget<FilledButton>(share).onPressed, isNull);
      expect(
        t
            .widget<OutlinedButton>(find.byKey(const ValueKey('qr-print')))
            .onPressed,
        isNull,
      );
      pending.complete();
      await t.pumpAndSettle();
      expect(t.widget<FilledButton>(share).onPressed, isNotNull);
      expect(find.text('Chưa xuất được thẻ QR. Hãy thử lại.'), findsNothing);
    },
  );

  testWidgets(
    'A6 label handles long Vietnamese text and print receives a PDF',
    (t) async {
      var printed = false;
      final longAnimal = FarmRecord({
        ...sample.values,
        'code': 'BO-THU-NGHIEM-00000000000000000001',
        'name':
            'Bông nhỏ có tên tiếng Việt rất dài để kiểm tra thẻ vật nuôi ' * 3,
        'speciesName': 'Bò sữa giống Hà Lan',
      });
      await mount(
        t,
        AnimalQrPage(
          animal: longAnimal,
          printPdf: (bytes) async {
            printed = true;
            expect(bytes.length, greaterThan(1000));
          },
        ),
      );
      await tapVisible(t, find.byKey(const ValueKey('qr-print')));
      expect(printed, isTrue);
      expect(find.text('Chưa xuất được thẻ QR. Hãy thử lại.'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  for (final width in [320.0, 412.0]) {
    testWidgets('QR pages fit ${width}px with enlarged text', (t) async {
      final boundary = GlobalKey();
      await mount(
        t,
        AnimalQrPage(animal: sample),
        width: width,
        scale: 1.5,
        boundary: boundary,
      );
      expect(t.takeException(), isNull);
      await exportUiPreview(t, boundary, 'qr-card-${width.toInt()}.png');
      await mount(
        t,
        AnimalScannerPage(
          cameraBuilder: (_, _) => const ColoredBox(color: FarmColors.sky),
        ),
        width: width,
        scale: 1.5,
        boundary: boundary,
      );
      expect(t.takeException(), isNull);
      await exportUiPreview(t, boundary, 'qr-scanner-${width.toInt()}.png');
    });
  }

  if (exportUiPreviews) {
    testWidgets('export decodable sample QR', (t) async {
      await t.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)
          ..drawColor(Colors.white, BlendMode.src)
          ..translate(50, 50);
        QrPainter(
          data: animalQrData(
            const String.fromEnvironment(
              'QR_PREVIEW_ANIMAL_ID',
              defaultValue: animalId,
            ),
          ),
          version: QrVersions.auto,
          gapless: true,
        ).paint(canvas, const Size.square(700));
        final picture = recorder.endRecording();
        final image = await picture.toImage(800, 800);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        picture.dispose();
        final dir = Directory('outputs/qr-review-20261025');
        await dir.create(recursive: true);
        await File('${dir.path}/sample-qr.png')
            .writeAsBytes(png!.buffer.asUint8List());
        final bytes = await animalQrPdf(
          FarmRecord({
            ...sample.values,
            'code': 'BO-THU-NGHIEM-00000000000000000001',
            'name':
                'Bông nhỏ có tên tiếng Việt rất dài để kiểm tra thẻ vật nuôi ' *
                3,
            'speciesName': 'Bò sữa giống Hà Lan',
          }),
        );
        await File('${dir.path}/animal-label.pdf')
            .writeAsBytes(bytes, flush: true);
      });
    });
  }
}
