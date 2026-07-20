import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_theme.dart';

/// Camera / gallery chooser. Uses the root navigator so it works on top of
/// the already-open post form sheet (nested sheets were silently failing).
Future<ImageSource?> showPhotoSourceSheet(
  BuildContext context, {
  Color? accent,
}) {
  final color = accent ?? AppColors.rose;
  return showDialog<ImageSource>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Add photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Take a new photo or choose one you already have.',
              style: Theme.of(
                dialogContext,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: .14),
                child: Icon(Icons.photo_camera_outlined, color: color),
              ),
              title: Text(
                'Take photo',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
              onTap: () =>
                  Navigator.of(dialogContext, rootNavigator: true).pop(
                    ImageSource.camera,
                  ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: .14),
                child: Icon(Icons.photo_library_outlined, color: color),
              ),
              title: Text(
                'Choose from gallery',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
              onTap: () =>
                  Navigator.of(dialogContext, rootNavigator: true).pop(
                    ImageSource.gallery,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(),
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );
}
