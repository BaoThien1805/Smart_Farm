import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import '../auth/auth_repository.dart';
import '../auth/user_avatar.dart';
import 'personnel_confirmation.dart';
import 'personnel_form.dart';
import 'users_controller.dart';

class UsersPage extends StatefulWidget {
  final ApiClient api;
  final bool canManage;
  final Future<void> Function()? onProfileChanged;
  const UsersPage({
    super.key,
    required this.api,
    this.canManage = true,
    this.onProfileChanged,
  });
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late final UsersController controller;
  bool interacting = false;
  bool get locked => interacting || controller.loading || controller.saving;
  bool get canWrite =>
      widget.canManage && !locked && controller.loadError == null;
  @override
  void initState() {
    super.initState();
    controller = UsersController(widget.api, canManage: widget.canManage);
    controller.load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> edit([FarmUser? user]) async {
    if (!canWrite) return;
    setState(() => interacting = true);
    try {
      final changed = await showPersonnelForm(context, controller, user: user);
      if (changed && mounted) {
        if (user != null) await widget.onProfileChanged?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                user == null
                    ? 'Đã tạo tài khoản nhân sự.'
                    : 'Đã lưu thay đổi nhân sự.',
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => interacting = false);
    }
  }

  Future<void> confirm(FarmUser user, {bool deleting = false}) async {
    if (!canWrite || user.isAdmin) return;
    setState(() => interacting = true);
    try {
      if (await confirmPersonnelAction(
            context,
            controller,
            user,
            deleting: deleting,
          ) &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              deleting
                  ? 'Đã xóa nhân viên ${user.name} khỏi danh sách.'
                  : user.active
                  ? 'Đã khóa tài khoản ${user.name}.'
                  : 'Đã mở khóa tài khoản ${user.name}.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => interacting = false);
    }
  }

  Widget userCard(FarmUser user) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: FarmInfoCard(
      key: ValueKey('personnel-${user.id}'),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(user: user, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Mã nhân sự: ${user.code?.isNotEmpty == true ? user.code : 'Chưa có mã'}',
                      style: const TextStyle(color: muted),
                    ),
                    Text(user.email),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: ValueKey('personnel-menu-${user.id}'),
                tooltip: 'Thao tác nhân sự',
                enabled: canWrite,
                onSelected: (action) {
                  if (action == 'edit') {
                    edit(user);
                  } else {
                    confirm(user, deleting: action == 'delete');
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                  if (!user.isAdmin) ...[
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(user.active ? 'Khóa' : 'Mở khóa'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Xóa')),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FarmStatusBadge(
                label: user.roleLabel,
                tone: switch (user.role) {
                  'ADMIN' => FarmBadgeTone.info,
                  'VET' => FarmBadgeTone.lavender,
                  'ACCOUNTANT' => FarmBadgeTone.peach,
                  _ => FarmBadgeTone.success,
                },
              ),
              FarmStatusBadge(
                label: user.active ? 'Đang hoạt động' : 'Đã khóa',
                tone: user.active
                    ? FarmBadgeTone.success
                    : FarmBadgeTone.neutral,
              ),
            ],
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!widget.canManage) {
      return const Center(child: Text('Bạn không có quyền quản lý nhân sự.'));
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => SingleChildScrollView(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FarmSectionHeader(
                  title: 'Nhân sự trang trại',
                  pageTitle: true,
                  subtitle:
                      'Cấp quyền làm việc và quản lý tài khoản của đội ngũ.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: canWrite ? () => edit() : null,
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Thêm nhân sự'),
                    ),
                    OutlinedButton.icon(
                      onPressed: locked
                          ? null
                          : () {
                              controller.clearError();
                              controller.load();
                            },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Làm mới'),
                    ),
                    Text('${controller.total} tài khoản'),
                  ],
                ),
                const SizedBox(height: 24),
                if (controller.loading)
                  const FarmLoadingState(
                    message: 'Đang tải danh sách nhân viên',
                  ),
                if (controller.loadError != null) ...[
                  FarmLoadError(
                    message: controller.loadError!,
                    onRetry: locked ? null : () => controller.load(),
                  ),
                  const SizedBox(height: 12),
                  if (controller.users.isNotEmpty)
                    const Text(
                      'Đang hiển thị danh sách từ lần tải trước. Tải lại thành công để tiếp tục chỉnh sửa.',
                      style: TextStyle(color: muted),
                    ),
                  const SizedBox(height: 16),
                ],
                if (!controller.loading &&
                    controller.loadError == null &&
                    controller.users.isEmpty)
                  const FarmEmptyState(
                    icon: Icons.people_outline,
                    message: 'Chưa có tài khoản nào.',
                    description: 'Dùng nút Thêm nhân sự để cấp tài khoản làm việc trong trang trại.',
                  ),
                LayoutBuilder(
                  builder: (context, c) {
                    final columns = c.maxWidth >= 900 ? 2 : 1;
                    return Wrap(
                      spacing: 12,
                      children: [
                        for (final user in controller.users)
                          SizedBox(
                            width: (c.maxWidth - (columns - 1) * 12) / columns,
                            child: userCard(user),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Trang ${controller.page}'),
                    IconButton(
                      tooltip: 'Trang trước',
                      onPressed: !locked && controller.page > 1
                          ? () =>
                                controller.load(targetPage: controller.page - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      tooltip: 'Trang sau',
                      onPressed:
                          !locked && controller.page * 20 < controller.total
                          ? () =>
                                controller.load(targetPage: controller.page + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
