// Fixture-only editor preview; HTTP is handled locally by MockClient.
import 'package:flutter/material.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/animal_editor.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';

import '../support/animal_editor_fixture.dart';

void main() => runApp(const AnimalEditorPreview());

class AnimalEditorPreview extends StatefulWidget {
  const AnimalEditorPreview({super.key});
  @override
  State<AnimalEditorPreview> createState() => _AnimalEditorPreviewState();
}

class _AnimalEditorPreviewState extends State<AnimalEditorPreview> {
  final fixture = AnimalEditorFixture();
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
      body: Builder(
        builder: (context) => Center(
          child: Wrap(
            spacing: 16,
            children: [
              FilledButton(
                onPressed: () =>
                    animalForm(context, fixture.repository, {}, null, true),
                child: const Text('Thêm vật nuôi'),
              ),
              OutlinedButton(
                onPressed: () => animalForm(
                  context,
                  fixture.repository,
                  {},
                  FarmRecord(fixture.animal),
                  true,
                ),
                child: const Text('Sửa hồ sơ'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
