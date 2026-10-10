import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Reusable image surface. Missing/undecodable optional content keeps a placeholder.
class AppImage extends StatelessWidget {
  const AppImage({super.key, this.bytes, this.size = 96});
  final Uint8List? bytes;
  final double size;
  Widget _placeholder(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(Icons.image_outlined),
  );
  @override
  Widget build(BuildContext context) => bytes == null
      ? _placeholder(context)
      : ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => _placeholder(context),
          ),
        );
}
