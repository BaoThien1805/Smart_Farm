import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';

/// JSON is converted at the repository boundary; widgets use checked accessors.
class FarmRecord {
  final Map<String, dynamic> values;
  FarmRecord(Map<String, dynamic> values) : values = Map.unmodifiable(values);
  String text(String key) => values[key]?.toString() ?? '';
  int integer(String key) => (values[key] as num?)?.toInt() ?? 0;
  double number(String key) => (values[key] as num?)?.toDouble() ?? 0;
  bool flag(String key) => values[key] == true;
  String get id => text('id');
}

class FarmRepository {
  final ApiClient api;
  List<String> selectedSpeciesIds = [];
  FarmRepository(this.api);
  Future<Map<String, dynamic>> get(String path) {
    final uri = Uri.parse(path);
    if (selectedSpeciesIds.isNotEmpty &&
        !uri.queryParameters.containsKey('speciesId') &&
        ['/animals', '/care-tasks', '/farm/dashboard'].contains(uri.path)) {
      path = uri
          .replace(
            queryParameters: {
              ...uri.queryParameters,
              'speciesIds': selectedSpeciesIds.join(','),
            },
          )
          .toString();
    }
    return api.request('GET', path);
  }

  Future<void> save(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
    await api.request(method, path, body: body);
  }

  static List<FarmRecord> records(Map<String, dynamic> data, String key) =>
      ((data[key] as List?) ?? [])
          .map((v) => FarmRecord(Map<String, dynamic>.from(v as Map)))
          .toList();
  static String requestId() {
    final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}

class FarmController extends ChangeNotifier {
  final FarmRepository repository;
  FarmController(this.repository);
  Map<String, dynamic> data = {};
  Map<String, dynamic> catalogs = {};
  bool loading = false;
  String? error;
  bool _disposed = false;
  int _generation = 0;
  Future<void> load(String path, {bool withCatalogs = false}) async {
    final generation = ++_generation;
    loading = true;
    error = null;
    _notify();
    try {
      final result = await repository.get(path);
      final catalog = withCatalogs
          ? path == '/farm/catalogs'
                ? result
                : await repository.get('/farm/catalogs')
          : catalogs;
      if (!_disposed && generation == _generation) {
        data = result;
        catalogs = catalog;
      }
    } on ApiException catch (e) {
      if (generation == _generation) error = e.message;
    } finally {
      if (generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  List<FarmRecord> items(String key) => FarmRepository.records(data, key);
  List<FarmRecord> catalog(String key) => FarmRepository.records(catalogs, key);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

String label(String value) =>
    const {
      'ACTIVE': 'Đang nuôi',
      'DEAD': 'Đã chết',
      'SOLD': 'Đã bán',
      'NORMAL': 'Bình thường',
      'NEEDS_CARE': 'Cần chăm sóc',
      'MALE': 'Đực',
      'FEMALE': 'Cái',
      'UNKNOWN': 'Chưa xác định',
      'VACCINATION': 'Tiêm phòng',
      'CHECKUP': 'Kiểm tra',
      'PENDING': 'Chờ thực hiện',
      'DONE': 'Đã hoàn thành',
      'CANCELLED': 'Đã hủy',
    }[value] ??
    value;
String farmToday() => DateTime.now()
    .toUtc()
    .add(const Duration(hours: 7))
    .toIso8601String()
    .substring(0, 10);
