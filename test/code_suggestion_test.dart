import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/core/suggested_code_field.dart';
import 'package:smart_farm/features/auth/auth_repository.dart';
import 'package:smart_farm/features/users/users_controller.dart';

import 'farm_test.dart' as fixture;

void main() {
  testWidgets(
    'old server explains missing suggestion route and preserves employee code',
    (t) async {
      final code = TextEditingController(text: 'NV-01');
      addTearDown(code.dispose);
      final api = ApiClient(
        client: MockClient(
          (_) async => fixture.response({
            'error': {
              'code': 'NOT_FOUND',
              'message': 'Không tìm thấy đường dẫn.',
            },
          }, 404),
        ),
      );
      addTearDown(api.dispose);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SuggestedCodeField(
              api: api,
              controller: code,
              kind: 'users',
              name: '',
              label: 'Mã nhân sự',
              suggestInitially: false,
            ),
          ),
        ),
      );
      await t.tap(find.byTooltip('Đề xuất mã'));
      await t.pumpAndSettle();
      expect(find.textContaining('backend v10 trên Render'), findsOneWidget);
      expect(code.text, 'NV-01');
      expect(t.takeException(), isNull);
    },
  );

  test('missing edit route gets an upgrade message; missing user keeps the server error', () async {
    var errorCode = 'NOT_FOUND';
    final api = ApiClient(
      client: MockClient(
        (r) async => fixture.response({
          'error': {'code': errorCode, 'message': 'Không tìm thấy tài khoản.'},
        }, 404),
      ),
    );
    addTearDown(api.dispose);
    final controller = UsersController(api);
    addTearDown(controller.dispose);
    const user = FarmUser(
      id: 'staff',
      email: 'staff@example.test',
      name: 'Nhân viên',
      role: 'STAFF',
      active: true,
    );
    expect(await controller.updateUser(user, {'name': 'Tên mới'}), isFalse);
    expect(controller.error, contains('backend v10'));
    expect(controller.saving, isFalse);
    errorCode = 'USER_NOT_FOUND';
    expect(await controller.updateUser(user, {'name': 'Tên mới'}), isFalse);
    expect(controller.error, 'Không tìm thấy tài khoản.');
  });
  testWidgets(
    'suggested code follows breed name but never replaces a manual code',
    (t) async {
      final code = TextEditingController();
      final name = ValueNotifier('BBB');
      addTearDown(code.dispose);
      addTearDown(name.dispose);
      final api = ApiClient(
        client: MockClient(
          (r) async =>
              fixture.response({'code': '${r.url.queryParameters['name']}_01'}),
        ),
      );
      addTearDown(api.dispose);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: name,
              builder: (_, value, _) => SuggestedCodeField(
                api: api,
                controller: code,
                kind: 'animals',
                name: value,
                label: 'Mã',
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(code.text, 'BBB_01');
      name.value = 'BOER';
      await t.pump();
      await t.pump(const Duration(milliseconds: 350));
      await t.pumpAndSettle();
      expect(code.text, 'BOER_01');
      await t.enterText(find.byType(TextFormField), 'MY-CODE');
      name.value = 'ABC';
      await t.pump();
      await t.pump(const Duration(milliseconds: 350));
      await t.pumpAndSettle();
      expect(code.text, 'MY-CODE');
      await t.tap(find.byTooltip('Đề xuất mã'));
      await t.pumpAndSettle();
      expect(code.text, 'ABC_01');
    },
  );

  testWidgets(
    'late suggestions cannot overwrite typed codes; editing keeps existing codes',
    (t) async {
      final response = Completer<void>();
      final code = TextEditingController();
      addTearDown(code.dispose);
      var requests = 0;
      final api = ApiClient(
        client: MockClient((r) async {
          requests++;
          await response.future;
          return fixture.response({'code': 'BBB_01'});
        }),
      );
      addTearDown(api.dispose);
      Widget field(bool create) => MaterialApp(
        home: Scaffold(
          body: SuggestedCodeField(
            key: ValueKey(create),
            api: api,
            controller: code,
            kind: 'animals',
            name: 'BBB',
            label: 'Mã',
            suggestInitially: create,
          ),
        ),
      );
      await t.pumpWidget(field(true));
      await t.enterText(find.byType(TextFormField), 'CUSTOM');
      response.complete();
      await t.pumpAndSettle();
      expect(code.text, 'CUSTOM');
      await t.pumpWidget(field(false));
      await t.pumpAndSettle();
      expect(requests, 1);
      expect(code.text, 'CUSTOM');
      expect(t.takeException(), isNull);
    },
  );
}
