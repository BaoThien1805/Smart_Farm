import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../auth/user_avatar.dart';
import '../../core/api_client.dart';

class ProfilePage extends StatefulWidget {
  final AuthController auth;
  const ProfilePage({super.key, required this.auth});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool updatingAvatar = false;
  Future<void> changeAvatar({bool remove = false}) async {
    if (updatingAvatar || !widget.auth.user!.isAdmin) return;
    setState(() => updatingAvatar = true);
    try {
      final image = remove ? null : await pickUserAvatar();
      if (!remove && image == null) return;
      await widget.auth.repository.api.request(
        'PATCH',
        '/users/${widget.auth.user!.id}/avatar',
        body: {'photoBase64': image},
      );
      await widget.auth.refresh();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể cập nhật ảnh đại diện. Hãy thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => updatingAvatar = false);
    }
  }

  final form = GlobalKey<FormState>();
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user!;
    return SingleChildScrollView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tài khoản của tôi',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text('Thông tin cá nhân và bảo mật đăng nhập.'),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(
                    MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserAvatar(user: user, radius: 32),
                      if (user.isAdmin)
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: updatingAvatar ? null : changeAvatar,
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                              ),
                              label: const Text('Đổi ảnh đại diện'),
                            ),
                            if (user.avatarData != null)
                              TextButton(
                                onPressed: updatingAvatar
                                    ? null
                                    : () => changeAvatar(remove: true),
                                child: const Text('Xóa ảnh đại diện'),
                              ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      Text(
                        user.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(user.email),
                      const SizedBox(height: 12),
                      Chip(
                        label: Text(user.roleLabel),
                        avatar: const Icon(
                          Icons.verified_user_outlined,
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: widget.auth.busy
                            ? null
                            : widget.auth.refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Làm mới thông tin'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(
                    MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                  ),
                  child: Form(
                    key: form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đổi mật khẩu',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Dùng ít nhất 12 ký tự. Sau khi đổi, bạn sẽ đăng nhập lại trên các thiết bị.',
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: current,
                          obscureText: true,
                          enabled: !widget.auth.busy,
                          autofillHints: const [AutofillHints.password],
                          decoration: const InputDecoration(
                            labelText: 'Mật khẩu hiện tại',
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Nhập mật khẩu hiện tại.'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: next,
                          obscureText: true,
                          enabled: !widget.auth.busy,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: const InputDecoration(
                            labelText: 'Mật khẩu mới',
                          ),
                          validator: (v) =>
                              v == null || v.length < 12 || v.length > 128
                              ? 'Mật khẩu cần từ 12 đến 128 ký tự.'
                              : v == current.text
                              ? 'Mật khẩu mới phải khác mật khẩu hiện tại.'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: confirm,
                          obscureText: true,
                          enabled: !widget.auth.busy,
                          decoration: const InputDecoration(
                            labelText: 'Nhập lại mật khẩu mới',
                          ),
                          validator: (v) => v != next.text
                              ? 'Mật khẩu nhập lại không khớp.'
                              : null,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: widget.auth.busy
                              ? null
                              : () {
                                  if (form.currentState!.validate()) {
                                    widget.auth.changePassword(
                                      current.text,
                                      next.text,
                                    );
                                  }
                                },
                          icon: const Icon(Icons.lock_reset),
                          label: Text(
                            widget.auth.busy
                                ? 'Đang xử lý…'
                                : 'Cập nhật mật khẩu',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: widget.auth.busy ? null : widget.auth.logout,
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
