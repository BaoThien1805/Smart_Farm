// Fixture-only preview. All requests use MockClient.
import 'package:flutter/material.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/animals_page.dart';

import '../support/animals_fixture.dart';

void main() => runApp(const AnimalsPreview());

class AnimalsPreview extends StatefulWidget {
  const AnimalsPreview({super.key});
  @override
  State<AnimalsPreview> createState() => _AnimalsPreviewState();
}

class _AnimalsPreviewState extends State<AnimalsPreview> {
  final fixture = AnimalsFixture();
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
      body: AnimalsPage(
        repository: fixture.repository,
        admin: true,
        canExamine: true,
        canFinance: true,
      ),
    ),
  );
}
