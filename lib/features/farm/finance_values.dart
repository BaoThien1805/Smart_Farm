import 'farm_repository.dart';

const financeCategories = {
  'FEED': 'Thức ăn',
  'MEDICINE': 'Thuốc / vaccine',
  'ANIMAL_PURCHASE': 'Mua vật nuôi',
  'OTHER': 'Khác',
};
String financeCategory(String key) =>
    key == 'ANIMAL_SALE' ? 'Bán vật nuôi' : financeCategories[key] ?? key;
bool isLinkedFinanceEntry(FarmRecord entry) =>
    entry.text('saleId').isNotEmpty ||
    entry.text('category') == 'ANIMAL_SALE' ||
    entry.text('stockEntryId').isNotEmpty;

String? validateVndAmount(String? text) {
  final value = (text ?? '').trim();
  final amount = int.tryParse(value);
  if (!RegExp(r'^\d+$').hasMatch(value) || amount == null || amount <= 0) {
    return 'Nhập số tiền nguyên VND lớn hơn 0.';
  }
  return amount > 1000000000000
      ? 'Số tiền tối đa 1.000.000.000.000 VND.'
      : null;
}

String vnd(Object? value) {
  final digits = (value ?? '0').toString();
  final negative = digits.startsWith('-');
  final raw = negative ? digits.substring(1) : digits;
  return '${negative ? '-' : ''}${raw.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')} ₫';
}
