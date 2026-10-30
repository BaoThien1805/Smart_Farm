import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/core/ui_components.dart';

import 'support/design_system_fixture.dart';
import 'support/ui_preview.dart';

void main() {
  if (exportUiPreviews) {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUpAll(loadUiPreviewFonts);
  }
  for (final width in [360.0, 412.0, 1200.0]) {
    testWidgets('shared components wrap long Vietnamese labels at $width', (
      t,
    ) async {
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
          home: const DesignSystemPreview(),
        ),
      );
      await t.pumpAndSettle();
      final badge = find.widgetWithText(
        FarmStatusBadge,
        'Kiểm tra sức khỏe theo lịch chăm sóc của trang trại',
      );
      expect(badge, findsOneWidget);
      final label = find.descendant(of: badge, matching: find.byType(Text));
      if (width < 600) {
        expect(t.getSize(label).height, greaterThan(30));
      }
      expect(t.getBottomRight(label).dx, lessThanOrEqualTo(width - 32));
      expect(t.takeException(), isNull);
      await exportUiPreview(t, boundary, 'components-${width.toInt()}.png');
      await t.ensureVisible(find.text('Mở form dùng chung'));
      await t.tap(find.text('Mở form dùng chung'));
      await t.pumpAndSettle();
      expect(find.byType(FarmFormLayout), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
