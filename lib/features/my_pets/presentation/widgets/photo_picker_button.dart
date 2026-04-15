import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PhotoPickerButton extends StatelessWidget {
  final File? currentPhoto;
  final String? currentPhotoUrl;
  final ValueChanged<File> onPhotoPicked;

  const PhotoPickerButton({
    super.key,
    this.currentPhoto,
    this.currentPhotoUrl,
    required this.onPhotoPicked,
  });

  Future<void> _pickImage(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text('media_from_camera'.tr()),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text('media_from_gallery'.tr()),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );

    if (image != null) {
      onPhotoPicked(File(image.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _pickImage(context),
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: _buildContent(colorScheme),
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    if (currentPhoto != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(currentPhoto!, fit: BoxFit.cover),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.surface.withValues(alpha: 0.8),
              child: Icon(Icons.edit, size: 16, color: colorScheme.primary),
            ),
          ),
        ],
      );
    }

    if (currentPhotoUrl != null && currentPhotoUrl!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              currentPhotoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholder(colorScheme),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.surface.withValues(alpha: 0.8),
              child: Icon(Icons.edit, size: 16, color: colorScheme.primary),
            ),
          ),
        ],
      );
    }

    return _buildPlaceholder(colorScheme);
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo, size: 40, color: colorScheme.onSurfaceVariant),
        const SizedBox(height: 8),
        Text(
          'media_add_photo'.tr(),
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
