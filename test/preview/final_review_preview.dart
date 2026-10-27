// Integrated workspace fixture for manual Web review. No live API or session.
// URL parameters: ?role=ADMIN|STAFF|VET|ACCOUNTANT&scenario=ready|empty|error|slow|weather
import 'package:flutter/material.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/home/workspace_page.dart';

import '../support/final_review_fixture.dart';

void main() => runApp(const FinalReviewPreview());

class FinalReviewPreview extends StatefulWidget {
  const FinalReviewPreview({super.key});
  @override
  State<FinalReviewPreview> createState() => _FinalReviewPreviewState();
}

class _FinalReviewPreviewState extends State<FinalReviewPreview> {
  late final fixture = FinalReviewFixture(
    Uri.base.queryParameters['role'] ?? 'ADMIN',
    scenario: Uri.base.queryParameters['scenario'] ?? 'ready',
  );
  @override
  void dispose() {
    fixture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Smart Farm · Kiểm tra bước 17 · dữ liệu thử nghiệm',
    theme: farmTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(1.3)),
      child: child!,
    ),
    home: WorkspacePage(auth: fixture.auth),
  );
}
