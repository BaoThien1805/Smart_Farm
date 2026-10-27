import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';
import 'package:smart_farm/features/farm/farm_widgets.dart';

void main() {
  test('calendar presentation round trips without rolling invalid dates', () {
    expect(farmDate('2026-10-25'), '25/10/2026');
    expect(farmIsoDate('25/10/2026'), '2026-10-25');
    expect(farmIsoDate('2026-10-25'), '2026-10-25');
    expect(farmDate('2024-02-29'), '29/02/2024');
    expect(farmParseDate('29/02/2026'), isNull);
    expect(farmParseDate('2026-02-31'), isNull);
    expect(farmParseDate('31/13/2026'), isNull);
    expect(farmDate(''), '');
  });

  testWidgets('date field shows dd/MM/yyyy and saves ISO to API callback', (
    t,
  ) async {
    Map<String, dynamic>? saved;
    await t.pumpWidget(
      MaterialApp(
        theme: farmTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => farmForm(
                context,
                title: 'Chọn ngày',
                fields: const [
                  FarmField(
                    'date',
                    'Ngày ghi nhận',
                    initial: '2026-10-25',
                    date: true,
                  ),
                ],
                save: (body) async {
                  saved = body;
                },
              ),
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Mở'));
    await t.pumpAndSettle();
    expect(
      t.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      '25/10/2026',
    );
    await t.tap(find.text('Lưu'));
    await t.pumpAndSettle();
    expect(saved, {'date': '2026-10-25'});
  });
}
