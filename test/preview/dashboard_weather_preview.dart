// Fixture-only preview. No online data, saved account or production writes.
import 'package:flutter/material.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/dashboard_page.dart';
import 'package:smart_farm/features/farm/farm_location_page.dart';

import '../support/dashboard_weather_fixture.dart';

void main() => runApp(const DashboardWeatherPreview());

class DashboardWeatherPreview extends StatefulWidget {
  const DashboardWeatherPreview({super.key});
  @override
  State<DashboardWeatherPreview> createState() =>
      _DashboardWeatherPreviewState();
}

class _DashboardWeatherPreviewState extends State<DashboardWeatherPreview> {
  final fixture = DashboardWeatherFixture(
    weatherState: const String.fromEnvironment(
      'WEATHER_STATE',
      defaultValue: 'ready',
    ),
  );
  @override
  void dispose() {
    fixture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: farmTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(1.3)),
      child: child!,
    ),
    home: Scaffold(
      appBar: AppBar(title: const Text('Preview · dữ liệu minh họa')),
      body: const String.fromEnvironment('PREVIEW_SCREEN') == 'location'
          ? FarmLocationPage(repository: fixture.repository, admin: true)
          : FarmDashboard(
              repository: fixture.repository,
              userName: 'Chủ trang trại mẫu',
              admin: true,
              onAnimals: () {},
              onCare: () {},
              onStock: () {},
              onPens: () {},
              onFinance: () {},
            ),
    ),
  );
}
