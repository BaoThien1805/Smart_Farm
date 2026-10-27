import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'farm_repository.dart';
import 'finance_values.dart';
import '../../core/ui_components.dart';

const revenueBlue = FarmColors.info;
const revenueAmber = FarmColors.warning;

String revenueMonth(String month) => month.split('-').reversed.join('/');

String compactRevenue(double amount) {
  if (amount >= 1e12) return amount.toStringAsExponential(0);
  if (amount >= 1e9) return '${(amount / 1e9).toStringAsFixed(1)} tỷ';
  if (amount >= 1e6) return '${(amount / 1e6).toStringAsFixed(1)} tr';
  if (amount >= 1e3) return '${(amount / 1e3).toStringAsFixed(0)} k';
  return amount.toStringAsFixed(0);
}

/// The chart uses approximate ratios only; monetary labels retain API strings.
class RevenueChart extends StatefulWidget {
  final List<FarmRecord> monthly;
  const RevenueChart({super.key, required this.monthly});

  @override
  State<RevenueChart> createState() => _RevenueChartState();
}

class _RevenueChartState extends State<RevenueChart> {
  String metric = 'salesRevenue';
  String? selectedMonth;
  static const metrics = {
    'salesRevenue': ('Doanh thu bán', forest),
    'income': ('Tổng thu', revenueBlue),
    'expense': ('Tổng chi', revenueAmber),
  };

  @override
  Widget build(BuildContext context) {
    final months = [...widget.monthly]
      ..sort((a, b) => a.text('month').compareTo(b.text('month')));
    if (months.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Text('Chưa có số liệu. Hãy tải lại Tổng quan.'),
      );
    }
    final selected = months.firstWhere(
      (month) => month.text('month') == selectedMonth,
      orElse: () => months.last,
    );
    final label = metrics[metric]!.$1;
    final color = metrics[metric]!.$2;
    final amounts = months.map((m) {
      final value = double.tryParse(m.text(metric)) ?? 0;
      return value.isFinite && value > 0 ? value : 0.0;
    }).toList();
    final maximum = amounts.fold<double>(0, (a, b) => a > b ? a : b);
    final ceiling = maximum == 0 ? 1.0 : maximum * 1.15;
    final total = months.fold<BigInt>(
      BigInt.zero,
      (sum, m) => sum + (BigInt.tryParse(m.text(metric)) ?? BigInt.zero),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label · ${months.length} tháng',
                  style: const TextStyle(color: muted),
                ),
                const SizedBox(height: 4),
                Text(
                  vnd(total),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in metrics.entries)
                  ChoiceChip(
                    label: Text(entry.value.$1),
                    selected: metric == entry.key,
                    onSelected: (_) => setState(() => metric = entry.key),
                    selectedColor: entry.value.$2.withValues(alpha: .12),
                    labelStyle: TextStyle(
                      color: metric == entry.key ? entry.value.$2 : ink,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Doanh thu bán nằm trong Tổng thu. Chỉ tính khoản hợp lệ.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 16),
        if (maximum == 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Chưa phát sinh ${label.toLowerCase()} trong khoảng thời gian này.',
            ),
          ),
        Semantics(
          label:
              'Biểu đồ cột $label theo tháng, đơn vị đồng. Tổng ${vnd(total)}. Chi tiết ở các nút tháng và bảng bên dưới.',
          child: SizedBox(
            height: 220,
            child: Row(
              children: [
                SizedBox(
                  width: 68,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          maximum == 0 ? 'VND' : compactRevenue(ceiling),
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          maximum == 0 ? '' : compactRevenue(ceiling / 2),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const Text('0', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final minWidth = months.length * 52.0;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: c.maxWidth > minWidth ? c.maxWidth : minWidth,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                bottom: 40,
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: List.generate(
                                    3,
                                    (_) =>
                                        const Divider(height: 1, color: line),
                                  ),
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  for (var i = 0; i < months.length; i++)
                                    Expanded(
                                      child: Tooltip(
                                        message:
                                            '${revenueMonth(months[i].text('month'))}: ${vnd(months[i].values[metric])}',
                                        child: Column(
                                          children: [
                                            Expanded(
                                              child: Align(
                                                alignment:
                                                    Alignment.bottomCenter,
                                                child: SizedBox(
                                                  width: 32,
                                                  child: Container(
                                                    key: ValueKey(
                                                      'revenue-bar-${months[i].text('month')}',
                                                    ),
                                                    height:
                                                        amounts[i] /
                                                        ceiling *
                                                        200,
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin:
                                                            Alignment.topCenter,
                                                        end: Alignment
                                                            .bottomCenter,
                                                        colors: [
                                                          color.withValues(
                                                            alpha: .6,
                                                          ),
                                                          color,
                                                        ],
                                                      ),
                                                      borderRadius:
                                                          const BorderRadius.vertical(
                                                            top:
                                                                Radius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              height: 40,
                                              child: Center(
                                                child: Text(
                                                  'T${months[i].text('month').split('-').last}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final month in months)
              ChoiceChip(
                label: Text(revenueMonth(month.text('month'))),
                selected: month == selected,
                onSelected: (_) =>
                    setState(() => selectedMonth = month.text('month')),
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.bar_chart_rounded, color: color),
              Text('$label · ${revenueMonth(selected.text('month'))}'),
              Text(
                vnd(selected.values[metric]),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FinanceTotals extends StatelessWidget {
  const FinanceTotals({super.key, required this.summary});
  final Map<String, dynamic> summary;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DashboardFinanceCards(summary: summary),
      const SizedBox(height: 12),
      const Text(
        'Doanh thu bán đã nằm trong Tổng thu. Chênh lệch thu chi chưa phải lợi nhuận kế toán. Khoản đã hủy không được tính vào báo cáo.',
        style: TextStyle(color: muted),
      ),
    ],
  );
}

class MonthlyFinanceChart extends StatelessWidget {
  const MonthlyFinanceChart({super.key, required this.monthly});
  final List<FarmRecord> monthly;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FarmInfoCard(child: RevenueChart(monthly: monthly)),
      const SizedBox(height: 24),
      const FarmSectionHeader(
        title: 'Chi tiết theo tháng',
        subtitle: 'Số tiền chính xác · VND · Chỉ tính khoản hợp lệ',
      ),
      const SizedBox(height: 16),
      for (final m in monthly.reversed) ...[
        FarmInfoCard(
          key: ValueKey('report-month-${m.text('month')}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tháng ${revenueMonth(m.text('month'))}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, c) {
                  final columns = c.maxWidth >= 900
                      ? 3
                      : c.maxWidth >= 600
                      ? 2
                      : 1;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final e in const {
                        'income': ('Tổng thu', FarmColors.mint, forest),
                        'expense': ('Tổng chi', FarmColors.peach, revenueAmber),
                        'difference': (
                          'Chênh lệch thu chi',
                          FarmColors.lavender,
                          FarmColors.purple,
                        ),
                      }.entries)
                        SizedBox(
                          width: (c.maxWidth - (columns - 1) * 12) / columns,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: e.value.$2,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.value.$1),
                                const SizedBox(height: 8),
                                Text(
                                  vnd(m.values[e.key]),
                                  style: TextStyle(
                                    color: e.value.$3,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Doanh thu bán: ${vnd(m.values['salesRevenue'])}',
                style: const TextStyle(
                  color: forest,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Doanh thu bán nằm trong Tổng thu.',
                style: TextStyle(color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    ],
  );
}

class DashboardFinanceCards extends StatelessWidget {
  final Map<String, dynamic> summary;
  const DashboardFinanceCards({super.key, required this.summary});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 960
          ? 4
          : constraints.maxWidth >= 540
          ? 2
          : 1;
      const entries = {
        'salesRevenue': (
          'Doanh thu bán vật nuôi',
          Icons.trending_up_rounded,
          forest,
        ),
        'income': ('Tổng thu', Icons.south_west_rounded, revenueBlue),
        'expense': ('Tổng chi', Icons.north_east_rounded, revenueAmber),
        'difference': (
          'Chênh lệch thu chi',
          Icons.account_balance_wallet_outlined,
          forest,
        ),
      };
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final entry in entries.entries)
            SizedBox(
              width: (constraints.maxWidth - (columns - 1) * 12) / columns,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: entry.key == 'salesRevenue' ? forest : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: entry.key == 'salesRevenue' ? forest : line,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      entry.value.$2,
                      color: entry.key == 'salesRevenue'
                          ? Colors.white
                          : entry.value.$3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      entry.value.$1,
                      style: TextStyle(
                        color: entry.key == 'salesRevenue'
                            ? Colors.white
                            : muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      vnd(summary[entry.key]),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        color: entry.key == 'salesRevenue' ? Colors.white : ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
