import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/ui_components.dart';
import '../auth/auth_repository.dart';
import '../auth/user_avatar.dart';
import 'users_controller.dart';

Future<bool> confirmPersonnelAction(
  BuildContext context,
  UsersController controller,
  FarmUser user, {
  bool deleting = false,
}) async {
  if (!controller.canManage ||
      user.isAdmin ||
      controller.saving ||
      controller.loading ||
      controller.loadError != null) {
    return false;
  }
  controller.clearError();
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PersonnelConfirmation(
          controller: controller,
          user: user,
          deleting: deleting,
        ),
      ) ??
      false;
}

class PersonnelConfirmation extends StatefulWidget {
  const PersonnelConfirmation({
    super.key,
    required this.controller,
    required this.user,
    this.deleting = false,
  });
  final UsersController controller;
  final FarmUser user;
  final bool deleting;
  @override
  State<PersonnelConfirmation> createState() => _PersonnelConfirmationState();
}

class _PersonnelConfirmationState extends State<PersonnelConfirmation> {
  bool submitting = false;
  final errorAnchor = GlobalKey();
  bool get busy => submitting || widget.controller.saving;
  String get action => widget.deleting
      ? 'Xóa tài khoản'
      : widget.user.active
      ? 'Khóa tài khoản'
      : 'Mở khóa';
  Future<void> submit() async {
    if (busy || !widget.controller.canManage || widget.user.isAdmin) return;
    setState(() => submitting = true);
    final success = widget.deleting
        ? await widget.controller.deleteUser(widget.user)
        : await widget.controller.setActive(widget.user, !widget.user.active);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() => submitting = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = errorAnchor.currentContext;
        if (mounted && target != null) {
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 200),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => PopScope(
      canPop: !busy,
      child: AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.all(20),
        title: Text('$action?'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.deleting
                        ? FarmColors.dangerSurface
                        : widget.user.active
                        ? FarmColors.amber
                        : FarmColors.mint,
                  ),
                  child: Icon(
                    widget.deleting
                        ? Icons.delete_outline
                        : widget.user.active
                        ? Icons.lock_outline
                        : Icons.lock_open,
                    size: 40,
                    color: widget.deleting ? FarmColors.danger : forest,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserAvatar(user: widget.user, radius: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(widget.user.email),
                        if (widget.user.code != null) Text(widget.user.code!),
                        Text(widget.user.roleLabel),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                widget.deleting
                    ? 'Tài khoản sẽ rời danh sách nhân sự, không thể đăng nhập và các phiên đăng nhập hiện tại bị thu hồi.'
                    : widget.user.active
                    ? 'Nhân sự sẽ bị đăng xuất và không thể truy cập trang trại cho đến khi được mở khóa. Lịch sử nghiệp vụ được giữ.'
                    : 'Nhân sự có thể đăng nhập trở lại bằng tài khoản hiện có. Các phiên đã thu hồi không được khôi phục.',
              ),
              if (widget.deleting) ...[
                const SizedBox(height: 12),
                const Text(
                  'Nếu chưa có dữ liệu liên kết, tài khoản được xóa hẳn. Nếu đã có lịch sử nghiệp vụ, hệ thống xóa mềm để giữ các liên kết và lịch sử.',
                ),
              ],
              if (widget.controller.error != null) ...[
                const SizedBox(height: 16),
                FeedbackBox(widget.controller.error!, key: errorAnchor),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: busy ? null : submit,
            style: FilledButton.styleFrom(
              backgroundColor: widget.deleting
                  ? FarmColors.danger
                  : widget.user.active
                  ? FarmColors.amber
                  : forest,
              foregroundColor: !widget.deleting && widget.user.active
                  ? ink
                  : Colors.white,
            ),
            child: FarmSubmitLabel(
              busy: busy,
              label: action,
              busyLabel: 'Đang xử lý…',
            ),
          ),
        ],
      ),
    ),
  );
}
