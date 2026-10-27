import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/home/workspace_page.dart';

import 'support/final_review_fixture.dart';
import 'support/ui_preview.dart';

Future<void> capture(WidgetTester t, GlobalKey boundary, String name) async {
  final context = boundary.currentContext!;
  final images = t.widgetList<Image>(find.byType(Image)).toList();
  await t.runAsync(
    () => Future.wait(images.map((i) => precacheImage(i.image, context))),
  );
  await t.pumpAndSettle();
  await exportUiPreview(t, boundary, name);
}

void main() {
  if (exportUiPreviews) {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUpAll(loadUiPreviewFonts);
  }
  for (final width in [360.0, 412.0]) {
    testWidgets(
      'integrated mobile headings and Back at $width with scale 1.3',
      (t) async {
        t.view.physicalSize = Size(width, 892);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final fixture = FinalReviewFixture('ADMIN');
        addTearDown(fixture.dispose);
        final boundary = GlobalKey();
        await t.pumpWidget(
          MaterialApp(
            theme: farmTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: RepaintBoundary(key: boundary, child: child!),
            ),
            home: WorkspacePage(auth: fixture.auth),
          ),
        );
        await t.pumpAndSettle();
        expect(find.byType(AppBar), findsNothing);
        await capture(t, boundary, 'integrated-overview-${width.toInt()}.png');
        for (final entry in {
          'pens': 'Chuồng trại',
          'animals': 'Đàn vật nuôi',
        }.entries) {
          await t.tap(find.byKey(ValueKey('tab-${entry.key}')));
          await t.pumpAndSettle();
          expect(find.byType(AppBar), findsNothing);
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('workspace-content')),
              matching: find.text(entry.value),
            ),
            findsOneWidget,
          );
          await capture(
            t,
            boundary,
            'integrated-${entry.key}-${width.toInt()}.png',
          );
        }
        await t.tap(find.byKey(const ValueKey('tab-more')));
        await t.pumpAndSettle();
        final target = find.byKey(const ValueKey('more-inventory'));
        await t.ensureVisible(target);
        await t.tap(target);
        await t.pumpAndSettle();
        expect(find.byType(AppBar), findsNothing);
        expect(find.byKey(const ValueKey('workspace-back')), findsOneWidget);
        await capture(t, boundary, 'integrated-inventory-${width.toInt()}.png');
        await t.tap(find.byKey(const ValueKey('workspace-back')));
        await t.pumpAndSettle();
        expect(find.byType(AppBar), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }
}
