import 'dart:convert';

import 'package:flutter/material.dart';

class PhotoView extends StatelessWidget {
  final String data;
  final double size;
  final IconData fallback;
  final Widget? fallbackWidget;
  final String label;
  const PhotoView({
    super.key,
    required this.data,
    this.size = 48,
    this.fallback = Icons.pets_outlined,
    this.fallbackWidget,
    this.label = 'Ảnh vật nuôi',
  });

  @override
  Widget build(BuildContext context) {
    Widget placeholder() =>
        fallbackWidget ??
        ColoredBox(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Center(
            child: Icon(
              fallback,
              size: size * .45,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        );
    Widget content = placeholder();
    if (data.isNotEmpty) {
      try {
        content = Image.memory(
          base64Decode(data.split(',').last),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => placeholder(),
        );
      } on FormatException {
        content = Tooltip(message: 'Ảnh không hợp lệ', child: placeholder());
      }
    }
    return Semantics(
      label: label,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: content,
        ),
      ),
    );
  }
}
