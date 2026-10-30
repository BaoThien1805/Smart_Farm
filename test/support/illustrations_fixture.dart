// Fixture-only preview: no API, account, permissions, or production data.
import 'package:flutter/material.dart';
import 'package:smart_farm/core/farm_illustrations.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/core/ui_components.dart';

// A 24px checker PNG fixture, not a real animal photo or production data.
const previewPhoto =
    'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAIAAABvFaqvAAAAOklEQVR4nGOUKE5gIASO1rcTVMPEQCXANGoQQTBq0FA0iPHup+cEFVk3Vg5BrzGNGkQQjBpEGFDNIAAlrAbQS/mP3AAAAABJRU5ErkJggg==';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: farmTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(1.3)),
      child: child!,
    ),
    home: const IllustrationsPreview(),
  ),
);

class IllustrationsPreview extends StatelessWidget {
  const IllustrationsPreview({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(FarmSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FarmSectionHeader(
                  title: 'Minh họa nông trại',
                  subtitle: 'Preview bước 02 · cỡ chữ 1.3',
                ),
                const SizedBox(height: 16),
                const FarmWelcomeBanner(),
                const SizedBox(height: 16),
                FarmInfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sticker 48 / 64 / 96 px'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          for (final art in FarmSpeciesArt.values)
                            Column(
                              children: [
                                for (final size in [48.0, 64.0, 96.0])
                                  FarmSpeciesIllustration(
                                    speciesName: art.label,
                                    size: size,
                                    decorative: true,
                                  ),
                                Text(art.label),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const FarmInfoCard(
                  color: FarmColors.lavender,
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _Example(
                        label: 'Chưa rõ loài',
                        child: FarmSpeciesIllustration(speciesName: 'Lạc đà'),
                      ),
                      _Example(
                        label: 'Chuồng hỗn hợp',
                        child: FarmPenIllustration(),
                      ),
                      _Example(
                        label: 'Ảnh trống',
                        child: FarmAnimalImage(
                          photoData: '',
                          speciesCode: 'HEO',
                        ),
                      ),
                      _Example(
                        label: 'Ảnh lỗi',
                        child: FarmAnimalImage(
                          photoData: '%%%',
                          speciesName: 'Dê',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FarmInfoCard(
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FarmAnimalImage(
                        photoData: previewPhoto,
                        speciesName: 'Bò',
                        semanticLabel: 'Ảnh PNG mẫu do người dùng chọn',
                      ),
                      const Text('Ảnh hợp lệ được ưu tiên'),
                      const Text('PNG mẫu: ô màu xanh'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Example extends StatelessWidget {
  const _Example({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 116,
    child: Column(children: [child, const SizedBox(height: 8), Text(label)]),
  );
}
