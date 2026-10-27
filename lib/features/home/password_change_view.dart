import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/ui_components.dart';

class PasswordChangeView extends StatefulWidget {
  const PasswordChangeView({
    super.key,
    required this.formKey,
    required this.errorAnchor,
    required this.current,
    required this.next,
    required this.confirm,
    required this.busy,
    required this.onSubmit,
    required this.onBack,
    this.error,
  });
  final GlobalKey<FormState> formKey;
  final GlobalKey errorAnchor;
  final TextEditingController current, next, confirm;
  final bool busy;
  final String? error;
  final VoidCallback onSubmit, onBack;
  @override
  State<PasswordChangeView> createState() => _PasswordChangeViewState();
}

class _PasswordChangeViewState extends State<PasswordChangeView> {
  final hidden = [true, true, true];
  Widget field(
    int index,
    String label,
    TextEditingController controller,
    String? Function(String?) validator,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextFormField(
      controller: controller,
      obscureText: hidden[index],
      enabled: !widget.busy,
      enableSuggestions: false,
      autocorrect: false,
      autofillHints: [
        index == 0 ? AutofillHints.password : AutofillHints.newPassword,
      ],
      textInputAction: index == 2 ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: index == 2
          ? (_) {
              if (!widget.busy) widget.onSubmit();
            }
          : null,
      decoration: farmInputDecoration(
        label: label,
        helperText: index == 1
            ? 'Từ 12 đến 128 ký tự, khác mật khẩu hiện tại.'
            : null,
        suffixIcon: IconButton(
          tooltip:
              '${hidden[index] ? 'Hiện' : 'Ẩn'} ${index == 0
                  ? 'mật khẩu hiện tại'
                  : index == 1
                  ? 'mật khẩu mới'
                  : 'mật khẩu nhập lại'}',
          onPressed: widget.busy
              ? null
              : () => setState(() => hidden[index] = !hidden[index]),
          icon: Icon(
            hidden[index]
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
      validator: validator,
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.busy,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: widget.busy ? null : widget.onBack,
                        tooltip: 'Quay lại tài khoản',
                        icon: const Icon(Icons.arrow_back),
                      ),
                    ),
                    const FarmSectionHeader(
                      title: 'Đổi mật khẩu',
                      subtitle: 'Nhập mật khẩu hiện tại và mật khẩu mới để bảo vệ tài khoản.',
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: FarmColors.sky,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield_outlined, color: forest),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Sau khi đổi mật khẩu thành công, các phiên đăng nhập sẽ bị thu hồi. Bạn cần đăng nhập lại bằng mật khẩu mới.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    FarmInfoCard(
                      child: AutofillGroup(
                        onDisposeAction: AutofillContextAction.cancel,
                        child: Form(
                          key: widget.formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (widget.error != null) ...[
                                FeedbackBox(
                                  widget.error!,
                                  key: widget.errorAnchor,
                                ),
                                const SizedBox(height: 20),
                              ],
                              field(
                                0,
                                'Mật khẩu hiện tại',
                                widget.current,
                                (v) => v == null || v.isEmpty
                                    ? 'Nhập mật khẩu hiện tại.'
                                    : null,
                              ),
                              field(
                                1,
                                'Mật khẩu mới',
                                widget.next,
                                (v) =>
                                    v == null || v.length < 12 || v.length > 128
                                    ? 'Mật khẩu cần từ 12 đến 128 ký tự.'
                                    : v == widget.current.text
                                    ? 'Mật khẩu mới phải khác mật khẩu hiện tại.'
                                    : null,
                              ),
                              field(
                                2,
                                'Nhập lại mật khẩu mới',
                                widget.confirm,
                                (v) => v != widget.next.text
                                    ? 'Mật khẩu nhập lại không khớp.'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: line)),
          ),
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.busy ? null : widget.onSubmit,
                    icon: const Icon(Icons.lock_reset),
                    label: FarmSubmitLabel(
                      busy: widget.busy,
                      label: 'Cập nhật mật khẩu',
                      busyLabel: 'Đang xử lý…',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
