// QR contains only a stable identifier, never a token or profile data.
final _animalUuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

String animalQrData(String id) {
  if (!_animalUuid.hasMatch(id)) throw ArgumentError.value(id, 'id');
  return 'smartfarm://animal/v1/${id.toLowerCase()}';
}

String? animalIdFromQr(String raw) {
  if (raw.length > 256) return null;
  try {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.scheme != 'smartfarm' ||
        uri.host != 'animal' ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.pathSegments.length != 2 ||
        uri.pathSegments.first != 'v1') {
      return null;
    }
    final id = uri.pathSegments.last;
    return _animalUuid.hasMatch(id) ? id.toLowerCase() : null;
  } on FormatException {
    return null;
  }
}
