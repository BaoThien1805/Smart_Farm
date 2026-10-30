// Local fixture preview only. This entry point never calls the backend.
import 'package:flutter/material.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/core/ui_components.dart';
import 'package:smart_farm/features/farm/farm_widgets.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: farmTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(1.3)),
      child: child!,
    ),
    home: const DesignSystemPreview(),
  ),
);

class DesignSystemPreview extends StatelessWidget {
  const DesignSystemPreview({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Smart Farm')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(FarmSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FarmSectionHeader(
                title: 'Bộ giao diện C',
                subtitle: 'Bản xem thử với dữ liệu minh họa · cỡ chữ 1.3',
              ),
              const SizedBox(height: FarmSpacing.xl),
              const FarmInfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FarmSectionHeader(title: 'Tình trạng vật nuôi'),
                    SizedBox(height: FarmSpacing.lg),
                    Wrap(
                      spacing: FarmSpacing.sm,
                      runSpacing: FarmSpacing.sm,
                      children: [
                        FarmStatusBadge(
                          label: 'Đang nuôi',
                          tone: FarmBadgeTone.success,
                          icon: Icons.circle,
                        ),
                        FarmStatusBadge(
                          label: 'Cần chăm sóc',
                          tone: FarmBadgeTone.warning,
                        ),
                        FarmStatusBadge(
                          label: 'Đã chết',
                          tone: FarmBadgeTone.neutral,
                        ),
                        FarmStatusBadge(
                          label: 'Kiểm tra sức khỏe theo lịch chăm sóc của trang trại',
                          tone: FarmBadgeTone.lavender,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: FarmSpacing.lg),
              const FeedbackBox(
                'Dữ liệu chưa được lưu. Vui lòng kiểm tra kết nối và thử lại.',
              ),
              const SizedBox(height: FarmSpacing.lg),
              FarmInfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FarmSectionHeader(title: 'Thông tin chuồng'),
                    const SizedBox(height: FarmSpacing.lg),
                    TextFormField(
                      initialValue: 'Chuồng chăm sóc',
                      decoration: farmInputDecoration(label: 'Tên chuồng'),
                    ),
                    const SizedBox(height: FarmSpacing.lg),
                    Wrap(
                      spacing: FarmSpacing.sm,
                      runSpacing: FarmSpacing.sm,
                      children: [
                        ChoiceChip(
                          label: const Text('Tất cả'),
                          selected: true,
                          onSelected: (_) {},
                        ),
                        ChoiceChip(
                          label: const Text('Đang sử dụng'),
                          selected: false,
                          onSelected: (_) {},
                        ),
                      ],
                    ),
                    const SizedBox(height: FarmSpacing.lg),
                    FilledButton.icon(
                      onPressed: () => farmForm(
                        context,
                        title: 'Thêm chuồng trại',
                        fields: const [
                          FarmField('code', 'Mã chuồng', initial: 'CT-01'),
                          FarmField(
                            'name',
                            'Tên chuồng',
                            initial: 'Chuồng chăm sóc',
                          ),
                          FarmField(
                            'capacity',
                            'Sức chứa (con)',
                            initial: '10',
                            numeric: true,
                          ),
                          FarmField('active', 'Đang sử dụng', boolean: true),
                        ],
                        save: (_) async {},
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Mở form dùng chung'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: FarmSpacing.lg),
              const FarmInfoCard(
                color: FarmColors.sky,
                child: Text(
                  'Mọi trạng thái đều có nhãn chữ, giữ dễ đọc khi tăng cỡ chữ.',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
