import 'package:flutter/material.dart';

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
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final farmName = TextEditingController();
  final confirmation = TextEditingController();
  bool registering = false;
  bool hidden = true;
  @override
  void dispose() {
    name.dispose();
    farmName.dispose();
    confirmation.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void submit() {
    if (form.currentState!.validate()) {
      if (registering) {
        widget.auth.register(
          name.text,
          farmName.text,
          email.text,
          password.text,
        );
      } else {
        widget.auth.login(email.text, password.text);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide =
              constraints.maxWidth >= 900 && constraints.maxHeight >= 700;
          return Row(
            children: [
              if (wide) const Expanded(child: _WelcomePanel()),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(wide ? 40 : 20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: AutofillGroup(
                        child: Form(
                          key: form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Brand(),
                              const SizedBox(height: 52),
                              Text(
                                registering
                                    ? 'BẮT ĐẦU TRANG TRẠI CỦA BẠN'
                                    : 'CHÀO MỪNG TRỞ LẠI',
                                style: TextStyle(
                                  fontSize: 12,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w700,
                                  color: forest,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                registering
                                    ? 'Đăng ký\nchủ trang trại.'
                                    : 'Đăng nhập\ntrang trại của bạn.',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineLarge,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Một nơi để ghi chép, chăm sóc và theo dõi trang trại mỗi ngày.',
                              ),
                              const SizedBox(height: 32),
                              if (widget.auth.error != null) ...[
                                FeedbackBox(widget.auth.error!),
                                const SizedBox(height: 18),
                              ],
                              if (widget.auth.notice != null) ...[
                                FeedbackBox(
                                  widget.auth.notice!,
                                  isError: false,
                                ),
                                const SizedBox(height: 18),
                              ],
                              if (registering) ...[
                                TextFormField(
                                  controller: name,
                                  enabled: !widget.auth.busy,
                                  textInputAction: TextInputAction.next,
                                  maxLength: 100,
                                  decoration: const InputDecoration(
                                    labelText: 'Họ và tên',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (v) => (v?.trim().length ?? 0) < 2
                                      ? 'Tên cần ít nhất 2 ký tự.'
                                      : null,
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: farmName,
                                  enabled: !widget.auth.busy,
                                  textInputAction: TextInputAction.next,
                                  maxLength: 100,
                                  decoration: const InputDecoration(
                                    labelText: 'Tên trang trại',
                                    prefixIcon: Icon(
                                      Icons.agriculture_outlined,
                                    ),
                                  ),
                                  validator: (v) => (v?.trim().length ?? 0) < 2
                                      ? 'Tên trang trại cần ít nhất 2 ký tự.'
                                      : null,
                                ),
                                const SizedBox(height: 20),
                              ],
                              TextFormField(
                                controller: email,
                                enabled: !widget.auth.busy,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.mail_outline),
                                ),
                                validator: (value) =>
                                    value == null ||
                                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                            .hasMatch(value.trim())
                                    ? 'Nhập địa chỉ email hợp lệ.'
                                    : null,
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: password,
                                enabled: !widget.auth.busy,
                                obscureText: hidden,
                                autofillHints: [
                                  registering
                                      ? AutofillHints.newPassword
                                      : AutofillHints.password,
                                ],
                                maxLength: registering ? 128 : null,
                                onFieldSubmitted: (_) => submit(),
                                decoration: InputDecoration(
                                  labelText: 'Mật khẩu',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: hidden
                                        ? 'Hiện mật khẩu'
                                        : 'Ẩn mật khẩu',
                                    onPressed: () =>
                                        setState(() => hidden = !hidden),
                                    icon: Icon(
                                      hidden
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Nhập mật khẩu của bạn.'
                                    : registering && value.length < 12
                                    ? 'Mật khẩu cần ít nhất 12 ký tự.'
                                    : null,
                              ),
                              if (registering) ...[
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: confirmation,
                                  enabled: !widget.auth.busy,
                                  obscureText: hidden,
                                  onFieldSubmitted: (_) => submit(),
                                  decoration: const InputDecoration(
                                    labelText: 'Nhập lại mật khẩu',
                                    prefixIcon: Icon(Icons.lock_outline),
                                  ),
                                  validator: (v) => v != password.text
                                      ? 'Mật khẩu nhập lại chưa khớp.'
                                      : null,
                                ),
                              ],
                              const SizedBox(height: 26),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: widget.auth.busy ? null : submit,
                                  child: widget.auth.busy
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              registering
                                                  ? 'Tạo tài khoản'
                                                  : 'Đăng nhập',
                                            ),
                                            SizedBox(width: 12),
                                            Icon(Icons.arrow_forward, size: 20),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextButton(
                                onPressed: widget.auth.busy
                                    ? null
                                    : () {
                                        setState(
                                          () => registering = !registering,
                                        );
                                        form.currentState?.reset();
                                        widget.auth.error = null;
                                        widget.auth.notice = null;
                                      },
                                child: Text(
                                  registering ? 'Đã có tài khoản? Đăng nhập' : 'Chưa có tài khoản? Đăng ký chủ trang trại',
                                ),
                              ),
                              if (registering)
                                const Text(
                                  'Nhân viên được chủ trang trại tạo tài khoản trong mục Nhân sự.',
                                ),
                              const SizedBox(height: 42),
                              const Center(
                                child: Text(
                                  'SMART FARM  /  QUẢN LÝ CHĂN NUÔI',
                                  style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 1.4,
                                    color: muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(20),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: forest,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _FieldPainter())),
        Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Brand(light: true),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'GẦN TRANG TRẠI HƠN MỖI NGÀY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Chăm từng con.\nVững cả trang trại.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 370),
                child: Text(
                  'Bắt đầu từ những ghi chép nhỏ, để công việc hằng ngày luôn rõ ràng và ngăn nắp.',
                  style: TextStyle(
                    color: Color(0xFFDDEAD9),
                    fontSize: 17,
                    height: 1.7,
                  ),
                ),
              ),
              const Spacer(),
              const Row(
                children: [
                  Icon(Icons.eco_outlined, color: Color(0xFFE4EAB8)),
                  SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Đơn giản để bắt đầu. Dễ dàng để sử dụng.',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF38664C);
    canvas.drawCircle(Offset(size.width * .88, size.height * .12), 115, paint);
    paint.color = const Color(0xFFE4EAB8).withValues(alpha: .2);
    canvas.drawCircle(Offset(size.width * .88, size.height * .12), 65, paint);
    paint
      ..color = Colors.white.withValues(alpha: .075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 12; i++) {
      final y = size.height * .78 + i * 25;
      final path = Path()
        ..moveTo(-100, y)
        ..cubicTo(
          size.width * .25,
          y - 190,
          size.width * .6,
          y + 130,
          size.width + 100,
          y - 80,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_FieldPainter oldDelegate) => false;
}
