import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api_client.dart';
import '../../core/device_location.dart';
import '../../core/theme.dart';
import 'farm_repository.dart';

class WeatherCard extends StatefulWidget {
  final FarmRepository repository;
  final bool admin;
  final bool compact;
  const WeatherCard({
    super.key,
    required this.repository,
    required this.admin,
    this.compact = false,
  });
  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  Map<String, dynamic>? data;
  String? error;
  String? errorCode;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
      errorCode = null;
    });
    try {
      final value = await widget.repository.get('/weather');
      if (mounted) setState(() => data = value);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          errorCode = e.code;
          data = null;
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> editLocation() async {
    try {
      final response = await widget.repository.get('/farm/location');
      if (!mounted) return;
      final location = response['location'] as Map<String, dynamic>? ?? {};
      final changed = await showDialog<bool>(
        context: context,
        builder: (_) => FarmLocationDialog(
          repository: widget.repository,
          location: location,
        ),
      );
      if (changed == true && mounted) await load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  IconData get conditionIcon {
    final code = (data?['condition'] as num?)?.toInt() ?? 800;
    if (code < 300) return Icons.thunderstorm_outlined;
    if (code < 600) return Icons.grain;
    if (code < 700) return Icons.ac_unit;
    if (code < 800) return Icons.blur_on;
    return code == 800 ? Icons.wb_sunny_outlined : Icons.cloud_outlined;
  }

  Future<void> showDetails() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.all(12),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: WeatherCard(
              repository: widget.repository,
              admin: widget.admin,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      final temperature = data?['temperature'];
      final text = loading
          ? 'Đang tải'
          : error != null
          ? (errorCode == 'WEATHER_NOT_CONFIGURED'
                ? 'Chưa bật'
                : 'Chưa có dữ liệu')
          : temperature is num
          ? '${temperature.round()}°C'
          : 'Thời tiết';
      return Tooltip(
        message: error ?? 'Xem thời tiết và vị trí trang trại',
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: line),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: showDetails,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (loading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          error != null
                              ? Icons.cloud_off_outlined
                              : conditionIcon,
                          size: 22,
                          color: forest,
                        ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: temperature is num && error == null
                                ? 22
                                : 12,
                            fontWeight: FontWeight.w700,
                            color: forest,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Thời tiết',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final observed = DateTime.tryParse(data?['observedAt']?.toString() ?? '')
        ?.toUtc()
        .add(const Duration(hours: 7));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6EE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD6E5D3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_cloudy_outlined, color: forest, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Thời tiết trang trại',
                  style: TextStyle(color: forest, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Cập nhật thời tiết',
                onPressed: loading ? null : load,
                icon: const Icon(Icons.refresh, size: 20),
              ),
            ],
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: LinearProgressIndicator(),
            )
          else if (error != null)
            Text(
              errorCode == 'WEATHER_NOT_CONFIGURED'
                  ? 'Dịch vụ thời tiết chưa được bật trên máy chủ. Chủ trang trại cần cấu hình dịch vụ để xem thời tiết.'
                  : error!,
              style: const TextStyle(color: forest),
            )
          else if (data?['temperature'] is num) ...[
            Text(
              data?['location']?.toString() ?? '',
              style: const TextStyle(color: forest),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(conditionIcon, color: const Color(0xFFB87B20), size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${(data!['temperature'] as num).round()}°C',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: forest,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              data?['description']?.toString() ?? '',
              style: const TextStyle(color: forest),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text('Độ ẩm ${data?['humidity']}%'),
                Text('Gió ${data?['windSpeed']} m/s'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'OpenWeather · ${observed == null ? "" : "${observed.hour.toString().padLeft(2, '0')}:${observed.minute.toString().padLeft(2, '0')} · Giờ Việt Nam"}',
              style: const TextStyle(fontSize: 12, color: forest),
            ),
          ],
          if (widget.admin)
            TextButton.icon(
              onPressed: loading ? null : editLocation,
              icon: const Icon(Icons.location_on_outlined, size: 18),
              label: const Text('Đặt vị trí trang trại'),
            ),
          if (!widget.admin && errorCode == 'FARM_LOCATION_REQUIRED')
            const Text('Chủ trang trại có thể đặt vị trí tại đây.'),
        ],
      ),
    );
  }
}

class FarmLocationDialog extends StatefulWidget {
  final FarmRepository repository;
  final Map<String, dynamic> location;
  const FarmLocationDialog({
    super.key,
    required this.repository,
    required this.location,
  });
  @override
  State<FarmLocationDialog> createState() => _FarmLocationDialogState();
}

class _FarmLocationDialogState extends State<FarmLocationDialog> {
  final form = GlobalKey<FormState>();
  late final latitude = TextEditingController(
    text: widget.location['latitude']?.toString() ?? '',
  );
  late final longitude = TextEditingController(
    text: widget.location['longitude']?.toString() ?? '',
  );
  String? error;
  bool busy = false;
  bool locationFailed = false;
  String? locationInfo;
  @override
  void dispose() {
    latitude.dispose();
    longitude.dispose();
    super.dispose();
  }

  Future<void> openSettings(bool application) async {
    try {
      final opened = application
          ? await Geolocator.openAppSettings()
          : await Geolocator.openLocationSettings();
      if (!opened && mounted) {
        setState(
          () => error =
              'Không mở được cài đặt. Hãy mở Cài đặt thiết bị để bật vị trí.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Không mở được cài đặt vị trí trên thiết bị này.',
        );
      }
    }
  }

  Future<void> locate() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final position = await currentDeviceLocation();
      locationFailed = false;
      if (mounted) {
        locationInfo =
            '${position.isMocked ? 'Vị trí mô phỏng' : 'Vị trí thiết bị'} · sai số khoảng ${position.accuracy.round()} m. Kiểm tra tọa độ rồi bấm Lưu.';
        latitude.text = position.latitude.toStringAsFixed(6);
        longitude.text = position.longitude.toStringAsFixed(6);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          locationFailed = true;
          error = e.message;
        });
      }
    } on TimeoutException {
      locationFailed = true;
      if (mounted) {
        setState(
          () => error = 'Chưa nhận được GPS. Kiểm tra quyền Vị trí chính xác. Trên máy ảo, chọn … → Location → Set location rồi thử lại; hoặc nhập tọa độ.',
        );
      }
    } on LocationServiceDisabledException {
      locationFailed = true;
      if (mounted) {
        setState(
          () => error = 'Dịch vụ vị trí đã tắt. Hãy bật Vị trí và thử lại.',
        );
      }
    } on PermissionDeniedException {
      locationFailed = true;
      if (mounted) {
        setState(
          () => error =
              'Hãy cho phép Smart Farm truy cập vị trí trong cài đặt ứng dụng.',
        );
      }
    } catch (e) {
      locationFailed = true;
      if (mounted) {
        setState(
          () => error =
              'Không lấy được vị trí thiết bị. Hãy nhập tọa độ thủ công.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.save('PATCH', '/farm/location', {
        'latitude': double.parse(latitude.text.trim().replaceAll(',', '.')),
        'longitude': double.parse(longitude.text.trim().replaceAll(',', '.')),
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Vị trí trang trại'),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nếu bạn đang ở trang trại, dùng vị trí thiết bị. Nếu ở nơi khác, nhập tọa độ của trang trại từ bản đồ.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy ? null : locate,
                icon: const Icon(Icons.my_location),
                label: const Text('Lấy vị trí thiết bị'),
              ),
              const SizedBox(height: 12),
              for (final entry in [
                (latitude, 'Vĩ độ', 90.0),
                (longitude, 'Kinh độ', 180.0),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: entry.$1,
                    enabled: !busy,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: InputDecoration(labelText: entry.$2),
                    validator: (text) {
                      final value = double.tryParse(
                        (text?.trim() ?? '').replaceAll(',', '.'),
                      );
                      return value == null ||
                              !value.isFinite ||
                              value.abs() > entry.$3
                          ? '${entry.$2} phải trong khoảng -${entry.$3.toInt()} đến ${entry.$3.toInt()}.'
                          : null;
                    },
                  ),
                ),
              if (locationInfo != null && error == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(locationInfo!),
                ),
              if (locationFailed && !kIsWeb)
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: busy ? null : () => openSettings(false),
                      child: const Text('Bật vị trí'),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => openSettings(true),
                      child: const Text('Quyền ứng dụng'),
                    ),
                  ],
                ),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: const Text('Lưu vị trí'),
      ),
    ],
  );
}
