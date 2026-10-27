import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api_client.dart';
import '../../core/device_location.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import 'farm_repository.dart';

class WeatherCard extends StatefulWidget {
  final FarmRepository repository;
  final bool admin;
  final bool compact;
  final VoidCallback? onLocationChanged;
  const WeatherCard({
    super.key,
    required this.repository,
    required this.admin,
    this.compact = false,
    this.onLocationChanged,
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
        barrierDismissible: false,
        builder: (_) => FarmLocationDialog(
          repository: widget.repository,
          location: location,
        ),
      );
      if (changed == true && mounted) {
        widget.onLocationChanged?.call();
        await load();
      }
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
              onLocationChanged: widget.onLocationChanged,
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

  Widget compactLocationLabel(String label) => LayoutBuilder(
    builder: (context, constraints) {
      const style = TextStyle(fontSize: 12, color: muted);
      final cityPrefix = RegExp(r'^Thành phố\s+', caseSensitive: false);
      var display = label;
      if (cityPrefix.hasMatch(label)) {
        final city = label.replaceFirst(cityPrefix, '').trim();
        final shortLabel = 'TP $city';
        final painter = TextPainter(
          text: TextSpan(
            text: shortLabel,
            style: DefaultTextStyle.of(context).style.merge(style),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        display = painter.width <= constraints.maxWidth
            ? shortLabel
            : 'Thành phố\n$city';
        painter.dispose();
      }
      return Text(
        display,
        maxLines: 2,
        softWrap: !cityPrefix.hasMatch(label),
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: style,
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final temperature = data?['temperature'];
    final hasWeather = temperature is num && temperature.isFinite;
    final region = data?['region']?.toString().trim();
    final locationLabel = region?.isNotEmpty == true
        ? region!
        : errorCode == 'FARM_LOCATION_REQUIRED'
        ? 'Chưa đặt vị trí'
        : loading
        ? 'Đang xác định'
        : 'Chưa rõ vị trí';
    final status = errorCode == 'WEATHER_NOT_CONFIGURED'
        ? 'Chưa bật'
        : errorCode == 'FARM_LOCATION_REQUIRED'
        ? 'Chưa đặt vị trí'
        : 'Chưa có dữ liệu';
    if (widget.compact) {
      return Tooltip(
        message: error ?? 'Xem thời tiết · $locationLabel',
        child: Material(
          color: FarmColors.sky,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FarmRadii.field),
            side: const BorderSide(color: line),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: showDetails,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      error != null
                          ? Icons.cloud_off_outlined
                          : hasWeather
                          ? conditionIcon
                          : Icons.cloud_outlined,
                      size: 24,
                      color: hasWeather && error == null
                          ? (conditionIcon == Icons.wb_sunny_outlined
                                ? FarmColors.gold
                                : FarmColors.blue)
                          : forest,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    loading
                        ? 'Đang tải'
                        : error != null
                        ? status
                        : hasWeather
                        ? '${temperature.round()}°C'
                        : 'Chưa có dữ liệu',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: hasWeather && error == null && !loading
                          ? 20
                          : 12,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  compactLocationLabel(locationLabel),
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
    return FarmInfoCard(
      color: FarmColors.sky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Thời tiết trang trại',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Cập nhật thời tiết',
                onPressed: loading ? null : load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: LinearProgressIndicator(),
            )
          else if (error != null) ...[
            Icon(
              errorCode == 'FARM_LOCATION_REQUIRED'
                  ? Icons.location_off_outlined
                  : Icons.cloud_off_outlined,
              size: 40,
              color: FarmColors.info,
            ),
            const SizedBox(height: 12),
            FeedbackBox(
              errorCode == 'WEATHER_NOT_CONFIGURED'
                  ? 'Dịch vụ thời tiết chưa được bật trên máy chủ. Chủ trang trại cần cấu hình dịch vụ để xem thời tiết.'
                  : error!,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: load,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại thời tiết'),
            ),
          ] else if (hasWeather) ...[
            if (region?.isNotEmpty == true) ...[
              Text(
                region!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              data?['location']?.toString() ?? '',
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(conditionIcon, size: 48, color: FarmColors.warning),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '${temperature.round()}°C',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
              ],
            ),
            Text(data?['description']?.toString() ?? ''),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text('Độ ẩm ${data?['humidity'] ?? '—'}%'),
                Text('Gió ${data?['windSpeed'] ?? '—'} m/s'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${data?["provider"] ?? "Thời tiết"} · ${observed == null ? 'Chưa có giờ cập nhật' : '${observed.hour.toString().padLeft(2, '0')}:${observed.minute.toString().padLeft(2, '0')}'} · Giờ Việt Nam',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (data?['provider'] == 'Open-Meteo') ...[
              const SizedBox(height: 4),
              SelectableText(
                'https://open-meteo.com/ · CC BY 4.0',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (region?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              SelectableText(
                'Địa danh: © OpenStreetMap contributors · Photon · ODbL',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ] else
            const Text('Chưa có dữ liệu thời tiết.'),
          if (widget.admin) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: loading ? null : editLocation,
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('Đặt vị trí trang trại'),
            ),
          ],
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
    if (busy) return;
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
    if (busy || !form.currentState!.validate()) return;
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
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: FarmFormLayout(
      title: 'Vị trí trang trại',
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
  );
}
