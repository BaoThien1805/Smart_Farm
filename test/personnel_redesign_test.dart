import 'dart:async';
import 'dart:convert';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/auth/auth_repository.dart';
import 'package:smart_farm/features/auth/user_avatar.dart';
import 'package:smart_farm/features/users/users_page.dart';
import 'package:smart_farm/features/users/users_controller.dart';
import 'package:smart_farm/features/users/personnel_form.dart';
import 'package:smart_farm/features/users/personnel_confirmation.dart';

import 'photo_workflow_test.dart' show ImagePicker;
import 'support/animals_fixture.dart';
import 'support/personnel_fixture.dart';
import 'support/ui_preview.dart';

bool passwordHidden(WidgetTester t) => t
    .widget<TextField>(
      find.descendant(
        of: personnelField('Mật khẩu ban đầu'),
        matching: find.byType(TextField),
      ),
    )
    .obscureText;

Finder personnelRow(String id) => find.byKey(ValueKey('personnel-$id'));
Finder personnelAction(String id, String text) =>
    find.descendant(of: personnelRow(id), matching: find.text(text));
Finder inPersonnel(Finder f) =>
    find.descendant(of: find.byType(PersonnelForm), matching: f);
Finder personnelField(String label) =>
    inPersonnel(find.widgetWithText(TextFormField, label));
Finder inConfirmation(Finder f) =>
    find.descendant(of: find.byType(PersonnelConfirmation), matching: f);
Future<void> tapPersonnel(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> personnelMenuAction(
  WidgetTester t,
  String id,
  String label,
) async {
  await tapPersonnel(t, find.byKey(ValueKey('personnel-menu-$id')));
  await tapPersonnel(t, find.widgetWithText(PopupMenuItem<String>, label));
}

Future<void> fillPersonnel(WidgetTester t, String label, String value) async {
  await t.ensureVisible(personnelField(label));
  await t.enterText(personnelField(label), value);
  await t.pump();
}

Future<GlobalKey> mountPersonnel(
  WidgetTester t,
  PersonnelFixture f, {
  double width = 412,
  Future<void> Function()? onProfileChanged,
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
      home: Scaffold(
        body: UsersPage(
          api: f.api,
          canManage: f.auth.user!.isAdmin,
          onProfileChanged: onProfileChanged,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return boundary;
}

Future<void> createPersonnelDraft(WidgetTester t) async {
  await tapPersonnel(t, find.text('Thêm nhân sự'));
  await fillPersonnel(t, 'Họ và tên', 'Nhân sự mới');
  await fillPersonnel(t, 'Email', 'new@example.test');
  await fillPersonnel(t, 'Mật khẩu ban đầu', 'fixture-only-password');
}

Future<void> selectPersonnelRole(WidgetTester t, String label) async {
  await tapPersonnel(
    t,
    inPersonnel(find.byType(DropdownButtonFormField<String>)),
  );
  await tapPersonnel(t, find.text(label).last);
}

Finder savePersonnel(bool create) => inPersonnel(
  find.widgetWithText(FilledButton, create ? 'Tạo tài khoản' : 'Lưu thay đổi'),
);
Future<void> capturePersonnel(WidgetTester t, GlobalKey b, String name) async {
  if (exportUiPreviews) {
    await t.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  }
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
  await exportUiPreview(t, b, '$name.png');
}

Future<void> openPersonnelMode(WidgetTester t, String mode) async {
  if (mode == 'create') {
    await tapPersonnel(t, find.text('Thêm nhân sự'));
  } else if (mode == 'edit') {
    await personnelMenuAction(t, 'staff', 'Chỉnh sửa');
  } else {
    await personnelMenuAction(
      t,
      mode == 'unlock' ? 'accountant' : 'staff',
      mode == 'delete'
          ? 'Xóa'
          : mode == 'unlock'
          ? 'Mở khóa'
          : 'Khóa',
    );
  }
}

Finder confirmPersonnel(String mode) => inConfirmation(
  find.widgetWithText(
    FilledButton,
    mode == 'delete'
        ? 'Xóa tài khoản'
        : mode == 'unlock'
        ? 'Mở khóa'
        : 'Khóa tài khoản',
  ),
);

void main() {
  if (exportUiPreviews) {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUpAll(loadUiPreviewFonts);
  }
  for (final role in ['ADMIN', 'STAFF', 'VET', 'ACCOUNTANT']) {
    testWidgets('$role personnel access is authorized before endpoint calls', (
      t,
    ) async {
      final f = PersonnelFixture(role);
      await mountPersonnel(t, f);
      if (role == 'ADMIN') {
        expect(find.text('Thêm nhân sự'), findsOneWidget);
        await tapPersonnel(
          t,
          find.byKey(const ValueKey('personnel-menu-owner')),
        );
        expect(
          find.widgetWithText(PopupMenuItem<String>, 'Khóa'),
          findsNothing,
        );
        expect(find.widgetWithText(PopupMenuItem<String>, 'Xóa'), findsNothing);
        expect(
          find.widgetWithText(PopupMenuItem<String>, 'Chỉnh sửa'),
          findsOneWidget,
        );
        await t.binding.handlePopRoute();
        await t.pumpAndSettle();
      } else {
        expect(
          find.text('Bạn không có quyền quản lý nhân sự.'),
          findsOneWidget,
        );
        expect(f.requests, isEmpty);
      }
    });
  }
  test('controller blocks admin creation, promotion, demotion, owner lock/delete and unauthorized writes', () async {
    final f = PersonnelFixture();
    addTearDown(f.dispose);
    final c = UsersController(f.api);
    addTearDown(c.dispose);
    final owner = FarmUser.fromJson(f.users.first),
        staff = FarmUser.fromJson(f.users[1]);
    expect(
      await c.create(
        'Tên',
        'a@example.test',
        'fixture-only-password',
        role: 'ADMIN',
      ),
      isFalse,
    );
    expect(await c.updateUser(owner, {'role': 'STAFF'}), isFalse);
    expect(await c.updateUser(staff, {'role': 'ADMIN'}), isFalse);
    expect(await c.setActive(owner, false), isFalse);
    expect(await c.deleteUser(owner), isFalse);
    final denied = UsersController(f.api, canManage: false);
    addTearDown(denied.dispose);
    await denied.load();
    expect(
      await denied.create('Tên', 'a@example.test', 'fixture-only-password'),
      isFalse,
    );
    expect(await denied.setAvatar(staff, null), isFalse);
    expect(f.requests, isEmpty);
  });
  testWidgets(
    'list uses actual photo, neutral fallbacks and all real role/status/code/email fields',
    (t) async {
      final f = PersonnelFixture();
      await mountPersonnel(t, f);
      final photo = find.descendant(
        of: personnelRow('staff'),
        matching: find.byType(Image),
      );
      expect(t.widget<Image>(photo).image, isA<MemoryImage>());
      expect(
        find.descendant(
          of: personnelRow('vet'),
          matching: find.byType(UserAvatar),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: personnelRow('vet'), matching: find.byType(Image)),
        findsNothing,
      );
      expect(personnelAction('accountant', 'Đã khóa'), findsOneWidget);
      expect(personnelAction('accountant', 'Kế toán'), findsOneWidget);
      expect(personnelAction('staff', 'Mã nhân sự: NV-001'), findsOneWidget);
      expect(
        personnelAction('staff', 'nhanvien.diachi.email.dai@example.test'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'create validates name/email/password bounds without writing and supports only three roles',
    (t) async {
      final f = PersonnelFixture();
      await mountPersonnel(t, f);
      await tapPersonnel(t, find.text('Thêm nhân sự'));
      expect(f.suggestions.single.url.queryParameters['kind'], 'users');
      expect(
        t.widget<TextFormField>(personnelField('Mã nhân sự')).controller!.text,
        'NV-004',
      );
      final roles = t
          .widget<DropdownButton<String>>(
            inPersonnel(find.byType(DropdownButton<String>)),
          )
          .items!
          .map((e) => e.value);
      expect(roles, ['STAFF', 'VET', 'ACCOUNTANT']);
      expect(inPersonnel(find.text('Chọn ảnh')), findsNothing);
      for (final name in ['A', 'A' * 101]) {
        await fillPersonnel(t, 'Họ và tên', name);
        await tapPersonnel(t, savePersonnel(true));
        expect(f.writes, isEmpty);
      }
      await fillPersonnel(t, 'Họ và tên', 'Tên hợp lệ');
      await fillPersonnel(t, 'Email', 'bad');
      await tapPersonnel(t, savePersonnel(true));
      expect(f.writes, isEmpty);
      await fillPersonnel(t, 'Email', 'new@example.test');
      for (final password in ['short', 'x' * 129]) {
        await fillPersonnel(t, 'Mật khẩu ban đầu', password);
        await tapPersonnel(t, savePersonnel(true));
        expect(f.writes, isEmpty);
      }
      expect(passwordHidden(t), isTrue);
      await tapPersonnel(t, inPersonnel(find.byTooltip('Hiện mật khẩu')));
      expect(passwordHidden(t), isFalse);
      await tapPersonnel(t, inPersonnel(find.byTooltip('Ẩn mật khẩu')));
      expect(passwordHidden(t), isTrue);
    },
  );
  testWidgets(
    'create keeps manual code and selected role, retries duplicate email with draft intact',
    (t) async {
      final f = PersonnelFixture()..writeError = 'Email đã được sử dụng.';
      await mountPersonnel(t, f);
      await createPersonnelDraft(t);
      await fillPersonnel(t, 'Mã nhân sự', 'CUSTOM-01');
      await selectPersonnelRole(t, 'Bác sĩ thú y');
      await tapPersonnel(t, savePersonnel(true));
      expect(find.text(f.writeError!).hitTestable(), findsOneWidget);
      final body = f.bodies.single;
      expect(body.keys.toSet(), {'name', 'email', 'password', 'role', 'code'});
      expect(body['role'], 'VET');
      expect(body['code'], 'CUSTOM-01');
      expect(
        t.widget<TextFormField>(personnelField('Họ và tên')).controller!.text,
        'Nhân sự mới',
      );
      f.writeError = null;
      await tapPersonnel(t, savePersonnel(true));
      expect(f.bodies.last, body);
      expect(f.lists.last.url.queryParameters, {'page': '1', 'pageSize': '20'});
      expect(find.byType(PersonnelForm), findsNothing);
      expect(find.text('Nhân sự mới'), findsOneWidget);
    },
  );
  testWidgets(
    'canceling edit keeps email role and image unchanged; editing never suggests a new code or password',
    (t) async {
      final f = PersonnelFixture();
      await mountPersonnel(t, f);
      await openPersonnelMode(t, 'edit');
      expect(f.suggestions, isEmpty);
      expect(personnelField('Mật khẩu ban đầu'), findsNothing);
      await fillPersonnel(t, 'Email', 'draft@example.test');
      await selectPersonnelRole(t, 'Kế toán');
      await tapPersonnel(t, inPersonnel(find.text('Bỏ ảnh')));
      await tapPersonnel(t, inPersonnel(find.text('Hủy')));
      expect(f.writes, isEmpty);
      expect(f.users[1]['role'], 'STAFF');
      expect(f.users[1]['avatarData'], isNotNull);
    },
  );
  testWidgets(
    'edit saves email role and removed photo together, refreshes list/profile and revokes changed role in fixture',
    (t) async {
      final f = PersonnelFixture();
      var refreshed = 0;
      await mountPersonnel(
        t,
        f,
        onProfileChanged: () async {
          refreshed++;
        },
      );
      await openPersonnelMode(t, 'edit');
      await fillPersonnel(t, 'Email', 'edited@example.test');
      await fillPersonnel(t, 'Họ và tên', 'Tên đã sửa');
      await selectPersonnelRole(t, 'Kế toán');
      await tapPersonnel(t, inPersonnel(find.text('Bỏ ảnh')));
      await tapPersonnel(t, savePersonnel(false));
      expect(f.writes.single.method, 'PATCH');
      expect(f.writes.single.url.path, endsWith('/users/staff'));
      expect(f.bodies.single, {
        'name': 'Tên đã sửa',
        'email': 'edited@example.test',
        'role': 'ACCOUNTANT',
        'code': 'NV-001',
        'photoBase64': null,
      });
      expect(f.revoked, ['staff']);
      expect(refreshed, 1);
      expect(personnelAction('staff', 'Kế toán'), findsOneWidget);
    },
  );
  testWidgets('choose avatar is a draft saved only with profile PATCH', (
    t,
  ) async {
    final f = PersonnelFixture();
    await mountPersonnel(t, f);
    await openPersonnelMode(t, 'edit');
    final original = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = ImagePicker(
      base64Decode(AnimalsFixture.photo),
    );
    addTearDown(() => FileSelectorPlatform.instance = original);
    await t.runAsync(() async {
      await t.tap(inPersonnel(find.text('Chọn ảnh')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await t.pumpAndSettle();
    expect(f.writes, isEmpty);
    expect(
      t.widget<Image>(inPersonnel(find.byType(Image))).image,
      isA<MemoryImage>(),
    );
    await tapPersonnel(t, savePersonnel(false));
    expect(f.bodies.single['photoBase64'], isNotEmpty);
    expect(f.writes.single.url.path, endsWith('/users/staff'));
  });
  testWidgets('bad avatar file reports error while preserving typed draft', (
    t,
  ) async {
    final f = PersonnelFixture();
    await mountPersonnel(t, f);
    await openPersonnelMode(t, 'edit');
    await fillPersonnel(t, 'Họ và tên', 'Giữ nháp ảnh lỗi');
    final original = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = ImagePicker(base64Decode('AAAA'));
    addTearDown(() => FileSelectorPlatform.instance = original);
    await t.runAsync(() async {
      await t.tap(inPersonnel(find.text('Chọn ảnh')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await t.pumpAndSettle();
    expect(
      find.textContaining('Ảnh phải là JPEG/PNG').hitTestable(),
      findsOneWidget,
    );
    expect(f.writes, isEmpty);
    expect(
      t.widget<TextFormField>(personnelField('Họ và tên')).controller!.text,
      'Giữ nháp ảnh lỗi',
    );
  });
  testWidgets(
    'owner edit preserves ADMIN role with no role dropdown and permits email update',
    (t) async {
      final f = PersonnelFixture();
      await mountPersonnel(t, f);
      await personnelMenuAction(t, 'owner', 'Chỉnh sửa');
      expect(
        inPersonnel(find.byType(DropdownButtonFormField<String>)),
        findsNothing,
      );
      await fillPersonnel(t, 'Email', 'owner-updated@example.test');
      await tapPersonnel(t, savePersonnel(false));
      expect(f.bodies.single['role'], 'ADMIN');
      expect(f.revoked, isEmpty);
    },
  );
  for (final mode in ['lock', 'unlock', 'delete']) {
    testWidgets(
      '$mode confirmation is independent, cancel does not write, success refreshes correct state',
      (t) async {
        final f = PersonnelFixture();
        await mountPersonnel(t, f);
        await openPersonnelMode(t, mode);
        expect(find.byType(PersonnelForm), findsNothing);
        expect(find.byType(PersonnelConfirmation), findsOneWidget);
        expect(f.writes, isEmpty);
        if (mode == 'delete') {
          expect(find.textContaining('xóa hẳn'), findsOneWidget);
          expect(find.textContaining('xóa mềm'), findsOneWidget);
        }
        await tapPersonnel(t, inConfirmation(find.text('Hủy')));
        expect(f.writes, isEmpty);
        await openPersonnelMode(t, mode);
        await tapPersonnel(t, confirmPersonnel(mode));
        expect(f.writes.length, 1);
        expect(find.byType(PersonnelConfirmation), findsNothing);
        if (mode == 'delete') {
          expect(f.writes.single.method, 'DELETE');
          expect(f.writes.single.body, isEmpty);
          expect(personnelRow('staff'), findsNothing);
          expect(f.history['staff'], isNotNull);
          expect(
            f.users.firstWhere((u) => u['id'] == 'staff')['deletedAt'],
            isNotNull,
          );
        } else {
          expect(f.bodies.single, {'active': mode == 'unlock'});
          expect(
            personnelAction(
              mode == 'unlock' ? 'accountant' : 'staff',
              mode == 'unlock' ? 'Đang hoạt động' : 'Đã khóa',
            ),
            findsOneWidget,
          );
        }
        expect(f.revoked, mode == 'unlock' ? isEmpty : ['staff']);
      },
    );
  }
  testWidgets(
    'delete an unlinked account removes it physically in fixture without changing another history',
    (t) async {
      final f = PersonnelFixture();
      await mountPersonnel(t, f);
      await personnelMenuAction(t, 'vet', 'Xóa');
      await tapPersonnel(t, confirmPersonnel('delete'));
      expect(f.users.any((u) => u['id'] == 'vet'), isFalse);
      expect(f.history['staff'], isNotNull);
    },
  );
  for (final mode in ['create', 'edit', 'lock', 'unlock', 'delete']) {
    testWidgets(
      '$mode blocks double-submit and Back until response; retry keeps modal draft',
      (t) async {
        final f = PersonnelFixture()
          ..writeError = 'Máy chủ từ chối thay đổi. Kiểm tra lại rồi thử.';
        final pending = Completer<void>();
        f.pending = pending.future;
        await mountPersonnel(t, f);
        if (mode == 'create') {
          await createPersonnelDraft(t);
        } else {
          await openPersonnelMode(t, mode);
        }
        final save = ['create', 'edit'].contains(mode)
            ? savePersonnel(mode == 'create')
            : confirmPersonnel(mode);
        final callback = t.widget<FilledButton>(save).onPressed!;
        callback();
        callback();
        await t.pump();
        expect(f.writes.length, 1);
        await t.binding.handlePopRoute();
        await t.pump();
        expect(
          find.byType(
            ['create', 'edit'].contains(mode)
                ? PersonnelForm
                : PersonnelConfirmation,
          ),
          findsOneWidget,
        );
        final cancel = ['create', 'edit'].contains(mode)
            ? inPersonnel(find.widgetWithText(TextButton, 'Hủy'))
            : inConfirmation(find.widgetWithText(TextButton, 'Hủy'));
        expect(t.widget<TextButton>(cancel).onPressed, isNull);
        pending.complete();
        await t.pumpAndSettle();
        expect(find.text(f.writeError!).hitTestable(), findsOneWidget);
        f.pending = null;
        f.writeError = null;
        await tapPersonnel(t, save);
        expect(f.writes.length, 2);
        expect(f.bodies.last, f.bodies.first);
      },
    );
  }
  testWidgets(
    'successful write with failed reload closes form, shows stale warning and cannot create twice',
    (t) async {
      final f = PersonnelFixture()..failListAfterWrite = true;
      await mountPersonnel(t, f);
      await createPersonnelDraft(t);
      await tapPersonnel(t, savePersonnel(true));
      expect(f.writes.length, 1);
      expect(find.byType(PersonnelForm), findsNothing);
      expect(
        find.textContaining('Đang hiển thị danh sách từ lần tải trước.'),
        findsOneWidget,
      );
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Thêm nhân sự'),
            )
            .onPressed,
        isNull,
      );
      f.failList = false;
      await tapPersonnel(t, find.widgetWithText(FilledButton, 'Thử lại'));
      expect(find.text('Nhân sự mới'), findsOneWidget);
      expect(f.writes.length, 1);
    },
  );
  testWidgets(
    'list failure retries without false empty, pagination has no invented filters and delete returns from last page',
    (t) async {
      final f = PersonnelFixture()..failList = true;
      await mountPersonnel(t, f);
      expect(find.text('Chưa có tài khoản nào.'), findsNothing);
      f.failList = false;
      for (var i = 0; i < 17; i++) {
        f.users.add({
          'id': 'extra-$i',
          'code': 'NV-X$i',
          'name': 'Nhân sự $i',
          'email': 'staff$i@example.test',
          'role': 'STAFF',
          'active': true,
        });
      }
      await tapPersonnel(t, find.widgetWithText(FilledButton, 'Thử lại'));
      await tapPersonnel(t, find.byTooltip('Trang sau'));
      expect(f.lists.last.url.queryParameters, {'page': '2', 'pageSize': '20'});
      await personnelMenuAction(t, 'extra-16', 'Xóa');
      await tapPersonnel(t, confirmPersonnel('delete'));
      expect(f.lists.last.url.queryParameters['page'], '1');
      expect(find.text('20 tài khoản'), findsOneWidget);
    },
  );
  testWidgets(
    'empty list and stale failed page retain honest count and disable changes until reload',
    (t) async {
      final f = PersonnelFixture();
      await mountPersonnel(t, f);
      f.failList = true;
      await tapPersonnel(t, find.text('Làm mới'));
      expect(personnelRow('staff'), findsOneWidget);
      expect(
        t
            .widget<PopupMenuButton<String>>(
              find.byKey(const ValueKey('personnel-menu-staff')),
            )
            .enabled,
        isFalse,
      );
      f.failList = false;
      f.users.clear();
      await tapPersonnel(t, find.widgetWithText(FilledButton, 'Thử lại'));
      expect(find.text('Chưa có tài khoản nào.'), findsOneWidget);
      expect(find.text('0 tài khoản'), findsOneWidget);
    },
  );
  for (final width in [360.0, 412.0, 1200.0]) {
    testWidgets(
      'personnel $width fits long names and true avatar at scale 1.3',
      (t) async {
        final f = PersonnelFixture();
        final b = await mountPersonnel(t, f, width: width);
        await capturePersonnel(t, b, 'list-${width.toInt()}-top');
        await t.ensureVisible(personnelRow('accountant'));
        await capturePersonnel(t, b, 'list-${width.toInt()}-bottom');
      },
    );
    for (final mode in ['create', 'edit']) {
      testWidgets(
        '$mode $width keeps CTA above keyboard, error visible and all drafts through resize',
        (t) async {
          final f = PersonnelFixture()
            ..writeError =
                'Không lưu được nhân sự. Thông tin đã nhập được giữ để kiểm tra và thử lại.';
          final b = await mountPersonnel(t, f, width: width);
          await openPersonnelMode(t, mode);
          await capturePersonnel(t, b, '$mode-${width.toInt()}-top');
          await fillPersonnel(
            t,
            'Họ và tên',
            'Tên dài được giữ qua đổi kích thước',
          );
          await fillPersonnel(t, 'Email', 'draft.personnel@example.test');
          if (mode == 'create') {
            await fillPersonnel(t, 'Mật khẩu ban đầu', 'fixture-only-password');
          }
          await t.ensureVisible(
            personnelField(mode == 'create' ? 'Mật khẩu ban đầu' : 'Email'),
          );
          await capturePersonnel(t, b, '$mode-${width.toInt()}-bottom');
          t.view.viewInsets = const FakeViewPadding(bottom: 300);
          await t.pumpAndSettle();
          await t.ensureVisible(
            personnelField(mode == 'create' ? 'Mật khẩu ban đầu' : 'Email'),
          );
          await t.pumpAndSettle();
          expect(savePersonnel(mode == 'create').hitTestable(), findsOneWidget);
          expect(
            t.getBottomRight(savePersonnel(mode == 'create')).dy,
            lessThanOrEqualTo(800),
          );
          await capturePersonnel(t, b, '$mode-${width.toInt()}-keyboard');
          await tapPersonnel(t, savePersonnel(mode == 'create'));
          expect(find.text(f.writeError!).hitTestable(), findsOneWidget);
          await capturePersonnel(t, b, '$mode-${width.toInt()}-error');
          t.view.viewInsets = const FakeViewPadding();
          t.view.physicalSize = Size(width < 600 ? 1200 : 360, 1100);
          await t.pumpAndSettle();
          expect(
            t
                .widget<TextFormField>(personnelField('Họ và tên'))
                .controller!
                .text,
            'Tên dài được giữ qua đổi kích thước',
          );
          expect(
            t.widget<TextFormField>(personnelField('Email')).controller!.text,
            'draft.personnel@example.test',
          );
          if (mode == 'create') expect(passwordHidden(t), isTrue);
          await tapPersonnel(t, inPersonnel(find.text('Hủy')));
          expect(f.writes.length, 1);
        },
      );
    }
    for (final mode in ['lock', 'unlock', 'delete']) {
      testWidgets(
        '$mode $width keeps one dialog, long account details and retry error readable',
        (t) async {
          final f = PersonnelFixture()
            ..writeError =
                'Không thể thay đổi tài khoản này. Dữ liệu hiện tại được giữ, hãy kiểm tra và thử lại.';
          final b = await mountPersonnel(t, f, width: width);
          await openPersonnelMode(t, mode);
          await capturePersonnel(t, b, '$mode-${width.toInt()}-top');
          await tapPersonnel(t, confirmPersonnel(mode));
          expect(find.text(f.writeError!).hitTestable(), findsOneWidget);
          await capturePersonnel(t, b, '$mode-${width.toInt()}-error');
          await tapPersonnel(t, inConfirmation(find.text('Hủy')));
          expect(f.writes.length, 1);
        },
      );
    }
  }
}
