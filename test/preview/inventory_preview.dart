// Fixture-only inventory preview: writes never leave MockClient memory.
import 'package:flutter/material.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/inventory_page.dart';

import '../support/inventory_fixture.dart';

void main() => runApp(const InventoryPreview());

class InventoryPreview extends StatefulWidget {
  const InventoryPreview({super.key});
  @override
  State<InventoryPreview> createState() => _InventoryPreviewState();
}

class _InventoryPreviewState extends State<InventoryPreview> {
  final fixture = InventoryFixture();
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
      body: InventoryPage(repository: fixture.repository, admin: true),
    ),
  );
}
