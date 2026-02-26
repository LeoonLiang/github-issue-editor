import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// 快速检测 Motion Photo — 只读前 64KB XMP 元数据，不解析整个文件
/// 比 MotionPhotos(path).isMotionPhoto() 快一个数量级
Future<bool> isMotionPhotoFast(File file) async {
  try {
    final bytes = await file.openRead(0, 64 * 1024).toList();
    final data = Uint8List.fromList(bytes.expand((e) => e).toList());
    final content = utf8.decode(data, allowMalformed: true);

    const xmpStart = '<x:xmpmeta';
    const xmpEnd = '</x:xmpmeta>';
    final startIndex = content.indexOf(xmpStart);
    if (startIndex == -1) return false;
    final endIndex = content.indexOf(xmpEnd, startIndex);
    if (endIndex == -1) return false;

    final xmpData = content.substring(startIndex, endIndex + xmpEnd.length);
    return xmpData.contains('Camera:MotionPhoto') ||
        xmpData.contains('GContainer:ItemLength');
  } catch (_) {
    return false;
  }
}
