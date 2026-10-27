import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/auth/auth_controller.dart';
import 'package:smart_farm/features/auth/auth_repository.dart';
import 'package:smart_farm/features/farm/farm_pages.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';
import 'package:smart_farm/features/farm/finance_page.dart';
import 'package:smart_farm/features/farm/inventory_page.dart';
import 'package:smart_farm/features/home/profile_page.dart';
import 'package:smart_farm/features/users/users_page.dart';

import 'farm_test.dart' as fixture;
import 'widget_test.dart' show MemoryStore;
import 'support/ui_preview.dart';

void main() {
  if (exportUiPreviews) {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUpAll(loadUiPreviewFonts);
  }
  for (final width in [320.0, 360.0, 412.0, 1200.0]) {
    for (final page in [
      'animals',
      'detail',
      'care',
      'inventory',
      'catalog',
      'finance',
      'users',
      'profile',
      'dashboard',
    ]) {
      testWidgets('$page fits $width with enlarged text', (t) async {
        t.view.physicalSize = Size(width, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        const user = FarmUser(
          id: 'owner',
          email: 'owner@example.test',
          name: 'Chủ trang trại',
          role: 'ADMIN',
          active: true,
        );
        final api = ApiClient(
          client: MockClient((r) async {
            if (r.url.path.endsWith('/weather')) {
              return fixture.response({
                'temperature': 29,
                'location': 'Trang trại',
                'description': 'mây nhẹ',
                'humidity': 76,
                'windSpeed': 2,
                'condition': 801,
              });
            }
            return fixture.response({
              ...fixture.catalogs,
              'animal': fixture.animal,
              'animals': [fixture.animal],
              'total': 1,
              'tasks': [],
              'entries': [],
              'feeds': [],
              'healthRecords': [],
              'weights': [],
              'transfers': [],
              'careTasks': [],
              'users': [
                {
                  'id': user.id,
                  'email': user.email,
                  'name': user.name,
                  'role': user.role,
                  'active': true,
                },
              ],
              'activeAnimals': 10,
              'activePens': 2,
              'needsCare': 1,
            });
          }),
        );
        addTearDown(api.dispose);
        final repository = FarmRepository(api);
        final auth = AuthController(AuthRepository(api, MemoryStore()))
          ..user = user;
        addTearDown(auth.dispose);
        final Widget content = switch (page) {
          'animals' => AnimalsPage(repository: repository, admin: true),
          'detail' => AnimalDetailPage(
            repository: repository,
            id: fixture.animal['id'] as String,
            admin: true,
          ),
          'care' => CarePage(repository: repository, admin: true),
          'inventory' => InventoryPage(repository: repository, admin: true),
          'catalog' => CatalogPage(repository: repository, admin: true),
          'finance' => FinancePage(repository: repository),
          'users' => UsersPage(api: api),
          'profile' => ProfilePage(auth: auth),
          _ => FarmDashboard(
            repository: repository,
            userName: user.name,
            admin: true,
            onAnimals: () {},
            onCare: () {},
          ),
        };
        final boundary = GlobalKey();
        await t.pumpWidget(
          MaterialApp(
            theme: farmTheme(),
            home: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 900),
                    textScaler: const TextScaler.linear(1.3),
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await exportUiPreview(t, boundary, '$page-${width.toInt()}.png');
        if (page == 'animals' && width == 320) {
          await t.tap(find.text('Bộ lọc vật nuôi'));
          await t.pumpAndSettle();
          final healthFilter = find.byKey(
            const ValueKey('Tình trạng sức khỏe-NEEDS_CARE'),
          );
          await t.ensureVisible(healthFilter);
          await t.pumpAndSettle();
          expect(find.text('Tình trạng sức khỏe'), findsOneWidget);
          expect(healthFilter, findsOneWidget);
          expect(t.takeException(), isNull);
        }
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}
