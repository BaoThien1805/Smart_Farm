import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_repository.dart';
import '../auth/user_avatar.dart';
import 'password_change_view.dart';

class ProfilePage extends StatefulWidget {
  final AuthController auth;
  const ProfilePage({super.key, required this.auth});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final form = GlobalKey<FormState>(), passwordErrorAnchor = GlobalKey();
  final current = TextEditingController(),
      next = TextEditingController(),
      confirm = TextEditingController();
  bool changingPassword = false,
      updatingAvatar = false,
      refreshing = false,
      submitting = false;
  bool loadingFarm = false, avatarNeedsRefresh = false;
  String? farmName, farmError, avatarError;
  int farmRevision = 0;
  bool get locked =>
      widget.auth.busy || updatingAvatar || refreshing || submitting;

  @override
  void initState() {
    super.initState();
    loadFarm();
  }

  @override
  void dispose() {
    farmRevision++;
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> loadFarm() async {
    if (widget.auth.user == null) return;
    final revision = ++farmRevision;
    setState(() {
      loadingFarm = true;
      farmError = null;
    });
    try {
      final response = await widget.auth.repository.api.request(
        'GET',
        '/farm/location',
      );
      final location = response['location'];
      final name = location is Map ? location['name'] : null;
      if (mounted && revision == farmRevision) {
        setState(
          () =>
              farmName = name is String && name.trim().isNotEmpty ? name : null,
        );
      }
    } on ApiException catch (e) {
      if (mounted && revision == farmRevision) {
        setState(() => farmError = e.message);
      }
    } finally {
      if (mounted && revision == farmRevision) {
        setState(() => loadingFarm = false);
      }
    }
  }

  Future<void> refresh() async {
    if (locked || widget.auth.user == null) return;
    setState(() => refreshing = true);
    try {
      final success = await widget.auth.refresh();
      if (!mounted) return;
      if (success) {
        setState(() {
          avatarNeedsRefresh = false;
          avatarError = null;
        });
      }
      if (widget.auth.user != null) await loadFarm();
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  Future<void> changeAvatar({bool remove = false}) async {
    final user = widget.auth.user;
    if (locked || avatarNeedsRefresh || user?.isAdmin != true) return;
    setState(() {
      updatingAvatar = true;
      avatarError = null;
    });
    var saved = false;
    try {
      final image = remove ? null : await pickUserAvatar();
      if (!remove && image == null) return;
      if (!mounted ||
          widget.auth.user?.id != user!.id ||
          widget.auth.user?.isAdmin != true) {
        return;
      }
      await widget.auth.repository.api.request(
        'PATCH',
        '/users/${user.id}/avatar',
        body: {'photoBase64': image},
      );
      saved = true;
      final refreshed = await widget.auth.refresh();
      if (mounted && !refreshed && widget.auth.user != null) {
        setState(() {
          avatarNeedsRefresh = true;
          avatarError = 'Ảnh đã được lưu nhưng chưa tải lại thông tin. Hãy chọn Làm mới thông tin.';
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => avatarError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          avatarNeedsRefresh = saved;
          avatarError = saved
              ? 'Ảnh đã được lưu nhưng chưa tải lại thông tin. Hãy chọn Làm mới thông tin.'
              : 'Không thể cập nhật ảnh đại diện. Hãy thử lại.';
        });
      }
    } finally {
      if (mounted) setState(() => updatingAvatar = false);
    }
  }

  Future<void> submitPassword() async {
    if (locked ||
        !changingPassword ||
        form.currentState == null ||
        widget.auth.user == null) {
      return;
    }
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
    final success = await widget.auth.changePassword(current.text, next.text);
    if (success) TextInput.finishAutofillContext(shouldSave: true);
    if (!mounted) return;
    setState(() => submitting = false);
    if (!success) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = passwordErrorAnchor.currentContext;
        if (mounted && target != null) {
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 200),
          );
        }
      });
    }
  }

  Widget infoRow(IconData icon, String title, Widget value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: muted, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: muted)),
              const SizedBox(height: 4),
              value,
            ],
          ),
        ),
      ],
    ),
  );

  Widget identity(FarmUser user) => FarmInfoCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: UserAvatar(user: user, radius: 52)),
        const SizedBox(height: 16),
        Text(
          user.name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(user.email, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Center(
          child: FarmStatusBadge(
            label: user.roleLabel,
            tone: FarmBadgeTone.info,
          ),
        ),
        if (user.isAdmin) ...[
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: locked || avatarNeedsRefresh ? null : changeAvatar,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  updatingAvatar ? 'Đang xử lý ảnh…' : 'Đổi ảnh đại diện',
                ),
              ),
              if (user.avatarData?.isNotEmpty == true)
                TextButton(
                  onPressed: locked || avatarNeedsRefresh
                      ? null
                      : () => changeAvatar(remove: true),
                  child: const Text('Xóa ảnh đại diện'),
                ),
            ],
          ),
        ],
        if (updatingAvatar)
          const LinearProgressIndicator(
            semanticsLabel: 'Đang cập nhật ảnh đại diện',
          ),
        if (avatarError != null) ...[
          const SizedBox(height: 12),
          FeedbackBox(avatarError!),
        ],
      ],
    ),
  );

  Widget farmCard() => FarmInfoCard(
    color: FarmColors.mint,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FarmSectionHeader(
          title: 'Trang trại',
          subtitle: 'Trang trại gắn với tài khoản của bạn.',
        ),
        const SizedBox(height: 12),
        if (loadingFarm)
          const LinearProgressIndicator(
            semanticsLabel: 'Đang tải tên trang trại',
          ),
        if (farmName != null)
          Text(farmName!, style: Theme.of(context).textTheme.titleLarge),
        if (!loadingFarm && farmError == null && farmName == null)
          const Text('Chưa có thông tin tên trang trại.'),
        if (farmError != null) ...[
          FeedbackBox(farmError!),
          if (farmName != null)
            const Text(
              'Đang hiển thị tên trại từ lần tải trước.',
              style: TextStyle(color: muted),
            ),
          TextButton(
            onPressed: loadingFarm || locked ? null : loadFarm,
            child: const Text('Tải lại thông tin trại'),
          ),
        ],
      ],
    ),
  );

  Widget account(FarmUser user) => FarmInfoCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FarmSectionHeader(title: 'Thông tin tài khoản'),
        const SizedBox(height: 8),
        infoRow(
          Icons.badge_outlined,
          'Mã nhân sự',
          Text(user.code?.isNotEmpty == true ? user.code! : 'Chưa có mã'),
        ),
        const Divider(height: 1),
        infoRow(Icons.person_outline, 'Họ và tên', Text(user.name)),
        const Divider(height: 1),
        infoRow(Icons.email_outlined, 'Email', Text(user.email)),
        const Divider(height: 1),
        infoRow(Icons.verified_user_outlined, 'Vai trò', Text(user.roleLabel)),
        const Divider(height: 1),
        infoRow(
          Icons.circle_outlined,
          'Trạng thái',
          FarmStatusBadge(
            label: user.active ? 'Đang hoạt động' : 'Đã khóa',
            tone: user.active ? FarmBadgeTone.success : FarmBadgeTone.neutral,
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: locked ? null : refresh,
          icon: const Icon(Icons.refresh),
          label: Text(refreshing ? 'Đang tải lại…' : 'Làm mới thông tin'),
        ),
      ],
    ),
  );

  Widget security() => FarmInfoCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FarmSectionHeader(title: 'Bảo mật đăng nhập'),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: locked
              ? null
              : () => setState(() {
                  changingPassword = true;
                  widget.auth.error = null;
                }),
          icon: const Icon(Icons.lock_outline),
          label: const Text('Đổi mật khẩu'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: locked ? null : widget.auth.logout,
          style: OutlinedButton.styleFrom(foregroundColor: FarmColors.danger),
          icon: const Icon(Icons.logout),
          label: const Text('Đăng xuất'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.auth,
    builder: (context, _) {
      final user = widget.auth.user;
      if (user == null) return const SizedBox.shrink();
      if (changingPassword) {
        return SafeArea(
          child: PasswordChangeView(
            formKey: form,
            errorAnchor: passwordErrorAnchor,
            current: current,
            next: next,
            confirm: confirm,
            busy: locked,
            error: widget.auth.error,
            onSubmit: submitPassword,
            onBack: () {
              if (!locked) setState(() => changingPassword = false);
            },
          ),
        );
      }
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FarmSectionHeader(
                    title: 'Tài khoản của tôi',
                    pageTitle: true,
                    subtitle: 'Thông tin cá nhân và bảo mật đăng nhập.',
                  ),
                  const SizedBox(height: 20),
                  if (widget.auth.error != null) ...[
                    FeedbackBox(widget.auth.error!),
                    const SizedBox(height: 16),
                  ],
                  LayoutBuilder(
                    builder: (context, c) {
                      final left = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          identity(user),
                          const SizedBox(height: 16),
                          farmCard(),
                        ],
                      );
                      final right = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          account(user),
                          const SizedBox(height: 16),
                          security(),
                        ],
                      );
                      if (c.maxWidth < 850) {
                        return Column(
                          children: [left, const SizedBox(height: 16), right],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: left),
                          const SizedBox(width: 20),
                          Expanded(flex: 3, child: right),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
