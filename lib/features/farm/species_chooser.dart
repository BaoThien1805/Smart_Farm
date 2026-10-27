import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/farm_illustrations.dart';
import '../../core/ui_components.dart';
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
  bool loading = true, busy = false, loadFailed = false;
  String? error;
  final errorAnchor = GlobalKey();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (busy) return;
    setState(() {
      loading = true;
      error = null;
      loadFailed = false;
    });
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
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          loadFailed = true;
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submit({bool all = false}) async {
    if (busy || loading || loadFailed) return;
    final ids = all ? species.map((s) => s.id).toList() : selected.toList();
    if (widget.admin && ids.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.save('PATCH', '/farm/preferences', {
        'speciesIds': ids,
      });
      if (mounted) widget.onContinue(ids);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted && errorAnchor.currentContext != null) {
          await Scrollable.ensureVisible(
            errorAnchor.currentContext!,
            duration: const Duration(milliseconds: 200),
          );
        }
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void toggle(FarmRecord animalSpecies) => setState(() {
    if (!selected.add(animalSpecies.id)) selected.remove(animalSpecies.id);
  });

  Widget speciesCard(FarmRecord animalSpecies, double width) {
    final checked = selected.contains(animalSpecies.id);
    final enabled = !loading && !busy;
    void onTap() => toggle(animalSpecies);
    return SizedBox(
      width: width,
      child: Semantics(
        label: animalSpecies.text('name'),
        checked: checked,
        enabled: enabled,
        onTap: enabled ? onTap : null,
        child: ExcludeSemantics(
          child: Material(
            color: checked ? FarmColors.mint : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FarmRadii.card),
              side: BorderSide(
                color: checked ? forest : line,
                width: checked ? 2 : 1,
              ),
            ),
            child: InkWell(
              key: ValueKey('species-${animalSpecies.id}'),
              borderRadius: BorderRadius.circular(FarmRadii.card),
              onTap: enabled ? onTap : null,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Icon(
                        checked ? Icons.check_circle : Icons.circle_outlined,
                        size: 24,
                        color: checked ? forest : muted,
                      ),
                    ),
                    FarmSpeciesIllustration(
                      speciesCode: animalSpecies.text('code'),
                      speciesName: animalSpecies.text('name'),
                      size: 80,
                      decorative: true,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      animalSpecies.text('name'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (animalSpecies.text('code').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        animalSpecies.text('code'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: muted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget groupSelector(String group) {
    final members = species
        .where((s) => livestockGroup(s.text('name')) == group)
        .toList();
    final count = members.where((s) => selected.contains(s.id)).length;
    return CheckboxListTile(
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
    );
  }

  Future<void> openCatalog() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Danh mục trang trại')),
          body: CatalogPage(
            repository: widget.repository,
            admin: true,
            initialKind: 'species',
            availableKinds: const ['species', 'breeds', 'areas'],
          ),
        ),
      ),
    );
    if (mounted) load();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
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
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'Chọn loài nuôi',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Chào ${widget.userName}.'),
                        const SizedBox(height: 8),
                        const Text(
                          'Chọn các loài vật nuôi bạn muốn quản lý trong trang trại. Bạn có thể bổ sung thêm sau.',
                        ),
                        const SizedBox(height: 20),
                        Column(
                          key: errorAnchor,
                          children: [if (error != null) FeedbackBox(error!)],
                        ),
                        if (loading) const LinearProgressIndicator(),
                        if (!loading && !loadFailed && species.isEmpty)
                          const FarmInfoCard(
                            child: Text(
                              'Chưa có loài. Chủ trang trại cần thêm loài trong danh mục để hoàn tất thiết lập.',
                            ),
                          ),
                        if (!loading && !loadFailed)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth >= 800
                                  ? 4
                                  : constraints.maxWidth >= 500
                                  ? 3
                                  : 2;
                              final width =
                                  (constraints.maxWidth - (columns - 1) * 12) /
                                  columns;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  for (final item in species)
                                    speciesCard(item, width),
                                ],
                              );
                            },
                          ),
                        const SizedBox(height: 16),
                        if (species.isNotEmpty && !loadFailed)
                          Card(
                            child: ExpansionTile(
                              title: const Text('Chọn theo nhóm'),
                              children: [
                                for (final group in livestockGroups)
                                  groupSelector(group),
                              ],
                            ),
                          ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: loading || busy ? null : load,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tải lại'),
                            ),
                            if (widget.admin)
                              TextButton.icon(
                                onPressed: busy ? null : openCatalog,
                                icon: const Icon(Icons.add),
                                label: const Text('Quản lý loài / giống'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Bạn đã chọn ${selected.length} loài',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: FilledButton(
                                key: const ValueKey('species-continue'),
                                onPressed:
                                    loading ||
                                        busy ||
                                        loadFailed ||
                                        selected.isEmpty
                                    ? null
                                    : () => submit(),
                                child: Text(
                                  busy
                                      ? 'Đang lưu…'
                                      : 'Tiếp tục (${selected.length} loài)',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    loading ||
                                        busy ||
                                        loadFailed ||
                                        (widget.admin && species.isEmpty)
                                    ? null
                                    : () => submit(all: true),
                                child: const Text(
                                  'Xem tất cả',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
