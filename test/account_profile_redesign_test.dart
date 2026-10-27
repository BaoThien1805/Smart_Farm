import 'dart:async';
import 'dart:convert';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/auth/auth_repository.dart';
import 'package:smart_farm/features/auth/login_page.dart';
import 'package:smart_farm/features/auth/user_avatar.dart';
import 'package:smart_farm/features/home/profile_page.dart';
import 'package:smart_farm/features/home/password_change_view.dart';
import 'package:smart_farm/features/home/workspace_page.dart';

import 'photo_workflow_test.dart' show ImagePicker;
import 'support/account_profile_fixture.dart';
import 'support/animals_fixture.dart';
import 'support/ui_preview.dart';

class CancelledProfilePicker extends FileSelectorPlatform {
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => null;
}

Future<void> tapAccount(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

Finder passwordField(String label) => find.descendant(
  of: find.byType(PasswordChangeView),
  matching: find.widgetWithText(TextFormField, label),
);
TextField passwordInput(WidgetTester t, String label) => t.widget<TextField>(
  find.descendant(of: passwordField(label), matching: find.byType(TextField)),
);
Finder passwordSave() => find.widgetWithText(FilledButton, 'Cập nhật mật khẩu');
Finder accountIcon(String tooltip) =>
    find.byWidgetPredicate((w) => w is IconButton && w.tooltip == tooltip);
Future<void> fillAccount(WidgetTester t, String label, String value) async {
  await t.ensureVisible(passwordField(label));
  await t.enterText(passwordField(label), value);
  await t.pump();
}

Future<void> passwordDraft(
  WidgetTester t,
  AccountProfileFixture f, {
  String? current,
  String next = 'fixture-new-password',
}) async {
  await tapAccount(t, find.widgetWithText(OutlinedButton, 'Đổi mật khẩu'));
  await fillAccount(t, 'Mật khẩu hiện tại', current ?? f.credential);
  await fillAccount(t, 'Mật khẩu mới', next);
  await fillAccount(t, 'Nhập lại mật khẩu mới', next);
}

Future<GlobalKey> mountAccount(
  WidgetTester t,
  AccountProfileFixture f, {
  double width = 412,
  bool workspace = false,
}) async {
  t.view.physicalSize = Size(width, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetViewInsets);
  addTearDown(f.dispose);
  final boundary = GlobalKey();
  await t.pumpWidget(
    MaterialApp(
      theme: farmTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.3)),
        child: RepaintBoundary(key: boundary, child: child!),
      ),
      home: ListenableBuilder(
        listenable: f.auth,
        builder: (context, _) => f.auth.user == null
            ? LoginPage(auth: f.auth)
            : workspace
            ? WorkspacePage(auth: f.auth)
            : Scaffold(body: ProfilePage(auth: f.auth)),
      ),
    ),
  );
  await t.pumpAndSettle();
  return boundary;
}

Future<void> captureAccount(WidgetTester t, GlobalKey b, String name) async {
  if (exportUiPreviews) {
    await t.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  }
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
  await exportUiPreview(t, b, '$name.png');
}

void main() {
  if (exportUiPreviews) {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUpAll(loadUiPreviewFonts);
  }
  for (final role in ['ADMIN', 'STAFF', 'VET', 'ACCOUNTANT']) {
    testWidgets(
      '$role sees real account and farm fields; only ADMIN changes avatar',
      (t) async {
        final f = AccountProfileFixture(role);
        await mountAccount(t, f);
        expect(find.text(f.farmName!), findsOneWidget);
        expect(find.text(f.user['name'] as String), findsNWidgets(2));
        expect(find.text('NV-016'), findsOneWidget);
        expect(find.text('Đang hoạt động'), findsOneWidget);
        expect(
          find.text(FarmUser.fromJson(f.user).roleLabel),
          findsNWidgets(2),
        );
        expect(
          find.text('Đổi ảnh đại diện'),
          role == 'ADMIN' ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Xóa ảnh đại diện'),
          role == 'ADMIN' ? findsOneWidget : findsNothing,
        );
        expect(find.text('Ngày tham gia'), findsNothing);
        expect(find.text('Địa chỉ'), findsNothing);
        expect(f.avatarWrites, isEmpty);
        expect(f.farms.single.method, 'GET');
      },
    );
  }
  testWidgets(
    'real avatar is prioritized and malformed/missing photos fall back to human without invented code',
    (t) async {
      final f = AccountProfileFixture();
      await mountAccount(t, f);
      expect(t.widget<Image>(find.byType(Image)).image, isA<MemoryImage>());
      f.user['avatarData'] = '%%%';
      f.user['code'] = null;
      await tapAccount(t, find.text('Làm mới thông tin'));
      expect(find.byType(Image), findsNothing);
      expect(find.byType(UserAvatar), findsOneWidget);
      expect(find.text('Chưa có mã'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'refresh replaces account and farm data without edits or role escalation',
    (t) async {
      final f = AccountProfileFixture('STAFF');
      await mountAccount(t, f);
      f.user.addAll({
        'name': 'Tên mới từ API',
        'email': 'refreshed@example.test',
        'code': 'NV-NEW',
      });
      f.farmName = 'Tên trại mới từ API';
      await tapAccount(t, find.text('Làm mới thông tin'));
      expect(find.text('Tên mới từ API'), findsNWidgets(2));
      expect(find.text('NV-NEW'), findsOneWidget);
      expect(find.text(f.farmName!), findsOneWidget);
      expect(f.avatarWrites, isEmpty);
    },
  );
  testWidgets(
    'farm errors are independent, keep previous name labeled and allow password entry and retry',
    (t) async {
      final f = AccountProfileFixture()..failFarm = true;
      await mountAccount(t, f);
      expect(find.text('Không tải được tên trang trại.'), findsOneWidget);
      expect(find.text('Chưa có thông tin tên trang trại.'), findsNothing);
      expect(
        t
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Đổi mật khẩu'),
            )
            .onPressed,
        isNotNull,
      );
      f.failFarm = false;
      await tapAccount(t, find.text('Tải lại thông tin trại'));
      expect(find.text(f.farmName!), findsOneWidget);
      f.failFarm = true;
      await tapAccount(t, find.text('Làm mới thông tin'));
      expect(find.text(f.farmName!), findsOneWidget);
      expect(
        find.text('Đang hiển thị tên trại từ lần tải trước.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'missing farm name stays unknown, failed profile refresh keeps actual previous account and token',
    (t) async {
      final f = AccountProfileFixture()..farmName = null;
      await mountAccount(t, f);
      expect(find.text('Chưa có thông tin tên trang trại.'), findsOneWidget);
      f.failProfile = true;
      await tapAccount(t, find.text('Làm mới thông tin'));
      expect(find.text('Chưa tải được thông tin tài khoản.'), findsOneWidget);
      expect(find.text(f.user['name'] as String), findsNWidgets(2));
      expect(f.store.token, isNotNull);
      expect(f.auth.user, isNotNull);
    },
  );
  testWidgets(
    'ADMIN chooses avatar through existing PATCH then refreshes; removal sends null',
    (t) async {
      final f = AccountProfileFixture();
      await mountAccount(t, f);
      final original = FileSelectorPlatform.instance;
      FileSelectorPlatform.instance = ImagePicker(
        base64Decode(AnimalsFixture.photo),
      );
      addTearDown(() => FileSelectorPlatform.instance = original);
      await t.runAsync(() async {
        await t.tap(find.text('Đổi ảnh đại diện'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await t.pumpAndSettle();
      expect(f.avatarBodies.single['photoBase64'], isNotEmpty);
      expect(f.avatarWrites.single.method, 'PATCH');
      expect(f.avatarWrites.single.url.path, '/api/users/profile-user/avatar');
      expect(f.profiles.length, 1);
      await tapAccount(t, find.text('Xóa ảnh đại diện'));
      expect(f.avatarBodies.last, {'photoBase64': null});
      expect(find.byType(Image), findsNothing);
      expect(find.text('Xóa ảnh đại diện'), findsNothing);
    },
  );
  testWidgets(
    'canceling the file picker never writes or locks profile actions',
    (t) async {
      final f = AccountProfileFixture();
      await mountAccount(t, f);
      final original = FileSelectorPlatform.instance;
      FileSelectorPlatform.instance = CancelledProfilePicker();
      addTearDown(() => FileSelectorPlatform.instance = original);
      await tapAccount(t, find.text('Đổi ảnh đại diện'));
      expect(f.avatarWrites, isEmpty);
      expect(
        t
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Đổi mật khẩu'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );
  testWidgets(
    'invalid avatar input and rejected upload preserve the saved photo and support retry',
    (t) async {
      final f = AccountProfileFixture();
      await mountAccount(t, f);
      final original = FileSelectorPlatform.instance;
      FileSelectorPlatform.instance = ImagePicker(base64Decode('AAAA'));
      addTearDown(() => FileSelectorPlatform.instance = original);
      await t.runAsync(() async {
        await t.tap(find.text('Đổi ảnh đại diện'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await t.pumpAndSettle();
      expect(find.textContaining('Ảnh phải là JPEG/PNG'), findsOneWidget);
      expect(f.avatarWrites, isEmpty);
      expect(find.byType(Image), findsOneWidget);
      f.avatarError = 'Không lưu được ảnh đại diện.';
      await tapAccount(t, find.text('Xóa ảnh đại diện'));
      expect(find.text(f.avatarError!), findsOneWidget);
      expect(f.auth.user!.avatarData, isNotNull);
      f.avatarError = null;
      await tapAccount(t, find.text('Xóa ảnh đại diện'));
      expect(f.avatarWrites.length, 2);
      expect(f.auth.user!.avatarData, isNull);
    },
  );
  testWidgets(
    'avatar saved with failed refresh blocks resending and refresh alone restores model',
    (t) async {
      final f = AccountProfileFixture()..failProfile = true;
      await mountAccount(t, f);
      await tapAccount(t, find.text('Xóa ảnh đại diện'));
      expect(
        find.textContaining('Ảnh đã được lưu nhưng chưa tải lại thông tin.'),
        findsOneWidget,
      );
      expect(
        t
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Đổi ảnh đại diện'),
            )
            .onPressed,
        isNull,
      );
      expect(
        t
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Xóa ảnh đại diện'),
            )
            .onPressed,
        isNull,
      );
      expect(f.avatarWrites.length, 1);
      f.failProfile = false;
      await tapAccount(t, find.text('Làm mới thông tin'));
      expect(f.avatarWrites.length, 1);
      expect(f.auth.user!.avatarData, isNull);
      expect(find.text('Xóa ảnh đại diện'), findsNothing);
    },
  );
  testWidgets(
    'avatar pending request blocks duplicate changes, refresh, password entry and logout',
    (t) async {
      final f = AccountProfileFixture();
      final pending = Completer<void>();
      f.pendingAvatar = pending.future;
      await mountAccount(t, f);
      final callback = t
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Xóa ảnh đại diện'),
          )
          .onPressed!;
      callback();
      callback();
      await t.pump();
      expect(f.avatarWrites.length, 1);
      for (final label in ['Đổi mật khẩu', 'Đăng xuất']) {
        expect(
          t
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, label),
              )
              .onPressed,
          isNull,
        );
      }
      expect(
        t
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Làm mới thông tin'),
            )
            .onPressed,
        isNull,
      );
      pending.complete();
      await t.pumpAndSettle();
      expect(f.auth.user!.avatarData, isNull);
    },
  );
  testWidgets(
    'all password fields hide independently and retain correct autofill without suggestions',
    (t) async {
      final f = AccountProfileFixture();
      await mountAccount(t, f);
      await passwordDraft(t, f);
      final labels = [
        'Mật khẩu hiện tại',
        'Mật khẩu mới',
        'Nhập lại mật khẩu mới',
      ];
      final tips = ['mật khẩu hiện tại', 'mật khẩu mới', 'mật khẩu nhập lại'];
      for (var i = 0; i < 3; i++) {
        expect(passwordInput(t, labels[i]).obscureText, isTrue);
        expect(passwordInput(t, labels[i]).enableSuggestions, isFalse);
        expect(passwordInput(t, labels[i]).autocorrect, isFalse);
        expect(passwordInput(t, labels[i]).autofillHints, [
          i == 0 ? AutofillHints.password : AutofillHints.newPassword,
        ]);
        await tapAccount(t, find.byTooltip('Hiện ${tips[i]}'));
        expect(passwordInput(t, labels[i]).obscureText, isFalse);
        await tapAccount(t, find.byTooltip('Ẩn ${tips[i]}'));
        expect(passwordInput(t, labels[i]).obscureText, isTrue);
      }
      expect(f.passwords, isEmpty);
    },
  );
  testWidgets(
    'password validation keeps nonempty current, 12-128 new, different and matching confirmation rules',
    (t) async {
      final f = AccountProfileFixture();
      await mountAccount(t, f);
      await tapAccount(t, find.widgetWithText(OutlinedButton, 'Đổi mật khẩu'));
      await tapAccount(t, passwordSave());
      expect(find.text('Nhập mật khẩu hiện tại.'), findsOneWidget);
      expect(f.passwords, isEmpty);
      await fillAccount(t, 'Mật khẩu hiện tại', f.credential);
      for (final value in ['x' * 11, 'x' * 129, f.credential]) {
        await fillAccount(t, 'Mật khẩu mới', value);
        await fillAccount(t, 'Nhập lại mật khẩu mới', value);
        await tapAccount(t, passwordSave());
        expect(f.passwords, isEmpty);
      }
      await fillAccount(t, 'Mật khẩu mới', 'fixture-new-password');
      await fillAccount(t, 'Nhập lại mật khẩu mới', 'mismatch');
      await tapAccount(t, passwordSave());
      expect(find.text('Mật khẩu nhập lại không khớp.'), findsOneWidget);
      expect(f.passwords, isEmpty);
    },
  );
  testWidgets(
    'wrong current password stays signed in and retains the three drafts for correction',
    (t) async {
      final f = AccountProfileFixture();
      await mountAccount(t, f);
      await passwordDraft(t, f, current: 'fixture-wrong-password');
      await tapAccount(t, passwordSave());
      expect(
        find.text('Mật khẩu hiện tại không đúng.').hitTestable(),
        findsOneWidget,
      );
      expect(f.auth.user, isNotNull);
      expect(f.store.token, 'fixture-session');
      expect(f.api.token, 'fixture-session');
      expect(f.store.clears, 0);
      expect(
        t.widget<TextFormField>(passwordField('Mật khẩu mới')).controller!.text,
        'fixture-new-password',
      );
      await fillAccount(t, 'Mật khẩu hiện tại', f.credential);
      await tapAccount(t, passwordSave());
      expect(find.byType(LoginPage), findsOneWidget);
      expect(f.passwords.length, 2);
    },
  );
  for (final length in [12, 128]) {
    testWidgets(
      'new password length $length succeeds and forgets token only after API success',
      (t) async {
        final f = AccountProfileFixture('STAFF');
        await mountAccount(t, f);
        await passwordDraft(t, f, next: 'x' * length);
        await tapAccount(t, passwordSave());
        expect(f.passwords.single.method, 'POST');
        expect(f.passwords.single.url.path, '/api/auth/password');
        expect(f.passwordBodies.single.keys.toSet(), {
          'currentPassword',
          'newPassword',
        });
        expect(f.auth.user, isNull);
        expect(f.api.token, isNull);
        expect(f.store.token, isNull);
        expect(f.store.clears, 1);
        expect(f.sessionValid, isFalse);
        expect(f.logouts, isEmpty);
        expect(
          find.text('Đã đổi mật khẩu. Vui lòng đăng nhập bằng mật khẩu mới.'),
          findsOneWidget,
        );
      },
    );
  }
  testWidgets(
    'password error keeps token and retries same draft; old login fails and new login restores profile',
    (t) async {
      final f = AccountProfileFixture()
        ..passwordError =
            'Máy chủ chưa sẵn sàng. Dữ liệu nhập được giữ để bạn thử lại.';
      await mountAccount(t, f);
      final previous = f.credential;
      await passwordDraft(t, f);
      await tapAccount(t, passwordSave());
      expect(find.text(f.passwordError!).hitTestable(), findsOneWidget);
      expect(f.store.token, isNotNull);
      expect(f.auth.user, isNotNull);
      f.passwordError = null;
      await tapAccount(t, passwordSave());
      expect(f.passwordBodies.first, f.passwordBodies.last);
      expect(find.byType(LoginPage), findsOneWidget);
      await t.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        f.user['email'] as String,
      );
      await t.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu'),
        previous,
      );
      await tapAccount(t, find.widgetWithText(FilledButton, 'Đăng nhập'));
      expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);
      expect(f.store.token, isNull);
      await t.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu'),
        'fixture-new-password',
      );
      await tapAccount(t, find.widgetWithText(FilledButton, 'Đăng nhập'));
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(f.store.token, 'fixture-next-session');
      expect(f.api.token, 'fixture-next-session');
    },
  );
  testWidgets(
    'expired password request clears session and returns login without losing the existing expiry notice',
    (t) async {
      final f = AccountProfileFixture()..expirePassword = true;
      await mountAccount(t, f);
      await passwordDraft(t, f);
      await tapAccount(t, passwordSave());
      expect(find.byType(LoginPage), findsOneWidget);
      expect(f.auth.user, isNull);
      expect(f.api.token, isNull);
      expect(f.store.token, isNull);
      expect(f.auth.notice, contains('Phiên đã hết hạn'));
      expect(f.logouts, isEmpty);
    },
  );
  testWidgets(
    'password busy blocks fields, visibility, back, keyboard submit and same-frame double tap',
    (t) async {
      final f = AccountProfileFixture();
      final pending = Completer<void>();
      f.pendingPassword = pending.future;
      await mountAccount(t, f);
      await passwordDraft(t, f);
      final callback = t.widget<FilledButton>(passwordSave()).onPressed!;
      callback();
      callback();
      await t.pump();
      expect(f.passwords.length, 1);
      expect(f.store.token, isNotNull);
      for (final label in [
        'Mật khẩu hiện tại',
        'Mật khẩu mới',
        'Nhập lại mật khẩu mới',
      ]) {
        expect(t.widget<TextFormField>(passwordField(label)).enabled, isFalse);
      }
      expect(
        t.widget<IconButton>(accountIcon('Quay lại tài khoản')).onPressed,
        isNull,
      );
      expect(
        t.widget<IconButton>(accountIcon('Hiện mật khẩu mới')).onPressed,
        isNull,
      );
      await t.binding.handlePopRoute();
      await t.pump();
      expect(find.byType(PasswordChangeView), findsOneWidget);
      pending.complete();
      await t.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(f.passwords.length, 1);
    },
  );
  testWidgets(
    'profile password draft survives account Back and reopen without writing',
    (t) async {
      final f = AccountProfileFixture();
      await mountAccount(t, f);
      await passwordDraft(t, f);
      final staleSubmit = t.widget<FilledButton>(passwordSave()).onPressed!;
      await tapAccount(t, find.byTooltip('Quay lại tài khoản'));
      expect(find.text('Tài khoản của tôi'), findsOneWidget);
      staleSubmit();
      await t.pump();
      expect(f.passwords, isEmpty);
      await tapAccount(t, find.widgetWithText(OutlinedButton, 'Đổi mật khẩu'));
      expect(
        t
            .widget<TextFormField>(passwordField('Mật khẩu hiện tại'))
            .controller!
            .text,
        f.credential,
      );
      expect(
        t.widget<TextFormField>(passwordField('Mật khẩu mới')).controller!.text,
        'fixture-new-password',
      );
      expect(
        t
            .widget<TextFormField>(passwordField('Nhập lại mật khẩu mới'))
            .controller!
            .text,
        'fixture-new-password',
      );
      expect(f.passwords, isEmpty);
    },
  );
  for (final offline in [false, true]) {
    testWidgets(
      '${offline ? 'offline' : 'confirmed'} logout always clears token and redirects to Login',
      (t) async {
        final f = AccountProfileFixture('STAFF')..offlineLogout = offline;
        await mountAccount(t, f);
        await tapAccount(t, find.widgetWithText(OutlinedButton, 'Đăng xuất'));
        expect(f.logouts.single.method, 'POST');
        expect(f.logouts.single.body, isEmpty);
        expect(f.logouts.single.headers.containsKey('content-type'), isFalse);
        expect(f.auth.user, isNull);
        expect(f.api.token, isNull);
        expect(f.store.token, isNull);
        expect(find.byType(LoginPage), findsOneWidget);
        expect(
          f.auth.notice,
          offline
              ? contains('Chưa thể xác nhận thu hồi phiên')
              : 'Đã đăng xuất.',
        );
      },
    );
  }
  testWidgets(
    'logout pending blocks duplicate submission and clears only after completion',
    (t) async {
      final f = AccountProfileFixture();
      final pending = Completer<void>();
      f.pendingLogout = pending.future;
      await mountAccount(t, f);
      final callback = t
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Đăng xuất'),
          )
          .onPressed!;
      callback();
      callback();
      await t.pump();
      expect(f.logouts.length, 1);
      expect(f.store.token, isNotNull);
      expect(
        t
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Đổi mật khẩu'),
            )
            .onPressed,
        isNull,
      );
      pending.complete();
      await t.pumpAndSettle();
      expect(f.store.token, isNull);
      expect(find.byType(LoginPage), findsOneWidget);
    },
  );
  testWidgets(
    'workspace password error appears once and navigation retains the profile password view',
    (t) async {
      final f = AccountProfileFixture('STAFF');
      await mountAccount(t, f, workspace: true);
      await tapAccount(t, find.byKey(const ValueKey('tab-more')));
      await tapAccount(t, find.byKey(const ValueKey('more-profile')));
      await passwordDraft(t, f, current: 'fixture-wrong-password');
      await tapAccount(t, passwordSave());
      expect(find.text('Mật khẩu hiện tại không đúng.'), findsOneWidget);
      await tapAccount(t, find.byKey(const ValueKey('tab-animals')));
      await tapAccount(t, find.byKey(const ValueKey('tab-more')));
      await tapAccount(t, find.byKey(const ValueKey('more-profile')));
      expect(find.byType(PasswordChangeView), findsOneWidget);
      expect(
        t.widget<TextFormField>(passwordField('Mật khẩu mới')).controller!.text,
        'fixture-new-password',
      );
    },
  );
  for (final width in [360.0, 412.0, 1200.0]) {
    testWidgets(
      'account $width wraps long model values and farm errors at scale 1.3',
      (t) async {
        final f = AccountProfileFixture();
        final b = await mountAccount(t, f, width: width);
        await captureAccount(t, b, 'account-${width.toInt()}-top');
        await t.ensureVisible(find.widgetWithText(OutlinedButton, 'Đăng xuất'));
        await captureAccount(t, b, 'account-${width.toInt()}-bottom');
        f.failFarm = true;
        await tapAccount(t, find.text('Làm mới thông tin'));
        await t.ensureVisible(find.text('Không tải được tên trang trại.'));
        await captureAccount(t, b, 'account-${width.toInt()}-error');
      },
    );
    testWidgets(
      'password $width keeps CTA visible above keyboard and error/draft through resize',
      (t) async {
        final f = AccountProfileFixture()
          ..passwordError =
              'Không thể đổi mật khẩu lúc này. Thông tin nhập được giữ để kiểm tra và thử lại sau.';
        final b = await mountAccount(t, f, width: width);
        await passwordDraft(t, f);
        await t.ensureVisible(find.text('Đổi mật khẩu'));
        await captureAccount(t, b, 'password-${width.toInt()}-top');
        await t.ensureVisible(passwordField('Nhập lại mật khẩu mới'));
        await captureAccount(t, b, 'password-${width.toInt()}-bottom');
        t.view.viewInsets = const FakeViewPadding(bottom: 300);
        await t.pumpAndSettle();
        await t.ensureVisible(passwordField('Nhập lại mật khẩu mới'));
        await t.pumpAndSettle();
        expect(passwordSave().hitTestable(), findsOneWidget);
        expect(t.getBottomRight(passwordSave()).dy, lessThanOrEqualTo(800));
        await captureAccount(t, b, 'password-${width.toInt()}-keyboard');
        await tapAccount(t, passwordSave());
        expect(find.text(f.passwordError!).hitTestable(), findsOneWidget);
        await captureAccount(t, b, 'password-${width.toInt()}-error');
        t.view.viewInsets = const FakeViewPadding();
        t.view.physicalSize = Size(width < 600 ? 1200 : 360, 1100);
        await t.pumpAndSettle();
        expect(
          t
              .widget<TextFormField>(passwordField('Mật khẩu mới'))
              .controller!
              .text,
          'fixture-new-password',
        );
        expect(passwordInput(t, 'Mật khẩu mới').obscureText, isTrue);
      },
    );
  }
  testWidgets(
    'short landscape and keyboard leave password form scrollable with usable CTA',
    (t) async {
      final f = AccountProfileFixture();
      await mountAccount(t, f);
      await passwordDraft(t, f);
      t.view.physicalSize = const Size(932, 430);
      t.view.viewInsets = const FakeViewPadding(bottom: 180);
      await t.pumpAndSettle();
      await t.ensureVisible(passwordField('Nhập lại mật khẩu mới'));
      await t.pumpAndSettle();
      expect(passwordSave().hitTestable(), findsOneWidget);
      expect(t.getBottomRight(passwordSave()).dy, lessThanOrEqualTo(250));
      expect(t.takeException(), isNull);
    },
  );
}
