import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/features/farm/farm_pages.dart';
import 'package:smart_farm/features/farm/finance_page.dart';
import 'package:smart_farm/features/farm/farm_location_page.dart';
import 'package:smart_farm/features/farm/inventory_page.dart';
import 'package:smart_farm/features/farm/species_chooser.dart';
import 'package:smart_farm/features/farm/weather_card.dart';
import 'package:smart_farm/features/home/more_page.dart';
import 'package:smart_farm/features/home/profile_page.dart';
import 'package:smart_farm/features/home/workspace_page.dart';
import 'package:smart_farm/features/home/workspace_destination.dart';
import 'package:smart_farm/features/users/users_page.dart';
import 'package:smart_farm/core/theme.dart';

import 'support/ui_preview.dart';
import 'support/workspace_fixture.dart';

Future<WorkspaceFixture> mount(
  WidgetTester t,
  String role, {
  double width = 412,
  bool configured = true,
  GlobalKey? boundary,
}) async {
  t.view.physicalSize = Size(width, width < 1000 ? 900 : 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final fixture = WorkspaceFixture(role, configured: configured);
  addTearDown(fixture.dispose);
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
  return fixture;
}

Future<void> tapKey(WidgetTester t, String key) async {
  final target = find.byKey(ValueKey(key));
  await t.ensureVisible(target);
  await t.tap(target);
  await t.pumpAndSettle();
}

void expectMoreSelected(WidgetTester t) => expect(
  t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
  4,
);

void main() {
  if (exportUiPreviews) {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUpAll(loadUiPreviewFonts);
  }

  for (final role in ['ADMIN', 'STAFF', 'VET', 'ACCOUNTANT']) {
    testWidgets(
      '$role starts at the correct page and has role-aware More links',
      (t) async {
        final boundary = GlobalKey();
        final fixture = await mount(t, role, boundary: boundary);
        expect(
          find.byType(switch (role) {
            'STAFF' => AnimalsPage,
            'VET' => CarePage,
            'ACCOUNTANT' => FinancePage,
            _ => FarmDashboard,
          }),
          findsOneWidget,
        );
        final destinations = t.widgetList<NavigationDestination>(
          find.byType(NavigationDestination),
        );
        expect(destinations.map((d) => d.label), [
          'Tổng quan',
          'Chuồng trại',
          'Vật nuôi',
          'Lịch',
          'Thêm',
        ]);
        // Only the starting page is fetched; privileged destinations are lazy.
        expect(
          fixture.requests.any((r) => r.url.path.endsWith('/users')),
          isFalse,
        );
        if (role != 'ACCOUNTANT') {
          expect(
            fixture.requests.any((r) => r.url.path.contains('/finance/')),
            isFalse,
          );
        }
        await tapKey(t, 'tab-more');
        expectMoreSelected(t);
        expect(
          find.byKey(const ValueKey('more-users')),
          role == 'ADMIN' ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const ValueKey('more-finance')),
          ['ADMIN', 'ACCOUNTANT'].contains(role)
              ? findsOneWidget
              : findsNothing,
        );
        for (final key in ['inventory', 'catalog', 'profile', 'location']) {
          expect(find.byKey(ValueKey('more-$key')), findsOneWidget);
        }
        if (exportUiPreviews) {
          final context = t.element(find.byType(MorePage));
          final images = t.widgetList<Image>(find.byType(Image)).toList();
          await t.runAsync(
            () => Future.wait(
              images.map((image) => precacheImage(image.image, context)),
            ),
          );
          await t.pumpAndSettle();
          await exportUiPreview(t, boundary, 'more-role-$role.png');
        }
        await tapKey(t, 'more-inventory');
        expect(find.byType(InventoryPage), findsOneWidget);
        expectMoreSelected(t);
        final operates = ['ADMIN', 'STAFF'].contains(role);
        expect(
          fixture.requests.any((r) => r.url.path.endsWith('/stock-entries')),
          operates,
        );
        expect(
          find.text('Lịch sử nhập / xuất'),
          operates ? findsOneWidget : findsNothing,
        );
        expect(find.text('Nhập kho'), operates ? findsOneWidget : findsNothing);
        expect(find.text('Xuất kho'), operates ? findsOneWidget : findsNothing);
        expect(find.text('24 kg'), findsOneWidget);
        expect(find.byType(AppBar), findsNothing);
        // Android Back from a secondary page returns to More, not to app exit.
        await t.binding.handlePopRoute();
        await t.pumpAndSettle();
        expect(find.byType(MorePage), findsOneWidget);
        expectMoreSelected(t);
        if (role != 'ADMIN') {
          t
              .widget<MorePage>(find.byType(MorePage))
              .onOpen(WorkspaceDestination.users);
          await t.pumpAndSettle();
          expect(find.byType(MorePage), findsOneWidget);
          expect(
            fixture.requests.any((r) => r.url.path.endsWith('/users')),
            isFalse,
          );
        }
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'all More entries open the intended page and return with the toolbar Back',
    (t) async {
      await mount(t, 'ADMIN');
      await tapKey(t, 'tab-more');
      for (final entry in <String, Type>{
        'inventory': InventoryPage,
        'finance': FinancePage,
        'users': UsersPage,
        'catalog': CatalogPage,
        'profile': ProfilePage,
        'location': WeatherCard,
      }.entries) {
        await tapKey(t, 'more-${entry.key}');
        expect(find.byType(entry.value), findsOneWidget);
        expectMoreSelected(t);
        expect(find.byType(AppBar), findsNothing);
        await tapKey(t, 'workspace-back');
        expect(find.byType(MorePage), findsOneWidget);
      }
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'dashboard callbacks open animals, care, stock and finance by identity',
    (t) async {
      await mount(t, 'ADMIN');
      final dashboard = t.widget<FarmDashboard>(find.byType(FarmDashboard));
      for (final action in <VoidCallback, Type>{
        dashboard.onAnimals: AnimalsPage,
        dashboard.onCare: CarePage,
        dashboard.onStock!: InventoryPage,
        dashboard.onPens!: CatalogPage,
        dashboard.onFinance!: FinancePage,
      }.entries) {
        action.key();
        await t.pumpAndSettle();
        expect(find.byType(action.value), findsOneWidget);
        await tapKey(t, 'tab-overview');
      }
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'pens are separate from catalog and old animal routes keep working',
    (t) async {
      await mount(t, 'ADMIN');
      await tapKey(t, 'tab-pens');
      expect(t.widget<CatalogPage>(find.byType(CatalogPage)).availableKinds, [
        'pens',
      ]);
      expect(find.textContaining('A1'), findsOneWidget);
      expect(find.text('Chuồng mẫu'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Loài'), findsNothing);
      await tapKey(t, 'tab-more');
      await tapKey(t, 'more-catalog');
      expect(find.widgetWithText(ChoiceChip, 'Loài'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Giống'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Khu vực'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Chuồng'), findsNothing);
      await tapKey(t, 'tab-animals');
      await t.tap(find.byKey(const ValueKey('animal-animal')));
      await t.pumpAndSettle();
      expect(find.byType(AnimalDetailPage), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byType(AnimalsPage), findsOneWidget);
      expect(
        t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'profile draft survives tab changes, Back, and mobile-desktop resize',
    (t) async {
      await mount(t, 'STAFF');
      await tapKey(t, 'tab-more');
      await tapKey(t, 'more-profile');
      final field = find.widgetWithText(TextFormField, 'Mật khẩu mới');
      await t.ensureVisible(find.text('Đổi mật khẩu'));
      await t.tap(find.text('Đổi mật khẩu'));
      await t.pumpAndSettle();
      await t.ensureVisible(field);
      await t.enterText(field, 'draft-preview-123');
      final state = t.state(find.byType(ProfilePage));
      await tapKey(t, 'tab-animals');
      await tapKey(t, 'tab-more');
      await tapKey(t, 'more-profile');
      expect(t.state(find.byType(ProfilePage)), same(state));
      expect(
        t.widget<TextFormField>(field).controller!.text,
        'draft-preview-123',
      );
      t.view.physicalSize = const Size(1200, 1100);
      await t.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      expect(t.state(find.byType(ProfilePage)), same(state));
      expect(
        t.widget<TextFormField>(field).controller!.text,
        'draft-preview-123',
      );
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      await tapKey(t, 'nav-profile');
      expect(
        t.widget<TextFormField>(field).controller!.text,
        'draft-preview-123',
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Back dismisses a modal form before leaving its More destination',
    (t) async {
      await mount(t, 'ADMIN');
      await tapKey(t, 'tab-more');
      await tapKey(t, 'more-catalog');
      await t.tap(find.widgetWithText(FilledButton, 'Thêm'));
      await t.pumpAndSettle();
      expect(find.text('Thêm loài'), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Thêm loài'), findsNothing);
      expect(find.byType(CatalogPage), findsOneWidget);
      expectMoreSelected(t);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byType(MorePage), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'location saves refresh both cached pages and preserve dashboard category',
    (t) async {
      final fixture = await mount(t, 'ADMIN');
      final alerts = find.widgetWithText(ChoiceChip, 'Cảnh báo');
      await t.ensureVisible(alerts);
      await t.tap(alerts);
      await t.pumpAndSettle();
      await tapKey(t, 'tab-more');
      await tapKey(t, 'more-location');
      final weatherRequests = fixture.requests
          .where((r) => r.url.path.endsWith('/weather'))
          .length;
      await t.tap(find.widgetWithText(FilledButton, 'Đặt vị trí trang trại'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextFormField, 'Vĩ độ'), '11');
      await t.tap(find.widgetWithText(FilledButton, 'Lưu vị trí'));
      await t.pumpAndSettle();
      expect(find.text('Vĩ độ: 11.0'), findsOneWidget);
      expect(
        fixture.requests.where((r) => r.url.path.endsWith('/weather')).length,
        greaterThan(weatherRequests),
      );
      await tapKey(t, 'tab-overview');
      expect(t.widget<ChoiceChip>(alerts).selected, isTrue);
      final weather = find.byType(WeatherCard).first;
      await t.ensureVisible(weather);
      await t.tap(weather);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(TextButton, 'Đặt vị trí trang trại'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextFormField, 'Vĩ độ'), '12');
      await t.tap(find.widgetWithText(FilledButton, 'Lưu vị trí'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(TextButton, 'Đóng'));
      await t.pumpAndSettle();
      await tapKey(t, 'tab-more');
      await tapKey(t, 'more-location');
      expect(find.byType(FarmLocationPage), findsOneWidget);
      expect(find.text('Vĩ độ: 12.0'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('accountant initial finance returns to More on Back', (t) async {
    await mount(t, 'ACCOUNTANT');
    expectMoreSelected(t);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(MorePage), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('unconfigured owner still completes the existing species setup', (
    t,
  ) async {
    final fixture = await mount(t, 'ADMIN', configured: false);
    expect(find.byType(SpeciesChooser), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    final chooser = t.widget<SpeciesChooser>(find.byType(SpeciesChooser));
    chooser.onContinue(['goat']);
    await t.pumpAndSettle();
    expect(find.byType(FarmDashboard), findsOneWidget);
    expect(
      fixture.requests
          .where((r) => r.url.path.endsWith('/species-settings'))
          .length,
      1,
    );
    expect(t.takeException(), isNull);
  });

  for (final width in [360.0, 412.0, 1200.0]) {
    testWidgets('More and shell render at $width, text scale 1.3', (t) async {
      final boundary = GlobalKey();
      await mount(t, 'ADMIN', width: width, boundary: boundary);
      await tapKey(t, width >= 1000 ? 'nav-more' : 'tab-more');
      final context = t.element(find.byType(MorePage));
      final images = t.widgetList<Image>(find.byType(Image)).toList();
      await t.runAsync(
        () => Future.wait(
          images.map((image) => precacheImage(image.image, context)),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await exportUiPreview(t, boundary, 'more-${width.toInt()}.png');
      await t.ensureVisible(find.byKey(const ValueKey('more-location')));
      await t.pumpAndSettle();
      await exportUiPreview(t, boundary, 'more-bottom-${width.toInt()}.png');
      expect(t.takeException(), isNull);
    });
  }
}
