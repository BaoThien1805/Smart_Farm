import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/farm_illustrations.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import 'animal_qr.dart';
import 'farm_repository.dart';

Future<Uint8List> animalQrPdf(FarmRecord animal) async {
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/roboto-regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/roboto-bold.ttf'),
  );
  final document = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: bold),
  );
  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a6,
      margin: const pw.EdgeInsets.all(8 * PdfPageFormat.mm),
      build: (_) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFFFF9F0),
          border: pw.Border.all(color: PdfColor.fromInt(0xFF187360)),
          borderRadius: pw.BorderRadius.circular(12),
        ),
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              'SMART FARM',
              style: pw.TextStyle(
                font: bold,
                fontSize: 12,
                color: PdfColor.fromInt(0xFF187360),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text('THẺ VẬT NUÔI', style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 8),
            pw.FittedBox(
              child: pw.Text(
                animal.text('code'),
                style: pw.TextStyle(font: bold, fontSize: 20),
              ),
            ),
            if (animal.text('name').isNotEmpty)
              pw.Text(
                animal.text('name'),
                maxLines: 2,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 10),
              ),
            pw.SizedBox(height: 8),
            pw.Container(
              width: 58 * PdfPageFormat.mm,
              height: 58 * PdfPageFormat.mm,
              color: PdfColors.white,
              padding: const pw.EdgeInsets.all(5 * PdfPageFormat.mm),
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: animalQrData(animal.id),
                drawText: false,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              animal.text('speciesName'),
              maxLines: 2,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Quét bằng Smart Farm để xem hồ sơ mới nhất.',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Cần đăng nhập tài khoản của trang trại.',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 7),
            ),
          ],
        ),
      ),
    ),
  );
  return document.save();
}

class AnimalQrPage extends StatefulWidget {
  const AnimalQrPage({
    super.key,
    required this.animal,
    this.sharePdf,
    this.printPdf,
  });
  final FarmRecord animal;
  final Future<void> Function(Uint8List bytes, String filename)? sharePdf;
  final Future<void> Function(Uint8List bytes)? printPdf;
  @override
  State<AnimalQrPage> createState() => _AnimalQrPageState();
}

class _AnimalQrPageState extends State<AnimalQrPage> {
  bool busy = false;
  String? error;
  Future<void> export({required bool print}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final bytes = await animalQrPdf(widget.animal);
      final filename = 'smart-farm-${widget.animal.id}.pdf';
      if (print) {
        if (widget.printPdf != null) {
          await widget.printPdf!(bytes);
        } else {
          await Printing.layoutPdf(
            name: filename,
            onLayout: (_) async => bytes,
            format: PdfPageFormat.a6,
            dynamicLayout: false,
          );
        }
      } else {
        if (widget.sharePdf != null) {
          await widget.sharePdf!(bytes, filename);
        } else {
          await Printing.sharePdf(bytes: bytes, filename: filename);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Chưa xuất được thẻ QR. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final animal = widget.animal;
    return Scaffold(
      appBar: AppBar(title: const Text('Thẻ QR vật nuôi')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FarmInfoCard(
                    color: FarmColors.mint,
                    child: Row(
                      children: [
                        FarmSpeciesIllustration(
                          speciesName: animal.text('speciesName'),
                          size: 64,
                          decorative: true,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                animal.text('code'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              if (animal.text('name').isNotEmpty)
                                Text(animal.text('name')),
                              Text(
                                animal.text('speciesName'),
                                style: const TextStyle(color: muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FarmInfoCard(
                    child: Column(
                      children: [
                        const FarmStatusBadge(
                          label: 'Quét là mở hồ sơ',
                          icon: Icons.qr_code_2,
                          tone: FarmBadgeTone.info,
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (_, constraints) => Center(
                            child: QrImageView(
                              key: const ValueKey('animal-qr-image'),
                              data: animalQrData(animal.id),
                              size: constraints.maxWidth.clamp(0, 300),
                              padding: const EdgeInsets.all(24),
                              backgroundColor: Colors.white,
                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                              semanticsLabel:
                                  'Mã QR vật nuôi ${animal.text('code')}',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          animal.text('code'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Mã vẫn dùng được khi đổi tên hoặc chuyển chuồng. Quét bằng Smart Farm để xem thông tin mới nhất.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (error != null) ...[
                    FeedbackBox(error!),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                    key: const ValueKey('qr-share-pdf'),
                    onPressed: busy ? null : () => export(print: false),
                    icon: const Icon(Icons.ios_share),
                    label: Text(busy ? 'Đang chuẩn bị…' : 'Lưu / chia sẻ PDF'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('qr-print'),
                    onPressed: busy ? null : () => export(print: true),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('In thẻ QR'),
                  ),
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            await Clipboard.setData(
                              ClipboardData(text: animalQrData(animal.id)),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã sao chép nội dung QR.'),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Sao chép nội dung mã'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Người quét vẫn cần đăng nhập và có quyền xem vật nuôi của trang trại.',
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
}
