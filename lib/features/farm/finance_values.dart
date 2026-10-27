const financeCategories = {
  'FEED': 'Thức ăn',
  'MEDICINE': 'Thuốc / vaccine',
  'ANIMAL_PURCHASE': 'Mua vật nuôi',
  'OTHER': 'Khác',
};
String financeCategory(String key) =>
    key == 'ANIMAL_SALE' ? 'Bán vật nuôi' : financeCategories[key] ?? key;
String vnd(Object? value) {
  final digits = (value ?? '0').toString();
  final negative = digits.startsWith('-');
  final raw = negative ? digits.substring(1) : digits;
  return '${negative ? '-' : ''}${raw.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')} ₫';
}
