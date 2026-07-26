import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:opennutritracker/features/ai_meal/domain/entity/ai_meal_photo.dart';

abstract interface class AiMealPhotoPicker {
  Future<AiMealPhoto?> pick(ImageSource source);
}

class AiMealPhotoPickerException implements Exception {
  final String message;

  const AiMealPhotoPickerException(this.message);

  @override
  String toString() => message;
}

class DeviceAiMealPhotoPicker implements AiMealPhotoPicker {
  static const maxImageBytes = 3_000_000;

  final ImagePicker _picker;

  DeviceAiMealPhotoPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  @override
  Future<AiMealPhoto?> pick(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (picked == null) return null;

    var bytes = await _compressJpeg(picked.path, quality: 80, dimension: 1600);
    bytes ??= await picked.readAsBytes();

    var mimeType = _detectMimeType(bytes);
    if (mimeType == null || bytes.length > maxImageBytes) {
      final smaller = await _compressJpeg(
        picked.path,
        quality: 58,
        dimension: 1200,
      );
      if (smaller != null) {
        bytes = smaller;
        mimeType = 'image/jpeg';
      }
    }

    mimeType ??= _detectMimeType(bytes);
    if (mimeType == null) {
      throw const AiMealPhotoPickerException(
        'Choose a JPEG, PNG, or WebP meal photo.',
      );
    }
    if (bytes.length > maxImageBytes) {
      throw const AiMealPhotoPickerException(
        'The meal photo is too large. Try taking it again from farther away.',
      );
    }

    return AiMealPhoto(
      path: picked.path,
      bytes: bytes,
      mimeType: mimeType,
      fileName: 'meal-photo.${_extensionFor(mimeType)}',
    );
  }

  Future<Uint8List?> _compressJpeg(
    String path, {
    required int quality,
    required int dimension,
  }) async {
    try {
      return await FlutterImageCompress.compressWithFile(
        path,
        minWidth: dimension,
        minHeight: dimension,
        quality: quality,
        format: CompressFormat.jpeg,
        autoCorrectionAngle: true,
      );
    } on Object catch (_) {
      return null;
    }
  }

  String? _detectMimeType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }

  static String _extensionFor(String mimeType) => switch (mimeType) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'jpg',
  };
}
