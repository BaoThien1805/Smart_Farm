// Fixture-only preview: requests are handled by MockClient.
import 'package:flutter/material.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/animal_detail_page.dart';

import '../support/animal_profile_fixture.dart';

void main() => runApp(const AnimalProfilePreview());

class AnimalProfilePreview extends StatefulWidget {
  const AnimalProfilePreview({super.key});
  @override
  State<AnimalProfilePreview> createState() => _AnimalProfilePreviewState();
}

class _AnimalProfilePreviewState extends State<AnimalProfilePreview> {
  final fixture = AnimalProfileFixture();
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
    home: AnimalDetailPage(
      repository: fixture.repository,
      id: 'profile',
      admin: true,
      canExamine: true,
      canFinance: true,
    ),
  );
}
