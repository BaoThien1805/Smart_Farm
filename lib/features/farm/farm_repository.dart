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
  Future<Map<String, List<String>>?>? _penSpeciesLoading;
  FarmRepository(this.api);
  Future<Map<String, dynamic>> get(
    String path, {
    bool withPenSpecies = false,
  }) async {
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
    final result = await api.request('GET', path);
    if (withPenSpecies &&
        (uri.path == '/farm/catalogs' || uri.path == '/farm/dashboard')) {
      return _withPenSpecies(result);
    }
    return result;
  }

  // Older online APIs omit speciesNames. Resolve it from actual residents,
  // never pen names/codes, and keep the catalog usable if this optional read fails.
  Future<Map<String, dynamic>> _withPenSpecies(
    Map<String, dynamic> data,
  ) async {
    const keys = ['pens', 'fullPens'];
    final needsResidents = keys.any((key) {
      final pens = data[key];
      return pens is List &&
          pens.whereType<Map>().any(
            (pen) =>
                pen['speciesNames'] is! List &&
                pen['id'] is String &&
                pen['occupied'] is num &&
                (pen['occupied'] as num) > 0,
          );
    });
    if (!needsResidents) return data;
    final residents = await (_penSpeciesLoading ??= _loadPenSpecies());
    if (residents == null) return data;
    return {
      ...data,
      for (final key in keys)
        if (data[key] is List)
          key: [
            for (final pen in data[key] as List)
              if (pen is Map && pen['speciesNames'] is! List)
                {...pen, 'speciesNames': residents[pen['id']] ?? <String>[]}
              else
                pen,
          ],
    };
  }

  Future<Map<String, List<String>>?> _loadPenSpecies() async {
    final names = <String, Set<String>>{};
    final seen = <String>{};
    var received = 0;
    try {
      for (var page = 1; ; page++) {
        // Pen art describes all residents, independently of the current species filter.
        final response = await api.request(
          'GET',
          '/animals?status=ACTIVE&pageSize=100&page=$page',
        );
        final animals = response['animals'];
        final total = response['total'];
        if (animals is! List || total is! num || total < 0) return null;
        final before = seen.length;
        for (final animal in animals.whereType<Map>()) {
          final id = animal['id'];
          if (id is! String || !seen.add(id)) continue;
          final penId = animal['penId'];
          final name = animal['speciesName'];
          if (animal['status'] == 'ACTIVE' &&
              penId is String &&
              name is String &&
              name.trim().isNotEmpty) {
            names.putIfAbsent(penId, () => <String>{}).add(name.trim());
          }
        }
        received += animals.length;
        if (seen.length >= total) {
          return {
            for (final entry in names.entries) entry.key: entry.value.toList(),
          };
        }
        if (seen.length == before || received >= total) return null;
      }
    } on ApiException {
      return null;
    } finally {
      _penSpeciesLoading = null;
    }
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
  Future<void> load(
    String path, {
    bool withCatalogs = false,
    bool withPenSpecies = false,
  }) async {
    final generation = ++_generation;
    loading = true;
    error = null;
    _notify();
    try {
      final result = await repository.get(path, withPenSpecies: withPenSpecies);
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

/// Calendar dates have no timezone. ISO stays at the API boundary.
DateTime? farmParseDate(String raw) {
  final value = raw.trim();
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  final local = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value);
  if (iso == null && local == null) return null;
  final year = int.parse(iso?[1] ?? local![3]!);
  final month = int.parse(iso?[2] ?? local![2]!);
  final day = int.parse(iso?[3] ?? local![1]!);
  final date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day
      ? date
      : null;
}

String farmIsoDate(String raw) =>
    farmParseDate(raw)?.toIso8601String().substring(0, 10) ?? raw.trim();

String farmDate(String raw) {
  final date = farmParseDate(raw);
  if (date == null) return raw;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year.toString().padLeft(4, '0')}';
}
