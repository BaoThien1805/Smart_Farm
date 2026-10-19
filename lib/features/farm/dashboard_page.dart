import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'farm_repository.dart';
import 'farm_widgets.dart';
import 'finance_page.dart';
import 'revenue_chart.dart';
import 'weather_card.dart';

class FarmDashboard extends StatefulWidget {
  final FarmRepository repository;
  final String userName;
  final VoidCallback onAnimals, onCare;
  final VoidCallback? onStock, onFinance;
  final bool admin;
  final bool financeAccess;
  const FarmDashboard({
    super.key,
    required this.repository,
    required this.userName,
    required this.onAnimals,
    required this.onCare,
    this.onStock,
    this.onFinance,
    this.admin = false,
    this.financeAccess = false,
  });
  @override
  State<FarmDashboard> createState() => _FarmDashboardState();
}

class _FarmDashboardState extends State<FarmDashboard> {
  late final controller = FarmController(widget.repository);
  String category = 'farm';
  void load() => controller.load('/farm/dashboard');
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => FarmBody(
      controller: controller,
      title: '',
      refresh: load,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF174B38), Color(0xFF247155)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: forest.withValues(alpha: .10),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final small = constraints.maxWidth < 600;
                  final date =
                      (controller.data['today']?.toString() ?? farmToday())
                          .split('-')
                          .reversed
                          .join('/');
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chào ${widget.userName}',
                              style: TextStyle(
                                fontSize: small ? 20 : 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  date,
                                  style: const TextStyle(
                                    color: Color(0xFFDDEEE5),
                                    fontSize: 13,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Tải lại',
                                  onPressed: controller.loading ? null : load,
                                  icon: const Icon(
                                    Icons.refresh,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: small ? 130 : 180,
                        child: WeatherCard(
                          repository: widget.repository,
                          admin: widget.admin,
                          compact: true,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: forest,
                    ),
                    onPressed: widget.onAnimals,
                    icon: const Icon(Icons.pets_outlined, size: 18),
                    label: const Text('Xem vật nuôi'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF9AC5AF)),
                    ),
                    onPressed: widget.onCare,
                    icon: const Icon(Icons.event_note, size: 18),
                    label: const Text('Lịch chăm sóc'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in {
              'farm': ('Trang trại', Icons.pets_outlined),
              if (widget.admin || widget.financeAccess)
                'finance': ('Tài chính', Icons.bar_chart_rounded),
              'alerts': ('Cảnh báo', Icons.notifications_outlined),
            }.entries)
              ChoiceChip(
                avatar: Icon(entry.value.$2, size: 18),
                label: Text(entry.value.$1),
                selected: category == entry.key,
                onSelected: (_) => setState(() => category = entry.key),
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (category == 'farm') ...[
          Text(
            'Trang trại trong ngày',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final columns = c.maxWidth >= 650
                  ? 3
                  : c.maxWidth >= 300
                  ? 2
                  : 1;
              final width = (c.maxWidth - (columns - 1) * 12) / columns;
              const metrics = {
                'activeAnimals': ('Đang nuôi', Icons.pets_outlined),
                'activePens': ('Chuồng hoạt động', Icons.home_work_outlined),
                'needsCare': ('Cần chăm sóc', Icons.health_and_safety_outlined),
              };
              if (c.maxWidth < 600) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        for (final e in metrics.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                  e.value.$2,
                                  color: e.key == 'needsCare'
                                      ? revenueAmber
                                      : forest,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(e.value.$1)),
                                Text(
                                  '${controller.data[e.key] ?? '—'}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final e in metrics.entries)
                    SizedBox(
                      width: width,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    e.key == 'overdue' || e.key == 'needsCare'
                                    ? const Color(0xFFFFF2DE)
                                    : e.key == 'due'
                                    ? const Color(0xFFEAF0FA)
                                    : const Color(0xFFECF4EF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                e.value.$2,
                                color:
                                    e.key == 'overdue' || e.key == 'needsCare'
                                    ? revenueAmber
                                    : e.key == 'due'
                                    ? revenueBlue
                                    : forest,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              '${controller.data[e.key] ?? '—'}',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(e.value.$1),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
        ],
        if (category == 'finance' &&
            (widget.admin || widget.financeAccess) &&
            controller.data['finance'] is Map) ...[
          DashboardPanel(
            title: 'Tài chính tháng này',
            subtitle: 'Toàn trang trại · VND · Chỉ tính khoản hợp lệ',
            icon: Icons.account_balance_wallet_outlined,
            action: TextButton(
              onPressed: widget.onFinance,
              child: const Text('Xem báo cáo'),
            ),
            child: DashboardFinanceCards(
              summary: Map<String, dynamic>.from(
                controller.data['finance'] as Map,
              ),
            ),
          ),
          const SizedBox(height: 20),
          DashboardPanel(
            title: 'Biểu đồ doanh thu',
            subtitle: '6 tháng gần nhất · VND · Toàn trang trại',
            icon: Icons.bar_chart_rounded,
            child: RevenueChart(monthly: controller.items('financeMonthly')),
          ),
          const SizedBox(height: 20),
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Xem bảng doanh thu chi tiết'),
              children: [
                RevenueTable(monthly: controller.items('financeMonthly')),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (category != 'finance')
          LayoutBuilder(
            builder: (context, c) {
              final care = DashboardPanel(
                title: 'Lịch chăm sóc',
                subtitle:
                    '${controller.data['due'] ?? 0} việc hôm nay · ${controller.data['overdue'] ?? 0} quá hạn · 7 ngày tới',
                icon: Icons.event_note,
                action: TextButton(
                  onPressed: widget.onCare,
                  child: const Text('Xem tất cả'),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (controller.items('tasks').isEmpty)
                      const DashboardEmpty(
                        icon: Icons.event_available_outlined,
                        text: 'Chưa có lịch chăm sóc sắp tới.',
                      ),
                    for (final t in controller.items('tasks').take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: widget.onCare,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F7F1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${t.text('animalCode')} · ${t.text('title')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${t.text('dueDate')} · ${label(t.text('kind'))}',
                                ),
                                if (t
                                        .text('dueDate')
                                        .compareTo(
                                          controller.data['today']
                                                  ?.toString() ??
                                              farmToday(),
                                        ) <
                                    0)
                                  const Chip(label: Text('Quá hạn')),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
              final alerts = DashboardPanel(
                title: 'Cần lưu ý',
                subtitle: 'Kho thức ăn và sức chứa toàn trang trại',
                icon: Icons.warning_amber_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (controller.items('lowStockFeeds').isEmpty &&
                        controller.items('fullPens').isEmpty)
                      const DashboardEmpty(
                        icon: Icons.check_circle_outline,
                        text: 'Kho và chuồng chưa có cảnh báo.',
                      ),
                    for (final f in controller.items('lowStockFeeds'))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: widget.onStock,
                        leading: const Icon(
                          Icons.inventory_2_outlined,
                          color: Color(0xFF92502A),
                        ),
                        title: Text(f.text('name')),
                        subtitle: Text(
                          'Tồn thấp · ${f.number('stock')} kg / ngưỡng ${f.number('lowStock')} kg',
                        ),
                      ),
                    for (final p in controller.items('fullPens'))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.home_work_outlined,
                          color: Color(0xFF92502A),
                        ),
                        title: Text('${p.text('code')} · ${p.text('name')}'),
                        subtitle: Text(
                          'Chuồng đầy · ${p.integer('occupied')}/${p.integer('capacity')} con',
                        ),
                      ),
                  ],
                ),
              );
              return category == 'farm' ? care : alerts;
            },
          ),
      ],
    ),
  );
}

class DashboardPanel extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Widget child;
  final Widget? action;
  const DashboardPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: line),
      boxShadow: [
        BoxShadow(
          color: ink.withValues(alpha: .035),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFECF4EF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: forest),
            ),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            ?action,
          ],
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: muted)),
        const SizedBox(height: 20),
        child,
      ],
    ),
  );
}

class DashboardEmpty extends StatelessWidget {
  final IconData icon;
  final String text;
  const DashboardEmpty({super.key, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Row(
      children: [
        Icon(icon, color: forest),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class RevenueTable extends StatelessWidget {
  final List<FarmRecord> monthly;
  const RevenueTable({super.key, required this.monthly});
  @override
  Widget build(BuildContext context) => DashboardPanel(
    title: 'Bảng thống kê doanh thu',
    subtitle: '6 tháng gần nhất · Doanh thu bán nằm trong Tổng thu',
    icon: Icons.table_chart_outlined,
    child: LayoutBuilder(
      builder: (context, c) {
        if (monthly.isEmpty) {
          return const DashboardEmpty(
            icon: Icons.bar_chart_outlined,
            text: 'Chưa có số liệu thống kê. Hãy tải lại Tổng quan.',
          );
        }
        const fields = {
          'salesRevenue': 'Doanh thu bán',
          'income': 'Tổng thu',
          'expense': 'Tổng chi',
          'difference': 'Chênh lệch',
        };
        if (c.maxWidth < 800) {
          return Column(
            children: [
              for (final m in monthly)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F7F1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tháng ${m.text('month').split('-').reversed.join('/')}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      for (final e in fields.entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Text(
                                '${e.value}:',
                                style: const TextStyle(color: muted),
                              ),
                              Text(
                                vnd(m.values[e.key]),
                                style: TextStyle(
                                  fontWeight: e.key == 'salesRevenue'
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: e.key == 'salesRevenue'
                                      ? forest
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        }
        Widget row(
          List<String> cells, {
          bool header = false,
          bool stripe = false,
        }) => Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: header
                ? forest
                : stripe
                ? const Color(0xFFF3F7F1)
                : Colors.white,
            borderRadius: header ? BorderRadius.circular(10) : null,
            border: header
                ? null
                : const Border(bottom: BorderSide(color: line)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cells.length; i++)
                Expanded(
                  flex: i == 0 ? 1 : 2,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      cells[i],
                      style: TextStyle(
                        color: header
                            ? Colors.white
                            : i == 1
                            ? forest
                            : null,
                        fontWeight: header || i == 1
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
        return Column(
          children: [
            row(['Tháng', ...fields.values], header: true),
            for (var i = 0; i < monthly.length; i++)
              row([
                monthly[i].text('month').split('-').reversed.join('/'),
                for (final key in fields.keys) vnd(monthly[i].values[key]),
              ], stripe: i.isEven),
          ],
        );
      },
    ),
  );
}
