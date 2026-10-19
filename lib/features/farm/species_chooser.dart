import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'farm_repository.dart';
import 'farm_pages.dart';

IconData speciesIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('heo') || n.contains('lợn')) return Icons.savings_outlined;
  if (n.contains('gà') || n.contains('vịt') || n.contains('gia cầm')) {
    return Icons.egg_outlined;
  }
  if (n.contains('cá') || n.contains('tôm')) return Icons.water_outlined;
  if (n.contains('bò') || n.contains('trâu')) return Icons.agriculture_outlined;
  return Icons.pets;
}

const livestockGroups = ['Gia súc', 'Gia cầm', 'Thủy sản', 'Vật nuôi khác'];
String livestockGroup(String name) {
  final n = name.trim().toLowerCase();
  if (RegExp(r'^(gà|vịt|ngan|ngỗng|cút|gia cầm)(\s|$)').hasMatch(n)) {
    return 'Gia cầm';
  }
  if (RegExp(r'^(bò|trâu|heo|lợn|dê|cừu|ngựa|gia súc)(\s|$)').hasMatch(n)) {
    return 'Gia súc';
  }
  if (RegExp(r'^(cá|tôm|cua|ếch|thủy sản)(\s|$)').hasMatch(n)) {
    return 'Thủy sản';
  }
  return 'Vật nuôi khác';
}

class SpeciesChooser extends StatefulWidget {
  final FarmRepository repository;
  final bool admin;
  final String userName;
  final ValueChanged<List<String>> onContinue;
  final VoidCallback onLogout;
  const SpeciesChooser({
    super.key,
    required this.repository,
    required this.admin,
    required this.userName,
    required this.onContinue,
    required this.onLogout,
  });
  @override
  State<SpeciesChooser> createState() => _SpeciesChooserState();
}

class _SpeciesChooserState extends State<SpeciesChooser> {
  List<FarmRecord> species = [];
  Set<String> selected = {};
  bool loading = true, busy = false, expanded = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final data = await Future.wait([
        widget.repository.get(
          widget.admin
              ? '/farm/catalogs?includeAvailable=true'
              : '/farm/catalogs',
        ),
        widget.repository.get('/farm/preferences'),
      ]);
      if (mounted) {
        setState(() {
          species = FarmRepository.records(data[0], 'species');
          selected = ((data[1]['speciesIds'] as List?) ?? [])
              .whereType<String>()
              .where((id) => species.any((s) => s.id == id))
              .toSet();
          error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submit({bool all = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    final ids = all ? species.map((s) => s.id).toList() : selected.toList();
    try {
      await widget.repository.save('PATCH', '/farm/preferences', {
        'speciesIds': ids,
      });
      if (mounted) widget.onContinue(ids);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget groupCard(String group) {
    final members = species
        .where((s) => livestockGroup(s.text('name')) == group)
        .toList();
    final count = members.where((s) => selected.contains(s.id)).length;
    return Card(
      child: Column(
        children: [
          CheckboxListTile(
            title: Text(group),
            subtitle: Text(
              members.isEmpty
                  ? 'Chưa có loài trong nhóm này'
                  : '$count/${members.length} loài đã chọn',
            ),
            tristate: true,
            value: count == 0
                ? false
                : count == members.length
                ? true
                : null,
            onChanged: busy || loading || members.isEmpty
                ? null
                : (_) => setState(() {
                    if (count == members.length) {
                      selected.removeAll(members.map((s) => s.id));
                    } else {
                      selected.addAll(members.map((s) => s.id));
                    }
                  }),
          ),
          for (final s in members)
            CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              value: selected.contains(s.id),
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      if (v == true) {
                        selected.add(s.id);
                      } else {
                        selected.remove(s.id);
                      }
                    }),
              title: Text(s.text('name')),
              secondary: Icon(speciesIcon(s.text('name')), color: forest),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Brand(),
      actions: [
        TextButton(
          onPressed: busy ? null : widget.onLogout,
          child: const Text('Đăng xuất'),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chào ${widget.userName}.',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const Text('Bắt đầu quản lý công việc chăn nuôi của bạn.'),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.agriculture_outlined,
                          size: 40,
                          color: forest,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.admin
                              ? 'Bạn có trang trại riêng?'
                              : 'Trang trại của bạn',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Chọn những loài đang nuôi để theo dõi vật nuôi, chăm sóc và kho.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: busy
                              ? null
                              : () => setState(() => expanded = !expanded),
                          icon: Icon(
                            expanded ? Icons.expand_less : Icons.expand_more,
                          ),
                          label: Text(
                            widget.admin
                                ? 'Quản lý trang trại của tôi'
                                : 'Vào trang trại làm việc',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (expanded) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Chọn vật nuôi trong trang trại',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Chọn các loài trang trại đang nuôi. Lựa chọn được lưu; sau này bổ sung tại mục Thêm loài.',
                  ),
                  const SizedBox(height: 16),
                  if (error != null) FeedbackBox(error!),
                  if (loading) const LinearProgressIndicator(),
                  if (!loading && species.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Chưa có loài. ADMIN có thể thêm loài trong danh mục hoặc vào trang trại trước.',
                      ),
                    ),
                  for (final group in livestockGroups) groupCard(group),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        onPressed: loading || busy || selected.isEmpty
                            ? null
                            : () => submit(),
                        child: Text(
                          busy
                              ? 'Đang lưu…'
                              : 'Tiếp tục (${selected.length} loài)',
                        ),
                      ),
                      OutlinedButton(
                        onPressed: loading || busy
                            ? null
                            : () => submit(all: true),
                        child: const Text('Xem tất cả'),
                      ),
                      TextButton.icon(
                        onPressed: loading || busy ? null : load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tải lại'),
                      ),
                      if (widget.admin)
                        TextButton.icon(
                          onPressed: busy
                              ? null
                              : () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => Scaffold(
                                        appBar: AppBar(
                                          title: const Text(
                                            'Danh mục trang trại',
                                          ),
                                        ),
                                        body: CatalogPage(
                                          repository: widget.repository,
                                          admin: true,
                                        ),
                                      ),
                                    ),
                                  );
                                  if (mounted) load();
                                },
                          icon: const Icon(Icons.add),
                          label: const Text('Quản lý loài / giống'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
