// All reads and writes use a local MockClient; no live account is accessed.
import 'package:flutter/material.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/auth/login_page.dart';
import 'package:smart_farm/features/home/profile_page.dart';

import '../support/account_profile_fixture.dart';

void main() => runApp(const AccountProfilePreview());

class AccountProfilePreview extends StatefulWidget {
  const AccountProfilePreview({super.key});
  @override
  State<AccountProfilePreview> createState() => _AccountProfilePreviewState();
}

class _AccountProfilePreviewState extends State<AccountProfilePreview> {
  final fixture = AccountProfileFixture();
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
    home: ListenableBuilder(
      listenable: fixture.auth,
      builder: (context, _) => fixture.auth.user == null
          ? LoginPage(auth: fixture.auth)
          : Scaffold(body: ProfilePage(auth: fixture.auth)),
    ),
  );
}
