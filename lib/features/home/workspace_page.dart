import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/ui_components.dart';
import '../../core/api_client.dart';
import '../auth/auth_controller.dart';
import '../auth/user_avatar.dart';
import '../users/users_page.dart';
import '../farm/farm_pages.dart';
import '../farm/farm_repository.dart';
import '../farm/inventory_page.dart';
import '../farm/finance_page.dart';
import '../farm/species_chooser.dart';
import '../farm/farm_location_page.dart';
import '../farm/animal_scanner_page.dart';
import 'more_page.dart';
import 'profile_page.dart';
import 'workspace_destination.dart';

class WorkspacePage extends StatefulWidget {
  final AuthController auth;
  const WorkspacePage({super.key, required this.auth});
  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  late WorkspaceDestination selected = WorkspaceDestination.initialFor(
    widget.auth.user!,
  );
  late final visited = <WorkspaceDestination>{selected};
  bool ready = false, checkingSetup = true;
  int locationRevision = 0;
  int overviewRevision = 0;
  int careRevision = 0;
  final pageRevisions = <WorkspaceDestination, int>{};
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

  void navigate(WorkspaceDestination destination) {
    if (!destination.allowedFor(widget.auth.user!)) return;
    setState(() {
      if (selected != destination) {
        pageRevisions.update(
          destination,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      if (destination == WorkspaceDestination.care && selected != destination) {
        careRevision++;
      }
      if (destination == WorkspaceDestination.overview &&
          selected != destination) {
        overviewRevision++;
      }
      selected = destination;
      visited.add(destination);
    });
  }

  Future<void> scanQr() async {
    final user = widget.auth.user!;
    await openAnimalQrScanner(
      context,
      detailBuilder: (id) => AnimalDetailPage(
        repository: repository,
        admin: user.isAdmin,
        id: id,
        canOperate: user.canOperate,
        canCare: user.canCare,
        canExamine: user.canExamine,
        canFinance: user.canFinance,
      ),
    );
  }

  Widget page(WorkspaceDestination destination) {
    final user = widget.auth.user!;
    return switch (destination) {
      WorkspaceDestination.overview => FarmDashboard(
        repository: repository,
        userName: user.name,
        onAnimals: () => navigate(WorkspaceDestination.animals),
        onCare: () => navigate(WorkspaceDestination.care),
        onStock: () => navigate(WorkspaceDestination.inventory),
        onPens: () => navigate(WorkspaceDestination.pens),
        locationRevision: locationRevision,
        refreshRevision: overviewRevision,
        onLocationChanged: () => setState(() => locationRevision++),
        admin: user.isAdmin,
        financeAccess: user.canFinance,
        onFinance: user.canFinance
            ? () => navigate(WorkspaceDestination.finance)
            : null,
      ),
      WorkspaceDestination.pens => CatalogPage(
        refreshRevision: pageRevisions[destination] ?? 0,
        repository: repository,
        admin: user.isAdmin,
        canOperate: user.canOperate,
        canCare: user.canCare,
        canExamine: user.canExamine,
        canFinance: user.canFinance,
        availableKinds: const ['pens'],
      ),
      WorkspaceDestination.animals => AnimalsPage(
        refreshRevision: pageRevisions[destination] ?? 0,
        repository: repository,
        admin: user.isAdmin,
        canOperate: user.canOperate,
        canCare: user.canCare,
        canExamine: user.canExamine,
        canFinance: user.canFinance,
      ),
      WorkspaceDestination.care => CarePage(
        repository: repository,
        refreshRevision: careRevision,
        admin: user.isAdmin,
        canOperate: user.canOperate,
        canCare: user.canCare,
        canExamine: user.canExamine,
        canFinance: user.canFinance,
      ),
      WorkspaceDestination.more => MorePage(
        auth: widget.auth,
        onOpen: navigate,
        onScanQr: scanQr,
      ),
      WorkspaceDestination.inventory => InventoryPage(
        refreshRevision: pageRevisions[destination] ?? 0,
        repository: repository,
        admin: user.isAdmin,
        canOperate: user.canOperate,
      ),
      WorkspaceDestination.finance => FinancePage(
        refreshRevision: pageRevisions[destination] ?? 0,
        repository: repository,
        admin: user.isAdmin,
        canFinance: user.canFinance,
      ),
      WorkspaceDestination.users => UsersPage(
        api: widget.auth.repository.api,
        canManage: user.isAdmin,
        onProfileChanged: widget.auth.refresh,
      ),
      WorkspaceDestination.catalog => CatalogPage(
        refreshRevision: pageRevisions[destination] ?? 0,
        repository: repository,
        admin: user.isAdmin,
        canOperate: user.canOperate,
        canCare: user.canCare,
        canExamine: user.canExamine,
        canFinance: user.canFinance,
        initialKind: 'species',
        availableKinds: const ['species', 'breeds', 'areas'],
      ),
      WorkspaceDestination.profile => ProfilePage(auth: widget.auth),
      WorkspaceDestination.location => FarmLocationPage(
        key: ValueKey(locationRevision),
        repository: repository,
        admin: user.isAdmin,
        onLocationChanged: () => setState(() => locationRevision++),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user!;
    if (checkingSetup || setupError != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: checkingSetup
                ? const CircularProgressIndicator()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
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
    final destinations = WorkspaceDestination.values
        .where((destination) => destination.allowedFor(user))
        .toList();
    if (!selected.allowedFor(user)) {
      selected = WorkspaceDestination.initialFor(user);
      visited.add(selected);
    }

    Widget backToMore() => IconButton(
      key: const ValueKey('workspace-back'),
      tooltip: 'Quay lại Thêm',
      onPressed: () => navigate(WorkspaceDestination.more),
      icon: const Icon(Icons.arrow_back),
    );

    return PopScope<Object?>(
      canPop: !selected.isSecondary,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selected.isSecondary) {
          navigate(WorkspaceDestination.more);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 1000;
          return Scaffold(
            appBar: desktop || selected != WorkspaceDestination.more
                ? null
                : AppBar(
                    leading: selected.isSecondary ? backToMore() : null,
                    title: Text(selected.label),
                    actions: [
                      if (user.isAdmin)
                        IconButton(
                          tooltip: 'Thêm loài đang nuôi',
                          onPressed: () =>
                              navigate(WorkspaceDestination.catalog),
                          icon: const Icon(Icons.tune),
                        ),
                    ],
                  ),
            bottomNavigationBar: desktop
                ? null
                : DefaultTextStyle.merge(
                    textAlign: TextAlign.center,
                    child: NavigationBar(
                      labelPadding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                      selectedIndex: WorkspaceDestination.primary.indexOf(
                        selected.primaryDestination,
                      ),
                      onDestinationSelected: (index) =>
                          navigate(WorkspaceDestination.primary[index]),
                      destinations: [
                        for (final destination in WorkspaceDestination.primary)
                          NavigationDestination(
                            key: ValueKey('tab-${destination.name}'),
                            icon: Icon(destination.icon),
                            selectedIcon: Icon(destination.selectedIcon),
                            label: destination.label,
                          ),
                      ],
                    ),
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
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const Brand(),
                          const SizedBox(height: 24),
                          for (final destination in destinations)
                            Material(
                              color: Colors.transparent,
                              child: ListTile(
                                key: ValueKey('nav-${destination.name}'),
                                selected: destination == selected,
                                leading: Icon(destination.icon),
                                title: Text(destination.label),
                                onTap: () => navigate(destination),
                              ),
                            ),
                          const Divider(),
                          Material(
                            color: Colors.transparent,
                            child: ListTile(
                              leading: UserAvatar(user: user, radius: 20),
                              title: Text(user.name),
                              subtitle: Text(user.roleLabel),
                              onTap: () =>
                                  navigate(WorkspaceDestination.profile),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: widget.auth.busy
                                ? null
                                : widget.auth.logout,
                            icon: const Icon(Icons.logout),
                            label: const Text('Đăng xuất'),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    key: const ValueKey('workspace-content'),
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
                                if (selected.isSecondary) backToMore(),
                                Expanded(
                                  child: Text('Trang trại / ${selected.label}'),
                                ),
                                if (user.isAdmin)
                                  TextButton.icon(
                                    onPressed: () =>
                                        navigate(WorkspaceDestination.catalog),
                                    icon: const Icon(Icons.tune),
                                    label: const Text('Thêm loài'),
                                  ),
                              ],
                            ),
                          ),
                        if (widget.auth.error != null &&
                            selected != WorkspaceDestination.profile)
                          FeedbackBox(widget.auth.error!),
                        Expanded(
                          key: const ValueKey('workspace-pages'),
                          // Lazy activation avoids requesting every page on login.
                          // Keeping visited children also keeps inline drafts and
                          // filters when switching tabs or resizing the shell.
                          child: IndexedStack(
                            index: destinations.indexOf(selected),
                            children: [
                              for (final destination in destinations)
                                KeyedSubtree(
                                  key: ValueKey(destination),
                                  child: visited.contains(destination)
                                      ? TickerMode(
                                          enabled: destination == selected,
                                          child: FarmPageNavigation(
                                            onBack:
                                                !desktop &&
                                                    destination.isSecondary
                                                ? () => navigate(
                                                    WorkspaceDestination.more,
                                                  )
                                                : null,
                                            child: page(destination),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
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
          );
        },
      ),
    );
  }
}
