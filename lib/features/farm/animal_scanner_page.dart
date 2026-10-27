import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/farm_illustrations.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import 'animal_qr.dart';

Future<void> openAnimalQrScanner(
  BuildContext context, {
  required Widget Function(String id) detailBuilder,
}) async {
  final id = await Navigator.push<String>(
    context,
    MaterialPageRoute(builder: (_) => const AnimalScannerPage()),
  );
  if (id == null || !context.mounted) return;
  // The existing authenticated detail endpoint scopes every read to the farm.
  await Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (_) => detailBuilder(id)),
  );
}

class AnimalScannerPage extends StatefulWidget {
  const AnimalScannerPage({super.key, this.cameraBuilder});
  final Widget Function(BuildContext context, ValueChanged<String> onCode)?
  cameraBuilder;
  @override
  State<AnimalScannerPage> createState() => _AnimalScannerPageState();
}

class _AnimalScannerPageState extends State<AnimalScannerPage>
    with WidgetsBindingObserver {
  final pasted = TextEditingController();
  MobileScannerController? camera;
  String? error, cameraError;
  bool finishing = false, picking = false, foreground = true;
  bool get supported =>
      kIsWeb ||
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ].contains(defaultTargetPlatform);
  bool get canReadImage => !kIsWeb && camera != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.cameraBuilder == null && supported) {
      camera = MobileScannerController(
        autoStart: false,
        formats: const [BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(startCamera()),
      );
    }
  }

  Future<void> startCamera() async {
    if (!mounted ||
        finishing ||
        picking ||
        !foreground ||
        camera == null ||
        camera!.value.isRunning) {
      return;
    }
    try {
      await camera!.start();
      if (mounted) setState(() => cameraError = null);
    } on MobileScannerException catch (e) {
      if (mounted) {
        setState(
          () => cameraError =
              e.errorCode == MobileScannerErrorCode.permissionDenied
              ? 'Chưa có quyền camera. Bạn có thể cấp quyền camera cho Smart Farm trong Cài đặt, hoặc chọn ảnh QR / dán nội dung mã.'
              : 'Chưa mở được camera. Hãy thử lại hoặc dán nội dung QR.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => cameraError =
              'Chưa mở được camera. Hãy thử lại hoặc dán nội dung QR.',
        );
      }
    }
  }

  Future<void> stopCamera() async {
    try {
      if (camera?.value.isRunning == true) await camera!.stop();
    } catch (_) {
      /* Camera can already be closed by the OS. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (camera?.value.hasCameraPermission != true) return;
    if (foreground) {
      unawaited(startCamera());
    } else {
      unawaited(stopCamera());
    }
  }

  void accept(String raw) {
    if (finishing || picking) return;
    final id = animalIdFromQr(raw);
    if (id == null) {
      const message =
          'Mã này không phải QR vật nuôi của Smart Farm. Hãy thử mã khác.';
      if (error != message) setState(() => error = message);
      return;
    }
    setState(() {
      finishing = true;
      error = null;
    });
    unawaited(finish(id));
  }

  Future<void> finish(String id) async {
    await stopCamera();
    if (mounted) Navigator.pop(context, id);
  }

  Future<void> readImage() async {
    if (picking || finishing || camera == null) return;
    setState(() {
      picking = true;
      error = null;
    });
    String? raw;
    try {
      await stopCamera();
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Ảnh QR',
            extensions: ['png', 'jpg', 'jpeg'],
            mimeTypes: ['image/png', 'image/jpeg'],
            uniformTypeIdentifiers: ['public.png', 'public.jpeg'],
          ),
        ],
      );
      if (file != null && mounted) {
        if (await file.length() > 12 * 1024 * 1024) {
          throw const FormatException('Ảnh quá lớn. Hãy chọn ảnh dưới 12 MB.');
        }
        final result = await camera!.analyzeImage(file.path);
        final values =
            result?.barcodes.map((b) => b.rawValue).whereType<String>() ??
            const <String>[];
        raw = values
            .where((value) => animalIdFromQr(value) != null)
            .firstOrNull;
        if (raw == null) {
          throw const FormatException(
            'Chưa tìm thấy QR Smart Farm trong ảnh. Hãy chọn ảnh rõ nét hoặc dùng camera.',
          );
        }
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Chưa đọc được ảnh QR. Hãy thử ảnh khác hoặc dùng camera.',
        );
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
    if (!mounted) return;
    if (raw != null) {
      accept(raw);
    } else {
      await startCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pasted.dispose();
    final controller = camera;
    camera = null;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  Widget cameraUnavailable(String message) => ColoredBox(
    color: FarmColors.sky,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                size: 42,
                color: forest,
              ),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              if (camera != null)
                TextButton.icon(
                  onPressed: startCamera,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại camera'),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Quét QR vật nuôi'),
      actions: [
        if (camera != null)
          IconButton(
            tooltip: 'Bật / tắt đèn',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () async {
              try {
                await camera!.toggleTorch();
              } catch (_) {
                if (mounted) {
                  setState(
                    () => error = 'Chưa bật được đèn trên thiết bị này.',
                  );
                }
              }
            },
          ),
      ],
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FarmInfoCard(
                  color: FarmColors.mint,
                  child: Row(
                    children: [
                      const FarmSpeciesIllustration(
                        speciesName: 'Bò',
                        size: 56,
                        decorative: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tìm đúng con, mở đúng hồ sơ',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Đưa QR vào khung. Không cần chọn chuồng.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(FarmRadii.card),
                  child: SizedBox(
                    height: MediaQuery.sizeOf(context).width < 600 ? 290 : 340,
                    child:
                        widget.cameraBuilder?.call(context, accept) ??
                        (camera == null
                            ? cameraUnavailable(
                                'Camera QR hỗ trợ trên Android, iPhone và trình duyệt. Bạn vẫn có thể dán nội dung mã bên dưới.',
                              )
                            : cameraError != null
                            ? cameraUnavailable(cameraError!)
                            : MobileScanner(
                                controller: camera,
                                useAppLifecycleState: false,
                                onDetect: (capture) {
                                  if (!foreground) return;
                                  final values = capture.barcodes
                                      .map((b) => b.rawValue)
                                      .whereType<String>();
                                  final raw =
                                      values
                                          .where(
                                            (v) => animalIdFromQr(v) != null,
                                          )
                                          .firstOrNull ??
                                      values.firstOrNull;
                                  if (raw != null) accept(raw);
                                },
                                errorBuilder: (_, failure) => cameraUnavailable(
                                  failure.errorCode ==
                                          MobileScannerErrorCode
                                              .permissionDenied
                                      ? 'Chưa có quyền camera. Cấp quyền cho Smart Farm trong Cài đặt, hoặc dán nội dung QR bên dưới.'
                                      : 'Chưa mở được camera. Hãy thử lại hoặc dán nội dung QR.',
                                ),
                                overlayBuilder: (_, _) => IgnorePointer(
                                  child: Center(
                                    child: FractionallySizedBox(
                                      widthFactor: .75,
                                      heightFactor: .75,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: FarmColors.mint,
                                            width: 3,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )),
                  ),
                ),
                const SizedBox(height: 12),
                if (error != null) ...[
                  FeedbackBox(error!),
                  const SizedBox(height: 12),
                ],
                if (canReadImage) ...[
                  OutlinedButton.icon(
                    onPressed: finishing || picking ? null : readImage,
                    icon: const Icon(Icons.image_search_outlined),
                    label: Text(picking ? 'Đang đọc ảnh…' : 'Chọn ảnh QR'),
                  ),
                  const SizedBox(height: 12),
                ],
                FarmInfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const ValueKey('qr-paste-field'),
                        controller: pasted,
                        maxLength: 256,
                        enabled: !finishing && !picking,
                        decoration: const InputDecoration(
                          labelText: 'Dán nội dung QR',
                          prefixIcon: Icon(Icons.qr_code_2),
                        ),
                        onSubmitted: accept,
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        key: const ValueKey('qr-open-pasted'),
                        onPressed: finishing || picking
                            ? null
                            : () => accept(pasted.text),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Mở hồ sơ từ mã'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Hồ sơ được mở theo quyền của tài khoản đang đăng nhập. Cần kết nối máy chủ để xem dữ liệu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
