import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/core/ui_components.dart';
import 'package:smart_farm/features/farm/farm_widgets.dart';

import 'support/ui_preview.dart';

const fields = [
  FarmField('name', 'Tên'),
  FarmField('date', 'Ngày ghi nhận', initial: '2026-10-23', date: true),
  FarmField('kg', 'Cân nặng (kg)', numeric: true),
  FarmField('notes', 'Ghi chú', requiredValue: false),
];

Future<GlobalKey> openForm(
  WidgetTester t, {
  required double width,
  required Future<void> Function(Map<String, dynamic>) save,
  ValueChanged<bool>? onResult,
}) async {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetViewInsets);
  final boundary = GlobalKey();
  await t.pumpWidget(
    MaterialApp(
      theme: farmTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.3)),
        child: RepaintBoundary(key: boundary, child: child!),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                final saved = await farmForm(
                  context,
                  title: 'Ghi nhận cân nặng và ghi chú chăm sóc',
                  fields: fields,
                  save: save,
                );
                onResult?.call(saved);
              },
              child: const Text('Mở form'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('Mở form'));
  await t.pumpAndSettle();
  return boundary;
}

void main() {
  if (exportUiPreviews) {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUpAll(loadUiPreviewFonts);
  }
  for (final width in [360.0, 412.0, 1200.0]) {
    testWidgets(
      'form $width keeps save above keyboard and preserves retry/draft',
      (t) async {
        final savedBodies = <Map<String, dynamic>>[];
        var result = false;
        final boundary = await openForm(
          t,
          width: width,
          save: (body) async {
            savedBodies.add(body);
            if (savedBodies.length == 1) {
              throw const ApiException(
                'Không lưu được dữ liệu. Kiểm tra kết nối rồi thử lại; nội dung vừa nhập vẫn được giữ nguyên.',
              );
            }
          },
          onResult: (value) => result = value,
        );
        expect(
          find.byType(AlertDialog),
          width >= 600 ? findsOneWidget : findsNothing,
        );
        final name = find.widgetWithText(TextFormField, 'Tên');
        final kg = find.widgetWithText(TextFormField, 'Cân nặng (kg)');
        await exportUiPreview(t, boundary, 'form-${width.toInt()}.png');
        await t.enterText(
          name,
          'Vật nuôi có tên dài để kiểm tra giao diện tiếng Việt',
        );
        await t.enterText(kg, '0');
        t.view.viewInsets = const FakeViewPadding(bottom: 300);
        await t.pumpAndSettle();
        final saveButton = find.widgetWithText(FilledButton, 'Lưu');
        expect(t.getBottomRight(saveButton).dy, lessThanOrEqualTo(600));
        await t.tap(saveButton);
        await t.pumpAndSettle();
        expect(savedBodies, isEmpty);
        expect(find.text('Nhập số lớn hơn 0.'), findsOneWidget);
        await t.ensureVisible(kg);
        await t.enterText(kg, '25.5');
        await t.tap(saveButton);
        await t.pumpAndSettle();
        expect(find.textContaining('Không lưu được dữ liệu.'), findsOneWidget);
        expect(
          find.textContaining('Không lưu được dữ liệu.').hitTestable(),
          findsOneWidget,
        );
        expect(
          t.widget<TextFormField>(name).controller!.text,
          contains('tiếng Việt'),
        );
        expect(t.widget<TextFormField>(kg).controller!.text, '25.5');
        expect(t.takeException(), isNull);
        await exportUiPreview(
          t,
          boundary,
          'form-keyboard-${width.toInt()}.png',
        );
        await t.tap(saveButton);
        await t.pumpAndSettle();
        expect(result, isTrue);
        expect(savedBodies.length, 2);
        expect(savedBodies.first, savedBodies.last);
        expect(savedBodies.last['kg'], 25.5);
        expect(find.byType(FarmFormLayout), findsNothing);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'responsive form preserves draft and blocks dismissal/duplicate submit while busy',
    (t) async {
      final pending = Completer<void>();
      var calls = 0;
      bool? result;
      await openForm(
        t,
        width: 412,
        save: (_) {
          calls++;
          return pending.future;
        },
        onResult: (value) => result = value,
      );
      final name = find.widgetWithText(TextFormField, 'Tên');
      final kg = find.widgetWithText(TextFormField, 'Cân nặng (kg)');
      await t.enterText(name, 'Bông');
      await t.enterText(kg, '215.5');
      t.view.physicalSize = const Size(1200, 900);
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(t.widget<TextFormField>(name).controller!.text, 'Bông');
      t.view.physicalSize = const Size(412, 900);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await t.pump();
      expect(
        t.widget<TextButton>(find.widgetWithText(TextButton, 'Hủy')).onPressed,
        isNull,
      );
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Đang lưu…'),
            )
            .onPressed,
        isNull,
      );
      await t.binding.handlePopRoute();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byType(FarmFormLayout), findsOneWidget);
      expect(calls, 1);
      expect(result, isNull);
      pending.complete();
      await t.pumpAndSettle();
      expect(result, isTrue);
      expect(find.byType(FarmFormLayout), findsNothing);
    },
  );

  testWidgets('cancel returns false without calling save', (t) async {
    bool? result;
    await openForm(
      t,
      width: 360,
      save: (_) async => fail('Cancelled form saved'),
      onResult: (value) => result = value,
    );
    await t.tap(find.widgetWithText(TextButton, 'Hủy'));
    await t.pumpAndSettle();
    expect(result, isFalse);
    expect(find.byType(FarmFormLayout), findsNothing);
  });
}
