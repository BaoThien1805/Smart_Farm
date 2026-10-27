// Fixture-only ledger preview; all writes remain in MockClient memory.
import 'package:flutter/material.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/finance_page.dart';

import '../support/finance_ledger_fixture.dart';

void main() => runApp(const FinanceLedgerPreview());

class FinanceLedgerPreview extends StatefulWidget {
  const FinanceLedgerPreview({super.key});
  @override
  State<FinanceLedgerPreview> createState() => _FinanceLedgerPreviewState();
}

class _FinanceLedgerPreviewState extends State<FinanceLedgerPreview> {
  final fixture = FinanceLedgerFixture();
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
    home: Scaffold(body: FinancePage(repository: fixture.repository)),
  );
}
