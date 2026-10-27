// Isolated preview. All requests are mocked; no session or online write occurs.
import 'package:flutter/material.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/auth/login_page.dart';
import 'package:smart_farm/features/farm/species_chooser.dart';

import '../support/auth_onboarding_fixture.dart';

void main() => runApp(const AuthOnboardingPreview());

class AuthOnboardingPreview extends StatefulWidget {
  const AuthOnboardingPreview({super.key});
  @override
  State<AuthOnboardingPreview> createState() => _AuthOnboardingPreviewState();
}

class _AuthOnboardingPreviewState extends State<AuthOnboardingPreview> {
  final fixture = AuthOnboardingFixture();
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
    home: const String.fromEnvironment('PREVIEW_SCREEN') == 'species'
        ? SpeciesChooser(
            repository: fixture.repository,
            admin: true,
            userName: 'Chủ trang trại mẫu',
            onContinue: (_) {},
            onLogout: () {},
          )
        : LoginPage(auth: fixture.auth),
  );
}
