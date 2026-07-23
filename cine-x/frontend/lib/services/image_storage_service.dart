import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/theme/app_theme.dart';

class ImageStorageService {
  const ImageStorageService();

  Future<String> copyPickedImage(
    XFile file, {
    required String folder,
    String? oldImagePath,
  }) async {
    if (kIsWeb) return file.path;
    final documents = await getApplicationDocumentsDirectory();
    final imageDir = Directory(p.join(documents.path, 'cine_x_images', folder));
    await imageDir.create(recursive: true);

    final extension = p.extension(file.name).isEmpty
        ? '.jpg'
        : p.extension(file.name).toLowerCase();
    final filename =
        '${DateTime.now().microsecondsSinceEpoch}_${file.name.hashCode.abs()}$extension';
    final targetPath = p.join(imageDir.path, filename);
    await File(file.path).copy(targetPath);

    return targetPath;
  }

  Future<void> deleteIfAppOwned(String imagePath) async {
    if (kIsWeb) return;
    final documents = await getApplicationDocumentsDirectory();
    final appImageRoot = p.join(documents.path, 'cine_x_images');
    final normalized = p.normalize(imagePath);
    if (!p.isWithin(appImageRoot, normalized)) return;
    final file = File(normalized);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class SafeLocalImage extends StatelessWidget {
  const SafeLocalImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.image_rounded,
  });

  final String? path;
  final BoxFit fit;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final imagePath = path?.trim();
    if (imagePath == null || imagePath.isEmpty) {
      return _ImagePlaceholder(icon: placeholderIcon);
    }
    if (kIsWeb) {
      return Image.network(
        imagePath,
        fit: fit,
        errorBuilder: (_, __, ___) =>
            _ImagePlaceholder(icon: placeholderIcon),
      );
    }
    final file = File(imagePath);
    if (!file.existsSync()) {
      return const _ImagePlaceholder(icon: Icons.broken_image_rounded);
    }
    return Image.file(
      file,
      fit: fit,
      errorBuilder: (_, __, ___) =>
          const _ImagePlaceholder(icon: Icons.broken_image_rounded),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CineXPalette.surface,
            CineXPalette.card,
            Color(0xFF293241),
          ],
        ),
      ),
      child: Center(
        child: Icon(icon, color: CineXPalette.textSecondary, size: 42),
      ),
    );
  }
}
