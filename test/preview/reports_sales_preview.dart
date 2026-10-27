import 'package:flutter/material.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';
import 'package:smart_farm/features/farm/finance_page.dart';
import 'package:smart_farm/features/farm/sales_forms.dart';

import '../support/reports_sales_fixture.dart';
import '../support/workspace_fixture.dart';

void main() => runApp(const ReportsSalesPreview());

class ReportsSalesPreview extends StatefulWidget {
  const ReportsSalesPreview({super.key});
  @override
  State<ReportsSalesPreview> createState() => _ReportsSalesPreviewState();
}

class _ReportsSalesPreviewState extends State<ReportsSalesPreview> {
  final fixture = ReportsSalesFixture();
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
    home: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('Preview bước 14 · Dữ liệu mô phỏng'),
          actions: [
            TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => SaleEditor(
                  repository: fixture.repository,
                  animal: FarmRecord(WorkspaceFixture.animal),
                ),
              ),
              child: const Text('Form bán'),
            ),
            TextButton(
              onPressed: () => cancelSaleForm(
                context,
                fixture.repository,
                FarmRecord(fixture.sales.first),
                admin: true,
              ),
              child: const Text('Form hủy'),
            ),
          ],
        ),
        body: FinancePage(repository: fixture.repository),
      ),
    ),
  );
}
