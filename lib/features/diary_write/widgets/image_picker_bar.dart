import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../services/image_service.dart';

class ImagePickerBar extends StatefulWidget {
  final ValueChanged<String> onImagePicked;

  const ImagePickerBar({super.key, required this.onImagePicked});

  static Future<String?> pickFromCamera() => _pickImage(ImageSource.camera);
  static Future<String?> pickFromGallery() => _pickImage(ImageSource.gallery);

  static Future<String?> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: source, maxWidth: 1200, imageQuality: 85);
    if (picked == null) return null;
    return ImageService.saveImage(File(picked.path));
  }

  @override
  State<ImagePickerBar> createState() => _ImagePickerBarState();
}

class _ImagePickerBarState extends State<ImagePickerBar> {
  Future<void> _pickImage(ImageSource source) async {
    final path = await ImagePickerBar._pickImage(source);
    if (path != null && mounted) {
      widget.onImagePicked(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _pickImage(ImageSource.camera),
          icon: Icon(Icons.camera_alt_outlined, size: 20, color: goldColor),
          tooltip: '拍照',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: () => _pickImage(ImageSource.gallery),
          icon: Icon(Icons.image_outlined, size: 20, color: goldColor),
          tooltip: '相册',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}
