import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../auth/auth_controller.dart';
import '../auth/user_avatar.dart';
import '../users/users_page.dart';
import '../farm/farm_pages.dart';
import '../farm/farm_repository.dart';
import '../farm/inventory_page.dart';
import '../farm/finance_page.dart';
import '../farm/species_chooser.dart';
import 'profile_page.dart';

class WorkspacePage extends StatefulWidget {
  final AuthController auth;
  const WorkspacePage({super.key, required this.auth});
  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  int? selected;
  bool ready = false, checkingSetup = true;
  String? setupError;
  late final repository = FarmRepository(widget.auth.repository.api);
  @override
  void initState() {
    super.initState();
    if (widget.auth.user!.isAdmin) {
      loadSetup();
    } else {
      checkingSetup = false;
    }
  }

  Future<void> loadSetup() async {
    setState(() {
      checkingSetup = true;
      setupError = null;
    });
    try {
      final settings = await repository.get('/farm/species-settings');
      if (mounted) setState(() => ready = settings['configured'] == true);
    } on ApiException catch (e) {
      if (mounted) setState(() => setupError = e.message);
    } finally {
      if (mounted) setState(() => checkingSetup = false);
    }
  }

  void navigate(int value) {
    setState(() => selected = value);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user!;
    if (checkingSetup || setupError != null) {
      return Scaffold(
        body: Center(
          child: checkingSetup
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FeedbackBox(setupError!),
                    TextButton(
                      onPressed: loadSetup,
                      child: const Text('Thử lại'),
                    ),
                    TextButton(
                      onPressed: widget.auth.logout,
                      child: const Text('Đăng xuất'),
                    ),
                  ],
                ),
        ),
      );
    }
    if (user.isAdmin && !ready) {
      return SpeciesChooser(
        repository: repository,
        admin: user.isAdmin,
        userName: user.name,
        onLogout: widget.auth.logout,
        onContinue: (ids) => setState(() {
          repository.selectedSpeciesIds = [];
          ready = true;
        }),
      );
    }
    final labels = [
      'Tổng quan',
      'Vật nuôi',
      'Chăm sóc',
      'Kho',
      'Tài khoản',
      if (user.isAdmin) 'Nhân sự',
      'Trang trại',
      if (user.canFinance) 'Thu chi',
    ];
    final selectedIndex =
        selected ??
        labels.indexOf(switch (user.role) {
          'STAFF' => 'Vật nuôi',
          'VET' => 'Chăm sóc',
          'ACCOUNTANT' => 'Thu chi',
          _ => 'Tổng quan',
        });
    final bottomItems = user.role == 'ACCOUNTANT'
        ? [0, labels.indexOf('Thu chi'), 1, 2, 4]
        : [0, 1, 2, 3, 4];
    final icons = [
      Icons.grid_view_rounded,
      Icons.pets,
      Icons.event_note,
      Icons.inventory_2_outlined,
      Icons.person_outline,
      if (user.isAdmin) Icons.people_outline,
      Icons.home_work_outlined,
      if (user.canFinance) Icons.account_balance_wallet_outlined,
    ];
    final pages = <Widget>[
      FarmDashboard(
        repository: repository,
        userName: user.name,
        onAnimals: () => navigate(1),
        onCare: () => navigate(2),
        onStock: () => navigate(3),
        admin: user.isAdmin,
        financeAccess: user.canFinance,
        onFinance: user.canFinance
            ? () => navigate(labels.indexOf('Thu chi'))
            : null,
      ),
      AnimalsPage(
        repository: repository,
        admin: user.isAdmin,
        canOperate: user.canOperate,
        canCare: user.canCare,
        canExamine: user.canExamine,
        canFinance: user.canFinance,
      ),
      CarePage(
        repository: repository,
        admin: user.isAdmin,
        canOperate: user.canOperate,
        canCare: user.canCare,
        canExamine: user.canExamine,
        canFinance: user.canFinance,
      ),
      InventoryPage(
        repository: repository,
        admin: user.isAdmin,
        canOperate: user.canOperate,
      ),
      ProfilePage(auth: widget.auth),
      if (user.isAdmin)
        UsersPage(
          api: widget.auth.repository.api,
          onProfileChanged: widget.auth.refresh,
        ),
      CatalogPage(
        repository: repository,
        admin: user.isAdmin,
        initialKind: 'species',
      ),
      if (user.canFinance)
        FinancePage(repository: repository, admin: user.isAdmin),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final desktop = c.maxWidth >= 1000;
        Widget navigation() => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Brand(),
            const SizedBox(height: 24),
            for (var i = 0; i < labels.length; i++)
              Material(
                color: Colors.transparent,
                child: ListTile(
                  selected: selectedIndex == i,
                  selectedTileColor: const Color(0xFFE7F3ED),
                  leading: Icon(icons[i]),
                  title: Text(labels[i]),
                  onTap: () {
                    if (!desktop) Navigator.pop(context);
                    navigate(i);
                  },
                ),
              ),
            const Divider(),
            if (user.isAdmin)
              TextButton.icon(
                onPressed: () {
                  if (!desktop) Navigator.pop(context);
                  navigate(labels.indexOf('Trang trại'));
                },
                icon: const Icon(Icons.tune),
                label: const Text('Thêm loài'),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: canvas,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  UserAvatar(user: user, radius: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          user.roleLabel,
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: widget.auth.busy ? null : widget.auth.logout,
              icon: const Icon(Icons.logout),
              label: const Text('Đăng xuất'),
            ),
          ],
        );
        return Scaffold(
          appBar: desktop
              ? null
              : AppBar(
                  title: Text(labels[selectedIndex]),
                  actions: [
                    if (user.isAdmin)
                      IconButton(
                        tooltip: 'Thêm loài đang nuôi',
                        onPressed: () => navigate(labels.indexOf('Trang trại')),
                        icon: const Icon(Icons.tune),
                      ),
                  ],
                ),
          drawer: desktop ? null : Drawer(child: SafeArea(child: navigation())),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: bottomItems.contains(selectedIndex)
                      ? bottomItems.indexOf(selectedIndex)
                      : 4,
                  onDestinationSelected: (i) => navigate(bottomItems[i]),
                  destinations: [
                    for (final i in bottomItems)
                      NavigationDestination(
                        icon: Icon(icons[i]),
                        label: labels[i],
                      ),
                  ],
                ),
          body: SafeArea(
            child: Row(
              children: [
                if (desktop)
                  Container(
                    width: 264,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(right: BorderSide(color: line)),
                    ),
                    child: navigation(),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      if (desktop)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Trang trại / ${labels[selectedIndex]}',
                                ),
                              ),
                              if (user.isAdmin)
                                TextButton.icon(
                                  onPressed: () =>
                                      navigate(labels.indexOf('Trang trại')),
                                  icon: const Icon(Icons.tune),
                                  label: const Text('Thêm loài'),
                                ),
                            ],
                          ),
                        ),
                      if (widget.auth.error != null)
                        FeedbackBox(widget.auth.error!),
                      Expanded(
                        child: KeyedSubtree(
                          key: ValueKey(
                            '$selectedIndex-${repository.selectedSpeciesIds.join()}',
                          ),
                          child: pages[selectedIndex],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
