// Standalone Flutter preview. No network or saved session is used.
import 'package:flutter/material.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/home/workspace_page.dart';

import '../support/workspace_fixture.dart';

void main() => runApp(const WorkspacePreview());

class WorkspacePreview extends StatefulWidget {
  const WorkspacePreview({super.key});
  @override
  State<WorkspacePreview> createState() => _WorkspacePreviewState();
}

class _WorkspacePreviewState extends State<WorkspacePreview> {
  final fixture = WorkspaceFixture(
    const String.fromEnvironment('PREVIEW_ROLE', defaultValue: 'ADMIN'),
  );
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
    home: WorkspacePage(auth: fixture.auth),
  );
}
