// Isolated interactive event preview; all writes stay in MockClient memory.
import 'package:flutter/material.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/animal_detail_page.dart';

import '../support/animal_events_fixture.dart';

void main() => runApp(const AnimalEventsPreview());

class AnimalEventsPreview extends StatefulWidget {
  const AnimalEventsPreview({super.key});
  @override
  State<AnimalEventsPreview> createState() => _AnimalEventsPreviewState();
}

class _AnimalEventsPreviewState extends State<AnimalEventsPreview> {
  final fixture = AnimalEventsFixture();
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
    ),
  );
}
