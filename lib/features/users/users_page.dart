import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/photo_view.dart';
import '../../core/suggested_code_field.dart';
import '../../core/theme.dart';
import '../auth/auth_repository.dart';
import 'users_controller.dart';
import '../auth/user_avatar.dart';

class UsersPage extends StatefulWidget {
  final ApiClient api;
  final Future<void> Function()? onProfileChanged;
  const UsersPage({super.key, required this.api, this.onProfileChanged});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late final UsersController controller;
  @override
  void initState() {
    super.initState();
    controller = UsersController(widget.api);
    controller.load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> editUser(FarmUser user) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateStaffDialog(controller: controller, user: user),
    );
    if (changed == true) await widget.onProfileChanged?.call();
  }

  Future<void> toggle(FarmUser user) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.active ? 'Khóa tài khoản?' : 'Mở khóa tài khoản?'),
        content: Text(
          user.active
              ? '${user.name} sẽ bị đăng xuất và không thể truy cập trang trại cho đến khi được mở khóa.'
              : '${user.name} sẽ có thể đăng nhập trở lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      await controller.setActive(user, !user.active);
    }
  }

  Future<void> deleteUser(FarmUser user) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xóa tài khoản ${user.name}?'),
        content: Text(
          'Tài khoản ${user.email} sẽ bị xóa khỏi danh sách nhân sự và không thể đăng nhập. Lịch sử chăm sóc, kho và thu chi của nhân viên vẫn được giữ lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa tài khoản'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      final removed = await controller.deleteUser(user);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              removed
                  ? 'Đã xóa nhân viên ${user.name}.'
                  : controller.error ?? 'Chưa xóa được nhân viên.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => SingleChildScrollView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nhân sự trang trại',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Cấp quyền làm việc và quản lý tài khoản của đội ngũ.',
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: controller.saving || controller.loading
                        ? null
                        : () => showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) =>
                                _CreateStaffDialog(controller: controller),
                          ),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Thêm nhân sự'),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.loading ? null : controller.load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Làm mới'),
                  ),
                  Text('${controller.total} tài khoản'),
                ],
              ),
              const SizedBox(height: 24),
              if (controller.error != null) ...[
                FeedbackBox(controller.error!),
                const SizedBox(height: 16),
              ],
              if (controller.loading)
                const LinearProgressIndicator(
                  semanticsLabel: 'Đang tải danh sách nhân viên',
                ),
              if (!controller.loading &&
                  controller.users.isEmpty &&
                  controller.error == null)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Text('Chưa có tài khoản nào.'),
                  ),
                ),
              ...controller.users.map(
                (user) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final details = Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              UserAvatar(user: user),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.name,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: ink,
                                      ),
                                    ),
                                    Text(user.email),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        if (user.code != null)
                                          _Badge(user.code!, false),
                                        _Badge(user.roleLabel, false),
                                        _Badge(
                                          user.active
                                              ? 'Đang hoạt động'
                                              : 'Đã khóa',
                                          !user.active,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                          final action = Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed:
                                    controller.saving || controller.loading
                                    ? null
                                    : () => editUser(user),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: const Text('Chỉnh sửa'),
                              ),
                              if (user.isAdmin)
                                const Text('Tài khoản quản trị'),
                              if (!user.isAdmin)
                                OutlinedButton.icon(
                                  onPressed:
                                      controller.saving || controller.loading
                                      ? null
                                      : () => toggle(user),
                                  icon: Icon(
                                    user.active
                                        ? Icons.lock_outline
                                        : Icons.lock_open,
                                    size: 18,
                                  ),
                                  label: Text(user.active ? 'Khóa' : 'Mở khóa'),
                                ),
                              if (!user.isAdmin)
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFC62828),
                                    side: const BorderSide(
                                      color: Color(0xFFEF9A9A),
                                    ),
                                  ),
                                  onPressed:
                                      controller.saving || controller.loading
                                      ? null
                                      : () => deleteUser(user),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  label: const Text('Xóa'),
                                ),
                            ],
                          );
                          return constraints.maxWidth < 700
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    details,
                                    const SizedBox(height: 16),
                                    action,
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(child: details),
                                    const SizedBox(width: 16),
                                    action,
                                  ],
                                );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Trang trước',
                    onPressed: controller.page > 1 && !controller.loading
                        ? () => controller.load(targetPage: controller.page - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Trang ${controller.page}'),
                  IconButton(
                    tooltip: 'Trang sau',
                    onPressed:
                        controller.page * 20 < controller.total &&
                            !controller.loading
                        ? () => controller.load(targetPage: controller.page + 1)
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

class _Badge extends StatelessWidget {
  final String label;
  final bool warning;
  const _Badge(this.label, this.warning);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: warning ? const Color(0xFFFFE9D7) : const Color(0xFFEAF1E5),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        color: warning ? const Color(0xFF85431C) : forest,
      ),
    ),
  );
}

class _CreateStaffDialog extends StatefulWidget {
  final UsersController controller;
  final FarmUser? user;
  const _CreateStaffDialog({required this.controller, this.user});
  @override
  State<_CreateStaffDialog> createState() => _CreateStaffDialogState();
}

class _CreateStaffDialogState extends State<_CreateStaffDialog> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.user?.name ?? '');
  late final code = TextEditingController(text: widget.user?.code ?? '');
  late final email = TextEditingController(text: widget.user?.email ?? '');
  final password = TextEditingController();
  bool hidden = true;
  late String role = widget.user?.role ?? 'STAFF';
  late String? avatar = widget.user?.avatarData;
  String? photoBase64;
  bool avatarChanged = false, pickingPhoto = false;
  @override
  void dispose() {
    name.dispose();
    code.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> chooseAvatar() async {
    setState(() => pickingPhoto = true);
    try {
      final photo = await pickUserAvatar();
      if (photo != null && mounted) {
        setState(() {
          photoBase64 = photo;
          avatar = photo;
          avatarChanged = true;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không mở được ảnh. Hãy chọn lại.')),
        );
      }
    } finally {
      if (mounted) setState(() => pickingPhoto = false);
    }
  }

  Future<void> submit() async {
    if (pickingPhoto || !form.currentState!.validate()) return;
    final user = widget.user;
    final success = user == null
        ? await widget.controller.create(
            name.text,
            email.text,
            password.text,
            role: role,
            code: code.text,
          )
        : await widget.controller.updateUser(user, {
            'name': name.text.trim(),
            'email': email.text.trim(),
            'role': role,
            if (code.text.trim().isNotEmpty) 'code': code.text.trim(),
            if (avatarChanged) 'photoBase64': photoBase64,
          });
    if (success && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => PopScope(
      canPop: !widget.controller.saving,
      child: AlertDialog(
        title: Text(widget.user == null ? 'Thêm nhân sự' : 'Chỉnh sửa nhân sự'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.user == null)
                    const Text(
                      'Chọn vai trò phù hợp với công việc. Hãy chuyển thông tin đăng nhập trực tiếp cho người sử dụng.',
                    ),
                  const SizedBox(height: 20),
                  if (widget.user?.isAdmin != true)
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: const InputDecoration(labelText: 'Vai trò'),
                      items: const [
                        DropdownMenuItem(
                          value: 'STAFF',
                          child: Text('Nhân viên'),
                        ),
                        DropdownMenuItem(
                          value: 'VET',
                          child: Text('Bác sĩ thú y'),
                        ),
                        DropdownMenuItem(
                          value: 'ACCOUNTANT',
                          child: Text('Kế toán'),
                        ),
                      ],
                      onChanged: widget.controller.saving
                          ? null
                          : (value) => setState(() => role = value!),
                    ),
                  const SizedBox(height: 18),
                  if (widget.controller.error != null) ...[
                    FeedbackBox(widget.controller.error!),
                    const SizedBox(height: 16),
                  ],
                  if (widget.user != null) ...[
                    PhotoView(
                      data: avatar ?? '',
                      size: 80,
                      fallback: Icons.person_outline,
                      label: 'Ảnh nhân sự',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: pickingPhoto || widget.controller.saving
                              ? null
                              : chooseAvatar,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(
                            pickingPhoto ? 'Đang xử lý ảnh…' : 'Chọn ảnh',
                          ),
                        ),
                        if (avatar != null)
                          TextButton(
                            onPressed: pickingPhoto || widget.controller.saving
                                ? null
                                : () => setState(() {
                                    avatar = null;
                                    photoBase64 = null;
                                    avatarChanged = true;
                                  }),
                            child: const Text('Bỏ ảnh'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  SuggestedCodeField(
                    api: widget.controller.api,
                    controller: code,
                    kind: 'users',
                    name: '',
                    label: 'Mã nhân sự',
                    suggestInitially: widget.user == null,
                    enabled: !widget.controller.saving,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: name,
                    enabled: !widget.controller.saving,
                    decoration: const InputDecoration(labelText: 'Họ và tên'),
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        v == null ||
                            v.trim().length < 2 ||
                            v.trim().length > 100
                        ? 'Tên cần từ 2 đến 100 ký tự.'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: email,
                    enabled: !widget.controller.saving,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        v == null ||
                            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(v.trim())
                        ? 'Nhập email hợp lệ.'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  if (widget.user == null)
                    TextFormField(
                      controller: password,
                      enabled: !widget.controller.saving,
                      obscureText: hidden,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu ban đầu',
                        helperText: 'Từ 12 đến 128 ký tự',
                        suffixIcon: IconButton(
                          tooltip: hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                          onPressed: () => setState(() => hidden = !hidden),
                          icon: Icon(
                            hidden
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.length < 12 || v.length > 128
                          ? 'Mật khẩu cần từ 12 đến 128 ký tự.'
                          : null,
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: widget.controller.saving
                ? null
                : () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: widget.controller.saving || pickingPhoto ? null : submit,
            child: Text(
              widget.controller.saving
                  ? 'Đang lưu…'
                  : widget.user == null
                  ? 'Tạo tài khoản'
                  : 'Lưu thay đổi',
            ),
          ),
        ],
      ),
    ),
  );
}
