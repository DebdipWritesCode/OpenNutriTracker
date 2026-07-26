import 'dart:typed_data';

import 'package:equatable/equatable.dart';

class AiMealPhoto extends Equatable {
  final String path;
  final Uint8List bytes;
  final String mimeType;
  final String fileName;

  const AiMealPhoto({
    required this.path,
    required this.bytes,
    required this.mimeType,
    required this.fileName,
  });

  @override
  List<Object?> get props => [path, bytes.length, mimeType, fileName];
}
