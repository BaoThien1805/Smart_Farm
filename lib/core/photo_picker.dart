import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';

import 'api_client.dart';

Future<Uint8List?> pickPhotoForUpload() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Ảnh JPEG/PNG',
        extensions: ['jpg', 'jpeg', 'png'],
        mimeTypes: ['image/jpeg', 'image/png'],
        uniformTypeIdentifiers: ['public.jpeg', 'public.png'],
      ),
    ],
  );
  if (file == null) return null;
  if (await file.length() > 12 * 1024 * 1024) {
    throw const ApiException('Hãy chọn ảnh JPEG/PNG nhỏ hơn 12 MB.');
  }
  return preparePhotoForUpload(await file.readAsBytes());
}

/// Bound decoded pixels and upload size before sending a camera photo.
Future<Uint8List> preparePhotoForUpload(Uint8List bytes) async {
  final jpeg =
      bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255;
  final png =
      bytes.length >= 8 &&
      bytes[0] == 137 &&
      bytes[1] == 80 &&
      bytes[2] == 78 &&
      bytes[3] == 71;
  if ((!jpeg && !png) || bytes.length > 12 * 1024 * 1024) {
    throw const ApiException('Ảnh phải là JPEG/PNG và nhỏ hơn 12 MB.');
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width * descriptor.height > 20000000) {
      throw const ApiException('Ảnh quá lớn. Hãy chọn ảnh dưới 20 megapixel.');
    }
    final longest = descriptor.width > descriptor.height
        ? descriptor.width
        : descriptor.height;
    final scale = longest > 400 ? 400 / longest : 1.0;
    codec = await descriptor.instantiateCodec(
      targetWidth: (descriptor.width * scale).round().clamp(1, 400),
      targetHeight: (descriptor.height * scale).round().clamp(1, 400),
    );
    image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null || data.lengthInBytes > 1024 * 1024) {
      throw const ApiException('Không xử lý được ảnh. Hãy chọn ảnh khác.');
    }
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } on ApiException {
    rethrow;
  } catch (_) {
    throw const ApiException('Ảnh không đọc được. Hãy chọn lại ảnh JPEG/PNG.');
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}
