import 'dart:convert';

import '../../core/photo_picker.dart';

import 'package:flutter/material.dart';

import 'auth_repository.dart';

Future<String?> pickUserAvatar() async {
  final bytes = await pickPhotoForUpload();
  return bytes == null ? null : base64Encode(bytes);
}

class UserAvatar extends StatelessWidget {
  final FarmUser user;
  final double radius;
  const UserAvatar({super.key, required this.user, this.radius = 24});
  @override
  Widget build(BuildContext context) {
    Widget fallback() => CircleAvatar(
      radius: radius,
      child: Icon(
        user.isAdmin
            ? Icons.admin_panel_settings_outlined
            : Icons.person_outline,
      ),
    );
    final data = user.avatarData;
    if (data == null || data.isEmpty) return fallback();
    try {
      final bytes = base64Decode(data.split(',').last);
      return Semantics(
        label: 'Ảnh đại diện ${user.name}',
        child: ClipOval(
          child: Image.memory(
            bytes,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback(),
          ),
        ),
      );
    } on FormatException {
      return Tooltip(message: 'Ảnh đại diện không hợp lệ', child: fallback());
    }
  }
}
