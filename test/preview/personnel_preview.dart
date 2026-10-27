// Fixture-only preview: never contacts a backend.
import 'package:flutter/material.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/users/users_page.dart';

import '../support/personnel_fixture.dart';

void main() => runApp(const PersonnelPreview());

class PersonnelPreview extends StatefulWidget {
  const PersonnelPreview({super.key});
  @override
  State<PersonnelPreview> createState() => _PersonnelPreviewState();
}

class _PersonnelPreviewState extends State<PersonnelPreview> {
  final fixture = PersonnelFixture();
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
    home: Scaffold(body: UsersPage(api: fixture.api)),
  );
}
