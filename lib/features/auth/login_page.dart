import 'package:flutter/material.dart';

import '../../core/farm_illustrations.dart';
import '../../core/theme.dart';
import 'auth_controller.dart';

class LoginPage extends StatefulWidget {
  final AuthController auth;
  const LoginPage({super.key, required this.auth});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final errorAnchor = GlobalKey();
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final farmName = TextEditingController();
  final confirmation = TextEditingController();
  bool registering = false, hidden = true;

  @override
  void dispose() {
    name.dispose();
    farmName.dispose();
    confirmation.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void switchMode() {
    if (widget.auth.busy) return;
    setState(() => registering = !registering);
    form.currentState?.reset();
    widget.auth.error = null;
    widget.auth.notice = null;
  }

  Future<void> submit() async {
    if (widget.auth.busy || !form.currentState!.validate()) return;
    final success = registering
        ? await widget.auth.register(
            name.text,
            farmName.text,
            email.text,
            password.text,
          )
        : await widget.auth.login(email.text, password.text);
    if (!success && mounted) {
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && errorAnchor.currentContext != null) {
        await Scrollable.ensureVisible(
          errorAnchor.currentContext!,
          duration: const Duration(milliseconds: 200),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.auth,
    builder: (context, _) {
      final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
      return Scaffold(
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              return Row(
                children: [
                  if (wide) const Expanded(child: _WelcomePanel()),
                  Expanded(
                    key: const ValueKey('auth-form'),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: AutofillGroup(
                          child: Form(
                            key: form,
                            child: Column(
                              children: [
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, formConstraints) =>
                                        SingleChildScrollView(
                                          keyboardDismissBehavior:
                                              ScrollViewKeyboardDismissBehavior
                                                  .onDrag,
                                          padding: EdgeInsets.fromLTRB(
                                            wide ? 32 : 20,
                                            16,
                                            wide ? 32 : 20,
                                            24,
                                          ),
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              minHeight:
                                                  (formConstraints.maxHeight -
                                                          40)
                                                      .clamp(
                                                        0,
                                                        double.infinity,
                                                      ),
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                if (registering)
                                                  Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: IconButton(
                                                      tooltip:
                                                          'Quay lại đăng nhập',
                                                      onPressed:
                                                          widget.auth.busy
                                                          ? null
                                                          : switchMode,
                                                      icon: const Icon(
                                                        Icons.arrow_back,
                                                      ),
                                                    ),
                                                  ),
                                                if (!wide &&
                                                    !keyboard &&
                                                    !registering) ...[
                                                  const FarmAuthHero(),
                                                  const SizedBox(height: 20),
                                                ],
                                                Semantics(
                                                  header: true,
                                                  child: Text(
                                                    registering
                                                        ? 'Tạo trang trại của bạn'
                                                        : 'Smart Farm',
                                                    textAlign: registering
                                                        ? TextAlign.left
                                                        : TextAlign.center,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .headlineLarge,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                Text(
                                                  registering
                                                      ? 'Bắt đầu quản lý trang trại dễ dàng với Smart Farm.'
                                                      : 'Quản lý trang trại dễ dàng, hiệu quả mỗi ngày.',
                                                  textAlign: registering
                                                      ? TextAlign.left
                                                      : TextAlign.center,
                                                ),
                                                const SizedBox(height: 24),
                                                Column(
                                                  key: errorAnchor,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    if (widget.auth.error !=
                                                        null) ...[
                                                      FeedbackBox(
                                                        widget.auth.error!,
                                                      ),
                                                      const SizedBox(
                                                        height: 16,
                                                      ),
                                                    ],
                                                    if (widget.auth.notice !=
                                                        null) ...[
                                                      FeedbackBox(
                                                        widget.auth.notice!,
                                                        isError: false,
                                                      ),
                                                      const SizedBox(
                                                        height: 16,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                if (registering) ...[
                                                  TextFormField(
                                                    key: const ValueKey(
                                                      'auth-name',
                                                    ),
                                                    controller: name,
                                                    enabled: !widget.auth.busy,
                                                    textInputAction:
                                                        TextInputAction.next,
                                                    autofillHints: const [
                                                      AutofillHints.name,
                                                    ],
                                                    maxLength: 100,
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText:
                                                              'Họ và tên',
                                                          prefixIcon: Icon(
                                                            Icons
                                                                .person_outline,
                                                          ),
                                                        ),
                                                    validator: (v) =>
                                                        (v?.trim().length ??
                                                                0) <
                                                            2
                                                        ? 'Tên cần ít nhất 2 ký tự.'
                                                        : null,
                                                  ),
                                                  const SizedBox(height: 16),
                                                  TextFormField(
                                                    key: const ValueKey(
                                                      'auth-farm-name',
                                                    ),
                                                    controller: farmName,
                                                    enabled: !widget.auth.busy,
                                                    textInputAction:
                                                        TextInputAction.next,
                                                    autofillHints: const [
                                                      AutofillHints
                                                          .organizationName,
                                                    ],
                                                    maxLength: 100,
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText:
                                                              'Tên trang trại',
                                                          prefixIcon: Icon(
                                                            Icons
                                                                .home_work_outlined,
                                                          ),
                                                        ),
                                                    validator: (v) =>
                                                        (v?.trim().length ??
                                                                0) <
                                                            2
                                                        ? 'Tên trang trại cần ít nhất 2 ký tự.'
                                                        : null,
                                                  ),
                                                  const SizedBox(height: 16),
                                                ],
                                                TextFormField(
                                                  key: const ValueKey(
                                                    'auth-email',
                                                  ),
                                                  controller: email,
                                                  enabled: !widget.auth.busy,
                                                  keyboardType: TextInputType
                                                      .emailAddress,
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  autofillHints: const [
                                                    AutofillHints.username,
                                                  ],
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Email',
                                                        prefixIcon: Icon(
                                                          Icons.mail_outline,
                                                        ),
                                                      ),
                                                  validator: (value) =>
                                                      value == null ||
                                                          !RegExp(
                                                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                                          ).hasMatch(
                                                            value.trim(),
                                                          )
                                                      ? 'Nhập địa chỉ email hợp lệ.'
                                                      : null,
                                                ),
                                                const SizedBox(height: 16),
                                                TextFormField(
                                                  key: const ValueKey(
                                                    'auth-password',
                                                  ),
                                                  controller: password,
                                                  enabled: !widget.auth.busy,
                                                  obscureText: hidden,
                                                  textInputAction: registering
                                                      ? TextInputAction.next
                                                      : TextInputAction.done,
                                                  autofillHints: [
                                                    registering
                                                        ? AutofillHints
                                                              .newPassword
                                                        : AutofillHints
                                                              .password,
                                                  ],
                                                  maxLength: registering
                                                      ? 128
                                                      : null,
                                                  onFieldSubmitted: (_) {
                                                    if (registering) {
                                                      FocusScope.of(context)
                                                          .nextFocus();
                                                    } else {
                                                      submit();
                                                    }
                                                  },
                                                  decoration: InputDecoration(
                                                    labelText: 'Mật khẩu',
                                                    helperText: registering
                                                        ? 'Từ 12 đến 128 ký tự'
                                                        : null,
                                                    prefixIcon: const Icon(
                                                      Icons.lock_outline,
                                                    ),
                                                    suffixIcon: IconButton(
                                                      tooltip: hidden
                                                          ? 'Hiện mật khẩu'
                                                          : 'Ẩn mật khẩu',
                                                      onPressed:
                                                          widget.auth.busy
                                                          ? null
                                                          : () => setState(
                                                              () => hidden =
                                                                  !hidden,
                                                            ),
                                                      icon: Icon(
                                                        hidden
                                                            ? Icons
                                                                  .visibility_outlined
                                                            : Icons
                                                                  .visibility_off_outlined,
                                                      ),
                                                    ),
                                                  ),
                                                  validator: (value) =>
                                                      value == null ||
                                                          value.isEmpty
                                                      ? 'Nhập mật khẩu của bạn.'
                                                      : registering &&
                                                            value.length < 12
                                                      ? 'Mật khẩu cần ít nhất 12 ký tự.'
                                                      : null,
                                                ),
                                                if (registering) ...[
                                                  const SizedBox(height: 16),
                                                  TextFormField(
                                                    key: const ValueKey(
                                                      'auth-confirmation',
                                                    ),
                                                    controller: confirmation,
                                                    enabled: !widget.auth.busy,
                                                    obscureText: hidden,
                                                    textInputAction:
                                                        TextInputAction.done,
                                                    autofillHints: const [
                                                      AutofillHints.newPassword,
                                                    ],
                                                    onFieldSubmitted: (_) =>
                                                        submit(),
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText: 'Nhập lại mật khẩu',
                                                          prefixIcon: Icon(
                                                            Icons.lock_outline,
                                                          ),
                                                        ),
                                                    validator: (v) =>
                                                        v != password.text
                                                        ? 'Mật khẩu nhập lại chưa khớp.'
                                                        : null,
                                                  ),
                                                  const SizedBox(height: 16),
                                                  const Text(
                                                    'Nhân viên được chủ trang trại tạo tài khoản trong mục Nhân sự.',
                                                  ),
                                                  if (!wide && !keyboard) ...[
                                                    const SizedBox(height: 20),
                                                    const FarmWelcomeBanner(),
                                                  ],
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    wide ? 32 : 20,
                                    12,
                                    wide ? 32 : 20,
                                    16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      FilledButton(
                                        key: const ValueKey('auth-submit'),
                                        onPressed: widget.auth.busy
                                            ? null
                                            : submit,
                                        child: widget.auth.busy
                                            ? SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      semanticsLabel:
                                                          registering
                                                          ? 'Đang tạo tài khoản'
                                                          : 'Đang đăng nhập',
                                                    ),
                                              )
                                            : Text(
                                                registering
                                                    ? 'Tạo tài khoản'
                                                    : 'Đăng nhập',
                                              ),
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton(
                                        key: const ValueKey('auth-switch'),
                                        onPressed: widget.auth.busy
                                            ? null
                                            : switchMode,
                                        child: Text(
                                          registering
                                              ? 'Đã có tài khoản? Đăng nhập'
                                              : 'Đăng ký chủ trang trại',
                                          textAlign: TextAlign.center,
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
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel();
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(40),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Brand(),
        const SizedBox(height: 48),
        Text(
          'Chăm từng con.\nVững cả trang trại.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 16),
        const Text(
          'Một nơi để ghi chép, chăm sóc và theo dõi trang trại mỗi ngày.',
        ),
        const SizedBox(height: 32),
        const FarmWelcomeBanner(),
      ],
    ),
  );
}
