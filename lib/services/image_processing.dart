import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageProcessing {
  Future<File> convertToWebP(File imageFile) async {
    final dir = await getTemporaryDirectory();
    final targetPath = path.join(
        dir.path, '${path.basenameWithoutExtension(imageFile.path)}.webp');

    final result = await FlutterImageCompress.compressAndGetFile(
      imageFile.absolute.path,
      targetPath,
      format: CompressFormat.webp,
      quality: 90, // 调整质量参数以控制压缩率
    );

    if (result != null) {
      return File(result.path); // 将 XFile 转换为 File
    } else {
      throw Exception('Failed to convert image to WebP.');
    }
  }

  Future<File> convertToJpeg(File imageFile) async {
    final dir = await getTemporaryDirectory();
    final targetPath = path.join(
        dir.path, '${path.basenameWithoutExtension(imageFile.path)}.jpg');

    final result = await FlutterImageCompress.compressAndGetFile(
      imageFile.absolute.path,
      targetPath,
      format: CompressFormat.jpeg,
      quality: 90, // 调整质量参数以控制压缩率
    );

    if (result != null) {
      return File(result.path); // 将 XFile 转换为 File
    } else {
      throw Exception('Failed to convert image to JPEG.');
    }
  }
}
