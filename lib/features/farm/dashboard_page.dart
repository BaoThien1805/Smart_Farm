import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/farm_illustrations.dart';
import '../../core/farm_feature_icon.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import 'farm_repository.dart';
import 'farm_widgets.dart';
import 'finance_page.dart';
import 'revenue_chart.dart';
import 'weather_card.dart';

class FarmDashboard extends StatefulWidget {
  final FarmRepository repository;
  final String userName;
  final VoidCallback onAnimals, onCare;
  final VoidCallback? onStock, onFinance, onPens;
  final bool admin, financeAccess;
  final int locationRevision;
  final int refreshRevision;
  final VoidCallback? onLocationChanged;
  const FarmDashboard({
    super.key,
    required this.repository,
    required this.userName,
    required this.onAnimals,
    required this.onCare,
    this.onStock,
    this.onFinance,
    this.onPens,
    this.admin = false,
    this.financeAccess = false,
    this.locationRevision = 0,
    this.refreshRevision = 0,
    this.onLocationChanged,
  });
  @override
  State<FarmDashboard> createState() => _FarmDashboardState();
}

class _FarmDashboardState extends State<FarmDashboard> {
  late final controller = FarmController(widget.repository);
  String category = 'farm';
  String? farmName;
  int locationGeneration = 0;
  bool get canFinance => widget.admin || widget.financeAccess;
  bool get hasData => controller.data.isNotEmpty;
  void load() {
    controller.load('/farm/dashboard', withPenSpecies: true);
    loadFarmName();
  }

  Future<void> loadFarmName() async {
    final generation = ++locationGeneration;
    try {
      final response = await widget.repository.get('/farm/location');
      final location = response['location'];
      final name = location is Map ? location['name']?.toString().trim() : null;
      if (mounted && generation == locationGeneration) {
        setState(() => farmName = name);
      }
    } on ApiException {
      // The header name is optional; dashboard data and weather stay independent.
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant FarmDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshRevision != widget.refreshRevision) load();
    if (oldWidget.locationRevision != widget.locationRevision) loadFarmName();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String count(String key) => controller.data[key]?.toString() ?? '—';

  Widget header() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  farmName?.isNotEmpty == true
                      ? farmName!
                      : 'Trang trại của bạn',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Chào ${widget.userName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      (controller.data['today']?.toString() ?? farmToday())
                          .split('-')
                          .reversed
                          .join('/'),
                      style: const TextStyle(color: muted),
                    ),
                    IconButton(
                      tooltip: 'Tải lại',
                      onPressed: controller.loading ? null : load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 112,
            child: WeatherCard(
              key: ValueKey(widget.locationRevision),
              repository: widget.repository,
              admin: widget.admin,
              compact: true,
              onLocationChanged: widget.onLocationChanged,
            ),
          ),
        ],
      ),
    ],
  );

  Widget metrics() => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          MediaQuery.textScalerOf(context).scale(14) <= 18 ||
              constraints.maxWidth >= 600
          ? 3
          : 2;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      final labelStyle = Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: ink);
      // Reserve the same label height so a wrapped caption cannot make one
      // summary card taller than its neighbours, including with large text.
      var labelHeight = 0.0;
      for (final label in ['Đang nuôi', 'Chuồng hoạt động', 'Việc hôm nay']) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 2,
        )..layout(maxWidth: width > 24 ? width - 24 : 1);
        if (painter.height > labelHeight) labelHeight = painter.height;
        painter.dispose();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final metric in [
                (
                  'activeAnimals',
                  'Đang nuôi',
                  Icons.pets_outlined,
                  FarmColors.mint,
                  widget.onAnimals,
                ),
                (
                  'activePens',
                  'Chuồng hoạt động',
                  Icons.home_work_outlined,
                  FarmColors.peach,
                  widget.onPens,
                ),
                (
                  'due',
                  'Việc hôm nay',
                  Icons.calendar_month_outlined,
                  FarmColors.lavender,
                  widget.onCare,
                ),
              ])
                SizedBox(
                  width: width,
                  child: FarmInfoCard(
                    color: metric.$4,
                    padding: EdgeInsets.zero,
                    child: InkWell(
                      key: ValueKey('dashboard-${metric.$1}'),
                      onTap: metric.$5,
                      borderRadius: BorderRadius.circular(FarmRadii.card),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            FarmFeatureIcon(
                              icon: metric.$3,
                              size: 38,
                              background: metric.$4,
                              color: metric.$1 == 'due'
                                  ? FarmColors.lilac
                                  : metric.$1 == 'activePens'
                                  ? FarmColors.coral
                                  : forest,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              count(metric.$1),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            SizedBox(
                              height: labelHeight,
                              child: Text(
                                metric.$2,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: labelStyle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          FarmInfoCard(
            color: FarmColors.mint,
            padding: EdgeInsets.zero,
            child: ListTile(
              key: const ValueKey('dashboard-needsCare'),
              onTap: widget.onAnimals,
              leading: const FarmFeatureIcon(
                icon: Icons.health_and_safety_outlined,
                color: forest,
                size: 38,
              ),
              title: const Text('Cần chăm sóc'),
              trailing: Text(
                count('needsCare'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget care() => DashboardPanel(
    title: 'Việc cần làm',
    subtitle:
        '${count('due')} việc hôm nay · ${count('overdue')} quá hạn · 7 ngày tới',
    icon: Icons.calendar_month_outlined,
    action: TextButton(
      onPressed: widget.onCare,
      child: const Text('Xem tất cả'),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.items('tasks').isEmpty)
          const DashboardEmpty(
            icon: Icons.event_available_outlined,
            text: 'Chưa có lịch chăm sóc sắp tới.',
          ),
        for (final task in controller.items('tasks').take(3))
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: FarmColors.cream,
            child: ListTile(
              onTap: widget.onCare,
              leading: const Icon(Icons.event_note_outlined, color: forest),
              title: Text('${task.text('animalCode')} · ${task.text('title')}'),
              subtitle: Text(
                '${farmDate(task.text('dueDate'))} · ${label(task.text('kind'))}'
                '${task.text('dueDate').compareTo(controller.data['today']?.toString() ?? farmToday()) < 0 ? ' · Quá hạn' : ''}',
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
      ],
    ),
  );

  Widget penOverview() => LayoutBuilder(
    builder: (context, c) {
      final columns =
          c.maxWidth >= 300 && MediaQuery.textScalerOf(context).scale(14) <= 18
          ? 4
          : 2;
      final width = (c.maxWidth - (columns - 1) * 8) / columns;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FarmSectionHeader(title: 'Tình trạng chuồng trại'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final pen in controller.items('pens').take(4))
                SizedBox(
                  width: width,
                  child: FarmInfoCard(
                    padding: EdgeInsets.zero,
                    child: InkWell(
                      onTap: widget.onPens,
                      borderRadius: BorderRadius.circular(FarmRadii.card),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            FarmPenIllustration(
                              iconKey: pen.text('iconKey'),
                              iconData: pen.text('iconData'),
                              size: 52,
                              decorative: true,
                              speciesNames:
                                  (pen.values['speciesNames'] as List?)
                                      ?.whereType<String>()
                                      .toList() ??
                                  const [],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pen.text('name'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: ink,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${pen.integer('occupied')}/${pen.integer('capacity')} con',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: pen.integer('capacity') > 0
                                  ? (pen.integer('occupied') /
                                            pen.integer('capacity'))
                                        .clamp(0, 1)
                                  : 0,
                              color:
                                  pen.integer('occupied') >=
                                      pen.integer('capacity')
                                  ? FarmColors.gold
                                  : const Color(0xFF2CBD6B),
                              backgroundColor: FarmColors.mint,
                              minHeight: 5,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    },
  );

  Widget alerts() => DashboardPanel(
    title: 'Cần lưu ý',
    subtitle: 'Tồn kho thức ăn toàn trang trại',
    icon: Icons.warning_amber_rounded,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.items('lowStockFeeds').isEmpty)
          const DashboardEmpty(
            icon: Icons.check_circle_outline,
            text: 'Kho thức ăn chưa có cảnh báo.',
          ),
        for (final feed in controller.items('lowStockFeeds'))
          Card(
            color: FarmColors.amber,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: widget.onStock,
              leading: const Icon(
                Icons.inventory_2_outlined,
                color: FarmColors.warning,
              ),
              title: Text(feed.text('name')),
              subtitle: Text(
                'Tồn thấp · ${feed.number('stock')} kg / ngưỡng ${feed.number('lowStock')} kg',
              ),
              trailing: widget.onStock == null
                  ? null
                  : const Icon(Icons.chevron_right),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => FarmBody(
      controller: controller,
      title: '',
      refresh: load,
      children: [
        header(),
        const SizedBox(height: 8),
        const FarmWelcomeBanner(),
        if (controller.error != null && hasData)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Đang hiển thị dữ liệu từ lần tải trước. Hãy thử tải lại.',
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in {
              'farm': ('Trang trại', Icons.pets_outlined),
              if (canFinance) 'finance': ('Tài chính', Icons.bar_chart_rounded),
              'alerts': ('Cảnh báo', Icons.notifications_outlined),
            }.entries)
              ChoiceChip(
                showCheckmark: false,
                label: Text(entry.value.$1),
                selected: category == entry.key,
                onSelected: (_) => setState(() => category = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (hasData && category == 'farm') ...[
          metrics(),
          const SizedBox(height: 16),
          care(),
          const SizedBox(height: 16),
          if (controller.items('pens').isNotEmpty) ...[
            penOverview(),
            const SizedBox(height: 16),
          ],
          FarmInfoCard(
            color: FarmColors.peach,
            padding: EdgeInsets.zero,
            child: ListTile(
              key: const ValueKey('dashboard-pens'),
              onTap: widget.onPens,
              leading: const FarmPenIllustration(size: 48, decorative: true),
              title: const Text('Chuồng trại'),
              subtitle: Text(
                '${count('activePens')} chuồng hoạt động · Xem danh sách và sức chứa',
              ),
              trailing: widget.onPens == null
                  ? null
                  : const Icon(Icons.chevron_right),
            ),
          ),
          if (controller.items('lowStockFeeds').isNotEmpty) ...[
            const SizedBox(height: 16),
            alerts(),
          ],
        ],
        if (hasData && category == 'alerts') alerts(),
        if (hasData && category == 'finance' && canFinance) ...[
          if (controller.data['finance'] is Map) ...[
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
          ],
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
        ],
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
                color: FarmColors.mint,
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
                    color: FarmColors.cream,
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
