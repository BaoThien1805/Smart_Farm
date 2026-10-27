// Fixture-only care preview; all HTTP stays in memory.
import 'package:flutter/material.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/care_page.dart';

import '../support/care_fixture.dart';

void main() => runApp(const CarePreview());

class CarePreview extends StatefulWidget {
  const CarePreview({super.key});
  @override
  State<CarePreview> createState() => _CarePreviewState();
}

class _CarePreviewState extends State<CarePreview> {
  final fixture = CareFixture();
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
      body: CarePage(
        repository: fixture.repository,
        admin: true,
        canExamine: true,
      ),
    ),
  );
}
