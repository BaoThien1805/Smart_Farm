import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/photo_view.dart';
import '../../core/suggested_code_field.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import '../auth/auth_repository.dart';
import '../auth/user_avatar.dart';
import 'users_controller.dart';

Future<bool> showPersonnelForm(
  BuildContext context,
  UsersController controller, {
  FarmUser? user,
}) async {
  if (!controller.canManage ||
      controller.saving ||
      controller.loading ||
      controller.loadError != null) {
    return false;
  }
  controller.clearError();
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PersonnelForm(controller: controller, user: user),
      ) ??
      false;
}

class PersonnelForm extends StatefulWidget {
  const PersonnelForm({super.key, required this.controller, this.user});
  final UsersController controller;
  final FarmUser? user;
  @override
  State<PersonnelForm> createState() => _PersonnelFormState();
}

class _PersonnelFormState extends State<PersonnelForm> {
  final form = GlobalKey<FormState>(), errorAnchor = GlobalKey();
  late final name = TextEditingController(text: widget.user?.name ?? '');
  late final code = TextEditingController(text: widget.user?.code ?? '');
  late final email = TextEditingController(text: widget.user?.email ?? '');
  final password = TextEditingController();
  late String role = widget.user?.role ?? 'STAFF';
  late String? avatar = widget.user?.avatarData;
  String? photoBase64;
  bool avatarChanged = false, pickingPhoto = false, hidden = true;
  bool submitting = false;
  bool get busy => widget.controller.saving || submitting || pickingPhoto;

  @override
  void dispose() {
    for (final c in [name, code, email, password]) {
      c.dispose();
    }
    super.dispose();
  }

  void revealError() => WidgetsBinding.instance.addPostFrameCallback((_) {
    final target = errorAnchor.currentContext;
    if (mounted && target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 200),
      );
    }
  });

  Future<void> chooseAvatar() async {
    if (busy) return;
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
        widget.controller.error = e.message;
        widget.controller.changed();
        revealError();
      }
    } catch (_) {
      if (mounted) {
        widget.controller.error = 'Không mở được ảnh. Hãy chọn lại.';
        widget.controller.changed();
        revealError();
      }
    } finally {
      if (mounted) setState(() => pickingPhoto = false);
    }
  }

  Future<void> submit() async {
    if (busy || !widget.controller.canManage) return;
    final invalid = form.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(
            invalid.first.context,
            duration: const Duration(milliseconds: 200),
          );
        }
      });
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => submitting = true);
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
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() => submitting = false);
      revealError();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => PopScope(
      canPop: !busy,
      child: FarmFormLayout(
        title: widget.user == null ? 'Thêm nhân sự' : 'Chỉnh sửa nhân sự',
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: busy ? null : submit,
            child: FarmSubmitLabel(
              busy: widget.controller.saving || submitting,
              label: widget.user == null ? 'Tạo tài khoản' : 'Lưu thay đổi',
            ),
          ),
        ],
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.controller.error != null) ...[
                FeedbackBox(widget.controller.error!, key: errorAnchor),
                const SizedBox(height: 20),
              ],
              if (widget.user == null) ...[
                const Text(
                  'Tạo tài khoản làm việc cho trang trại. Hãy chuyển thông tin đăng nhập trực tiếp cho người sử dụng.',
                  style: TextStyle(color: muted),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Có thể thêm ảnh đại diện bằng Chỉnh sửa sau khi tạo.',
                  style: TextStyle(color: muted),
                ),
              ] else ...[
                Center(
                  child: PhotoView(
                    data: avatar ?? '',
                    size: 96,
                    fallback: Icons.person_outline,
                    label: 'Ảnh nhân sự ${widget.user!.name}',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: busy ? null : chooseAvatar,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        pickingPhoto ? 'Đang xử lý ảnh…' : 'Chọn ảnh',
                      ),
                    ),
                    if (avatar != null && avatar!.isNotEmpty)
                      TextButton(
                        onPressed: busy
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
              ],
              const SizedBox(height: 24),
              const FarmSectionHeader(title: 'Thông tin nhân sự'),
              const SizedBox(height: 16),
              SuggestedCodeField(
                api: widget.controller.api,
                controller: code,
                kind: 'users',
                name: '',
                label: 'Mã nhân sự',
                suggestInitially: widget.user == null,
                enabled: !busy,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: name,
                enabled: !busy,
                decoration: farmInputDecoration(label: 'Họ và tên'),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    v == null || v.trim().length < 2 || v.trim().length > 100
                    ? 'Tên cần từ 2 đến 100 ký tự.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: email,
                enabled: !busy,
                decoration: farmInputDecoration(label: 'Email'),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    v == null ||
                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(v.trim())
                    ? 'Nhập email hợp lệ.'
                    : null,
              ),
              const SizedBox(height: 24),
              const FarmSectionHeader(title: 'Quyền làm việc'),
              const SizedBox(height: 16),
              if (widget.user?.isAdmin == true) ...[
                const FarmStatusBadge(
                  label: 'Quản trị viên',
                  tone: FarmBadgeTone.info,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Vai trò tài khoản chủ được bảo vệ. Có thể cập nhật thông tin và ảnh đại diện.',
                  style: TextStyle(color: muted),
                ),
              ] else ...[
                DropdownButtonFormField<String>(
                  initialValue: role,
                  isExpanded: true,
                  decoration: farmInputDecoration(label: 'Vai trò'),
                  items: const [
                    DropdownMenuItem(value: 'STAFF', child: Text('Nhân viên')),
                    DropdownMenuItem(value: 'VET', child: Text('Bác sĩ thú y')),
                    DropdownMenuItem(
                      value: 'ACCOUNTANT',
                      child: Text('Kế toán'),
                    ),
                  ],
                  onChanged: busy ? null : (v) => setState(() => role = v!),
                ),
                if (widget.user != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Khi đổi vai trò, các phiên đăng nhập hiện tại của nhân sự sẽ bị thu hồi.',
                    style: TextStyle(color: muted),
                  ),
                ],
              ],
              if (widget.user == null) ...[
                const SizedBox(height: 24),
                TextFormField(
                  controller: password,
                  enabled: !busy,
                  obscureText: hidden,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: farmInputDecoration(
                    label: 'Mật khẩu ban đầu',
                    helperText: 'Từ 12 đến 128 ký tự',
                    suffixIcon: IconButton(
                      tooltip: hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                      onPressed: busy
                          ? null
                          : () => setState(() => hidden = !hidden),
                      icon: Icon(
                        hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (v) => v == null || v.length < 12 || v.length > 128
                      ? 'Mật khẩu cần từ 12 đến 128 ký tự.'
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
