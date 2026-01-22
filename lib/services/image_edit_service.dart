import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:photo_manager/photo_manager.dart';
import '../models/edited_image.dart';

/// 图片编辑服务
/// 管理编辑后的图片临时文件，提供获取最终图片的接口
class ImageEditService {
  ImageEditService._();
  static final instance = ImageEditService._();

  /// 存储编辑后的图片映射：assetId → EditedImage
  final Map<String, EditedImage> _editedImages = {};

  /// 保存编辑后的图片到临时目录
  ///
  /// [assetId] 原始 AssetEntity 的 ID
  /// [bytes] 编辑后的图片字节数据
  /// [isLivePhoto] 原始图片是否为 live photo
  /// [originalFilePath] 原始文件路径（用于提取 live video）
  /// 返回保存后的临时文件
  Future<File> saveEditedImage(
    String assetId,
    Uint8List bytes, {
    bool isLivePhoto = false,
    String? originalFilePath,
  }) async {
    try {
      // 获取应用临时目录
      final tempDir = await getTemporaryDirectory();

      // 创建编辑图片子目录
      final editedDir = Directory(path.join(tempDir.path, 'edited_images'));
      if (!await editedDir.exists()) {
        await editedDir.create(recursive: true);
      }

      // 如果已经有编辑版本，先删除旧文件
      if (_editedImages.containsKey(assetId)) {
        final oldFile = _editedImages[assetId]!.editedFile;
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      }

      // 生成新文件名（使用时间戳确保唯一性）
      final fileName = '${assetId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = path.join(editedDir.path, fileName);

      // 写入文件
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // 保存到映射
      final editedImage = EditedImage(
        assetId: assetId,
        editedFile: file,
        editedAt: DateTime.now(),
        isLivePhoto: isLivePhoto,
        originalFilePath: originalFilePath,
      );
      _editedImages[assetId] = editedImage;

      print('✅ 图片编辑已保存: $filePath');
      if (isLivePhoto) {
        print('  📹 原始图片为 live photo，已保存原始路径: $originalFilePath');
      }
      return file;
    } catch (e) {
      print('❌ 保存编辑图片失败: $e');
      rethrow;
    }
  }

  /// 获取最终图片文件
  ///
  /// 优先返回编辑后的文件，如果没有编辑则返回原始文件
  /// [asset] 原始 AssetEntity
  /// 返回最终要使用的文件
  Future<File?> getFinalFile(AssetEntity asset) async {
    // 1. 检查是否有编辑版本
    if (_editedImages.containsKey(asset.id)) {
      final editedImage = _editedImages[asset.id]!;

      // 确保文件仍然存在
      if (await editedImage.editedFile.exists()) {
        print('📝 使用编辑后的图片: ${editedImage.editedFile.path}');
        return editedImage.editedFile;
      } else {
        // 文件不存在，从映射中移除
        _editedImages.remove(asset.id);
        print('⚠️ 编辑文件不存在，使用原始图片');
      }
    }

    // 2. 返回原始文件
    final originalFile = await asset.file;
    if (originalFile != null) {
      print('📷 使用原始图片: ${originalFile.path}');
    }
    return originalFile;
  }

  /// 检查图片是否已编辑
  ///
  /// [assetId] AssetEntity 的 ID
  /// 返回是否已编辑
  bool isEdited(String assetId) {
    return _editedImages.containsKey(assetId);
  }

  /// 获取编辑信息
  ///
  /// [assetId] AssetEntity 的 ID
  /// 返回编辑信息，如果未编辑则返回 null
  EditedImage? getEditedInfo(String assetId) {
    return _editedImages[assetId];
  }

  /// 清理单个编辑图片
  ///
  /// [assetId] 要清理的 AssetEntity ID
  Future<void> clearEditedImage(String assetId) async {
    if (_editedImages.containsKey(assetId)) {
      final editedImage = _editedImages[assetId]!;

      try {
        if (await editedImage.editedFile.exists()) {
          await editedImage.editedFile.delete();
          print('🗑️ 已删除编辑文件: ${editedImage.editedFile.path}');
        }
      } catch (e) {
        print('⚠️ 删除编辑文件失败: $e');
      }

      _editedImages.remove(assetId);
    }
  }

  /// 清理所有编辑图片
  ///
  /// 通常在取消选择或页面销毁时调用
  Future<void> clearAll() async {
    final assetIds = _editedImages.keys.toList();

    for (final assetId in assetIds) {
      await clearEditedImage(assetId);
    }

    print('🗑️ 已清理所有编辑图片 (${assetIds.length} 个)');
  }

  /// 清理所有临时文件（包括旧的遗留文件）
  ///
  /// 可以在应用启动时调用，清理上次未正常清理的文件
  Future<void> cleanupAllTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final editedDir = Directory(path.join(tempDir.path, 'edited_images'));

      if (await editedDir.exists()) {
        await editedDir.delete(recursive: true);
        print('🗑️ 已清理所有临时编辑文件');
      }
    } catch (e) {
      print('⚠️ 清理临时文件失败: $e');
    }
  }

  /// 销毁服务（清理资源）
  Future<void> dispose() async {
    await clearAll();
  }

  /// 获取已编辑图片数量
  int get editedCount => _editedImages.length;

  /// 获取所有已编辑的 AssetId 列表
  List<String> get editedAssetIds => _editedImages.keys.toList();
}
