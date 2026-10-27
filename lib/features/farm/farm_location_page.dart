import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import 'farm_repository.dart';
import 'weather_card.dart';

/// Read access is available to every signed-in role. Editing stays admin-only.
class FarmLocationPage extends StatefulWidget {
  const FarmLocationPage({
    super.key,
    required this.repository,
    required this.admin,
    this.onLocationChanged,
  });
  final FarmRepository repository;
  final bool admin;
  final VoidCallback? onLocationChanged;
  @override
  State<FarmLocationPage> createState() => _FarmLocationPageState();
}

class _FarmLocationPageState extends State<FarmLocationPage> {
  Map<String, dynamic>? location;
  bool loading = true, editing = false;
  String? error;
  int generation = 0, weatherRevision = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final request = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await widget.repository.get('/farm/location');
      if (mounted && request == generation) {
        setState(
          () => location = Map<String, dynamic>.from(
            data['location'] as Map? ?? {},
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted && request == generation) setState(() => error = e.message);
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  Future<void> edit() async {
    if (!widget.admin || loading || editing || error != null) return;
    setState(() => editing = true);
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FarmLocationDialog(
        repository: widget.repository,
        location: location ?? {},
      ),
    );
    if (!mounted) return;
    setState(() {
      editing = false;
      if (saved == true) weatherRevision++;
    });
    if (saved == true) {
      widget.onLocationChanged?.call();
      await load();
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FarmInfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: FarmSectionHeader(
                          title: 'Vị trí trang trại',
                          pageTitle: true,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tải lại vị trí',
                        onPressed: loading || editing ? null : load,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (loading)
                    const LinearProgressIndicator()
                  else if (error != null)
                    FeedbackBox(error!)
                  else ...[
                    if (location?['name']?.toString().isNotEmpty == true)
                      Text(
                        location!['name'].toString(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    const SizedBox(height: 12),
                    if (location?['latitude'] == null ||
                        location?['longitude'] == null)
                      const Text('Trang trại chưa có tọa độ.')
                    else ...[
                      Text('Vĩ độ: ${location!['latitude']}'),
                      Text('Kinh độ: ${location!['longitude']}'),
                    ],
                    const SizedBox(height: 16),
                    if (widget.admin)
                      FilledButton.icon(
                        onPressed: editing ? null : edit,
                        icon: const Icon(Icons.edit_location_alt_outlined),
                        label: const Text('Đặt vị trí trang trại'),
                      )
                    else
                      const Text('Chủ trang trại có thể cập nhật tọa độ.'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            WeatherCard(
              key: ValueKey(weatherRevision),
              repository: widget.repository,
              admin: false,
            ),
          ],
        ),
      ),
    ),
  );
}
