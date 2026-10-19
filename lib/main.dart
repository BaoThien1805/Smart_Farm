import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/login_page.dart';
import 'features/home/workspace_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartFarmApp());
}

class SmartFarmApp extends StatefulWidget {
  final AuthController? controller;
  const SmartFarmApp({super.key, this.controller});
  @override
  State<SmartFarmApp> createState() => _SmartFarmAppState();
}

class _SmartFarmAppState extends State<SmartFarmApp> {
  late final AuthController auth;
  @override
  void initState() {
    super.initState();
    auth =
        widget.controller ??
        AuthController(AuthRepository(ApiClient(), SecureTokenStore()));
    auth.initialize();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      auth.repository.api.dispose();
      auth.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Smart Farm',
    debugShowCheckedModeBanner: false,
    theme: farmTheme(),
    home: ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        if (auth.initializing) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Đang kiểm tra phiên đăng nhập',
              ),
            ),
          );
        }
        if (auth.user == null) return LoginPage(auth: auth);
        return WorkspacePage(key: ValueKey(auth.user!.id), auth: auth);
      },
    ),
  );
}
