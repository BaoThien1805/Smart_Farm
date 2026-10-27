// Flutter UI preview backed entirely by MockClient.
import 'package:flutter/material.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/farm_pages.dart';

import '../support/catalog_fixture.dart';

void main() => runApp(const CatalogPreview());
const previewKind = String.fromEnvironment(
  'CATALOG_KIND',
  defaultValue: 'pens',
);

class CatalogPreview extends StatefulWidget {
  const CatalogPreview({super.key});
  @override
  State<CatalogPreview> createState() => _CatalogPreviewState();
}

class _CatalogPreviewState extends State<CatalogPreview> {
  final fixture = CatalogFixture();
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
      body: CatalogPage(
        repository: fixture.repository,
        admin: true,
        initialKind: previewKind,
        availableKinds: previewKind == 'pens'
            ? const ['pens']
            : const ['species', 'breeds', 'areas'],
      ),
    ),
  );
}
