import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/auth/login_page.dart';
import 'package:smart_farm/features/farm/species_chooser.dart';
import 'package:http/http.dart' as http;

import 'support/auth_onboarding_fixture.dart';
import 'support/ui_preview.dart';

Future<void> mountAuth(
  WidgetTester t,
  AuthOnboardingFixture fixture, {
  double width = 412,
  double keyboard = 0,
  bool species = false,
  GlobalKey? boundary,
  ValueChanged<List<String>>? onContinue,
}) async {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  t.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetViewInsets);
  addTearDown(fixture.dispose);
  await t.pumpWidget(
    MaterialApp(
      theme: farmTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.3)),
        child: RepaintBoundary(key: boundary, child: child!),
      ),
      home: species
          ? SpeciesChooser(
              repository: fixture.repository,
              admin: true,
              userName: 'Nguyễn An Nhiên có tên dài để kiểm tra xuống dòng',
              onContinue: onContinue ?? (_) {},
              onLogout: () {},
            )
          : LoginPage(auth: fixture.auth),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> fill(WidgetTester t, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await t.ensureVisible(field);
  await t.enterText(field, value);
}

Future<void> tapKey(WidgetTester t, String key) async {
  final target = find.byKey(ValueKey(key));
  await t.ensureVisible(target);
  await t.tap(target);
  await t.pumpAndSettle();
}

void main() {
  if (exportUiPreviews) {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUpAll(loadUiPreviewFonts);
  }

  testWidgets(
    'login preserves visibility, autofill, busy guard, input and error retry',
    (t) async {
      final pending = Completer<http.Response>();
      var calls = 0;
      final fixture = AuthOnboardingFixture(
        responder: (r) async {
          expectSync(r.url.path, '/api/auth/login');
          calls++;
          expectSync(jsonDecode(r.body)['email'], 'user@example.test');
          return calls == 1
              ? pending.future
              : authFixtureResponse({
                  'error': {'message': 'Thử lại thất bại.'},
                }, 401);
        },
      );
      await mountAuth(t, fixture);
      await fill(t, 'Email', ' user@example.test ');
      await fill(t, 'Mật khẩu', 'fixture-password');
      final password = find.widgetWithText(TextFormField, 'Mật khẩu');
      expect(
        t
            .widget<TextField>(
              find.descendant(of: password, matching: find.byType(TextField)),
            )
            .autofillHints,
        [AutofillHints.password],
      );
      await t.tap(find.byTooltip('Hiện mật khẩu'));
      await t.pump();
      expect(
        t
            .widget<TextField>(
              find.descendant(of: password, matching: find.byType(TextField)),
            )
            .obscureText,
        isFalse,
      );
      final submit = t
          .widget<FilledButton>(find.byKey(const ValueKey('auth-submit')))
          .onPressed!;
      submit();
      submit();
      await t.pump();
      expect(calls, 1);
      expect(t.widget<TextFormField>(password).enabled, isFalse);
      expect(
        t
            .widget<FilledButton>(find.byKey(const ValueKey('auth-submit')))
            .onPressed,
        isNull,
      );
      pending.complete(
        authFixtureResponse({
          'error': {
            'message': 'Không thể đăng nhập. Vui lòng kiểm tra email và thử lại kết nối với máy chủ.',
          },
        }, 401),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('Không thể đăng nhập.'), findsOneWidget);
      expect(
        t.widget<TextFormField>(password).controller!.text,
        'fixture-password',
      );
      await tapKey(t, 'auth-submit');
      expect(calls, 2);
      expect(find.text('Thử lại thất bại.'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'registration keeps field rules, matching confirmation and exact API body',
    (t) async {
      var calls = 0;
      final fixture = AuthOnboardingFixture(
        responder: (r) async {
          calls++;
          expectSync(r.url.path, '/api/auth/register');
          expectSync(jsonDecode(r.body), {
            'name': 'Chủ trại',
            'farmName': 'Trại mẫu',
            'email': 'owner@example.test',
            'password': 'fixture-password-123',
          });
          return authFixtureResponse({
            'error': {'message': 'Email đã tồn tại.'},
          }, 409);
        },
      );
      await mountAuth(t, fixture, keyboard: 300);
      await tapKey(t, 'auth-switch');
      await fill(t, 'Họ và tên', ' Chủ trại ');
      await fill(t, 'Tên trang trại', ' Trại mẫu ');
      await fill(t, 'Email', 'owner@example.test');
      await fill(t, 'Mật khẩu', 'short');
      await fill(t, 'Nhập lại mật khẩu', 'different');
      await tapKey(t, 'auth-submit');
      expect(calls, 0);
      expect(find.text('Mật khẩu cần ít nhất 12 ký tự.'), findsOneWidget);
      expect(find.text('Mật khẩu nhập lại chưa khớp.'), findsOneWidget);
      await fill(t, 'Mật khẩu', 'fixture-password-123');
      await fill(t, 'Nhập lại mật khẩu', 'fixture-password-123');
      final confirmation = t.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('auth-confirmation')),
          matching: find.byType(TextField),
        ),
      );
      expect(confirmation.obscureText, isTrue);
      expect(confirmation.autofillHints, [AutofillHints.newPassword]);
      await tapKey(t, 'auth-submit');
      expect(calls, 1);
      expect(find.text('Email đã tồn tại.'), findsOneWidget);
      expect(
        t.getBottomRight(find.byKey(const ValueKey('auth-submit'))).dy,
        lessThanOrEqualTo(600),
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'draft and field state survive desktop-mobile resize and keyboard',
    (t) async {
      await mountAuth(t, AuthOnboardingFixture(), width: 1200);
      await fill(t, 'Email', 'draft@example.test');
      await fill(t, 'Mật khẩu', 'fixture-password');
      final field = find.byKey(const ValueKey('auth-email'));
      final state = t.state(field);
      t.view.physicalSize = const Size(360, 900);
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      await t.pumpAndSettle();
      expect(t.state(field), same(state));
      expect(
        t.widget<TextFormField>(field).controller!.text,
        'draft@example.test',
      );
      expect(
        t.getBottomRight(find.byKey(const ValueKey('auth-submit'))).dy,
        lessThanOrEqualTo(600),
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'species restores real IDs, includes unknown species, saves groups and retries without duplicate',
    (t) async {
      final pending = Completer<http.Response>();
      var saves = 0;
      List<String>? continued;
      final fixture = AuthOnboardingFixture(
        responder: (r) async {
          if (r.method == 'PATCH') {
            saves++;
            expectSync(
              jsonDecode(r.body)['speciesIds'],
              containsAll(['cow', 'pig', 'goat']),
            );
            return saves == 1
                ? pending.future
                : authFixtureResponse({'ok': true});
          }
          if (r.url.path.endsWith('/preferences')) {
            return authFixtureResponse({
              'speciesIds': ['goat', 'deleted'],
            });
          }
          expectSync(r.url.queryParameters['includeAvailable'], 'true');
          return authFixtureResponse({
            'species': [
              ...AuthOnboardingFixture.species,
              {'id': 'camel', 'code': 'LA', 'name': 'Lạc đà'},
            ],
          });
        },
      );
      await mountAuth(
        t,
        fixture,
        species: true,
        onContinue: (ids) => continued = ids,
      );
      expect(find.text('Bạn đã chọn 1 loài'), findsOneWidget);
      expect(find.text('Cá rô phi nước ngọt có tên dài'), findsOneWidget);
      expect(find.byIcon(Icons.pets_outlined), findsOneWidget);
      await t.ensureVisible(find.text('Chọn theo nhóm'));
      await t.tap(find.text('Chọn theo nhóm'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Gia súc'));
      await t.tap(find.text('Gia súc'));
      await t.pumpAndSettle();
      expect(find.text('Bạn đã chọn 3 loài'), findsOneWidget);
      final submit = t
          .widget<FilledButton>(find.byKey(const ValueKey('species-continue')))
          .onPressed!;
      submit();
      submit();
      await t.pump();
      expect(saves, 1);
      expect(continued, isNull);
      await t.binding.handlePopRoute();
      await t.pump();
      expect(find.byType(SpeciesChooser), findsOneWidget);
      pending.complete(
        authFixtureResponse({
          'error': {'message': 'Lưu thất bại, vui lòng thử lại.'},
        }, 503),
      );
      await t.pumpAndSettle();
      expect(find.text('Bạn đã chọn 3 loài'), findsOneWidget);
      expect(find.text('Lưu thất bại, vui lòng thử lại.'), findsOneWidget);
      await tapKey(t, 'species-continue');
      expect(saves, 2);
      expect(continued, containsAll(['cow', 'pig', 'goat']));
      expect(continued, isNot(contains('deleted')));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('load failure offers retry and empty owner cannot bypass setup', (
    t,
  ) async {
    var fail = true;
    final fixture = AuthOnboardingFixture(
      responder: (r) async {
        expectSync(r.method, 'GET');
        if (fail) {
          return authFixtureResponse({
            'error': {'message': 'Không tải được danh sách.'},
          }, 503);
        }
        return authFixtureResponse({'species': [], 'speciesIds': []});
      },
    );
    await mountAuth(t, fixture, species: true);
    expect(find.text('Không tải được danh sách.'), findsOneWidget);
    expect(
      t
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Xem tất cả'),
          )
          .onPressed,
      isNull,
    );
    fail = false;
    await t.ensureVisible(find.text('Tải lại'));
    await t.tap(find.text('Tải lại'));
    await t.pumpAndSettle();
    expect(find.textContaining('Chưa có loài.'), findsOneWidget);
    expect(
      t
          .widget<FilledButton>(find.byKey(const ValueKey('species-continue')))
          .onPressed,
      isNull,
    );
    expect(
      t
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Xem tất cả'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Quản lý loài / giống'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'custom species can be selected and view-all sends every API ID',
    (t) async {
      final saved = <List<dynamic>>[];
      List<String>? continued;
      final fixture = AuthOnboardingFixture(
        responder: (r) async {
          if (r.method == 'PATCH') {
            saved.add(jsonDecode(r.body)['speciesIds'] as List<dynamic>);
            return authFixtureResponse({'ok': true});
          }
          if (r.url.path.endsWith('/preferences')) {
            return authFixtureResponse({
              'speciesIds': ['goat'],
            });
          }
          return authFixtureResponse({
            'species': AuthOnboardingFixture.species,
          });
        },
      );
      await mountAuth(
        t,
        fixture,
        species: true,
        onContinue: (ids) => continued = ids,
      );
      await tapKey(t, 'species-fish');
      await tapKey(t, 'species-continue');
      expect(saved.single, unorderedEquals(['goat', 'fish']));
      expect(continued, unorderedEquals(['goat', 'fish']));
      await t.tap(find.widgetWithText(OutlinedButton, 'Xem tất cả'));
      await t.pumpAndSettle();
      expect(
        saved.last,
        unorderedEquals(['cow', 'pig', 'goat', 'chicken', 'fish']),
      );
      expect(
        continued,
        unorderedEquals(['cow', 'pig', 'goat', 'chicken', 'fish']),
      );
      expect(t.takeException(), isNull);
    },
  );

  for (final width in [360.0, 412.0, 1200.0]) {
    for (final screen in ['login', 'register', 'species']) {
      for (final keyboard in screen == 'species' ? [0.0] : [0.0, 300.0]) {
        testWidgets(
          '$screen fits $width with keyboard $keyboard and scale 1.3',
          (t) async {
            final boundary = GlobalKey();
            await mountAuth(
              t,
              AuthOnboardingFixture(),
              width: width,
              keyboard: keyboard,
              species: screen == 'species',
              boundary: boundary,
            );
            if (screen == 'register') await tapKey(t, 'auth-switch');
            if (screen != 'species') {
              if (keyboard > 0) {
                final last = find.byKey(
                  ValueKey(
                    screen == 'register'
                        ? 'auth-confirmation'
                        : 'auth-password',
                  ),
                );
                await t.ensureVisible(last);
                await t.pumpAndSettle();
                expect(
                  t.getBottomRight(last).dy,
                  lessThanOrEqualTo(900 - keyboard - 100),
                );
              }
              final cta = find.byKey(const ValueKey('auth-submit'));
              expect(
                t.getBottomRight(cta).dy,
                lessThanOrEqualTo(900 - keyboard),
              );
              expect(t.getTopLeft(cta).dy, greaterThanOrEqualTo(0));
            }
            final context = t.element(find.byType(Scaffold).first);
            final images = t.widgetList<Image>(find.byType(Image)).toList();
            await t.runAsync(
              () => Future.wait(
                images.map((image) => precacheImage(image.image, context)),
              ),
            );
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            await exportUiPreview(
              t,
              boundary,
              '$screen-${width.toInt()}-${keyboard.toInt()}.png',
            );
            if (screen == 'species') {
              await t.ensureVisible(find.byKey(const ValueKey('species-fish')));
              await t.pumpAndSettle();
              expect(t.takeException(), isNull);
            }
          },
        );
      }
    }
  }
}
