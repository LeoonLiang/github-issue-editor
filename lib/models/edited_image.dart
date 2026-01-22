import 'dart:io';

/// 编辑后的图片数据模型
class EditedImage {
  /// 原始 AssetEntity 的 ID
  final String assetId;

  /// 编辑后的临时文件
  final File editedFile;

  /// 编辑时间
  final DateTime editedAt;

  /// 是否为 live photo
  final bool isLivePhoto;

  /// 原始文件路径（用于提取 live video）
  final String? originalFilePath;

  EditedImage({
    required this.assetId,
    required this.editedFile,
    required this.editedAt,
    this.isLivePhoto = false,
    this.originalFilePath,
  });

  /// 从 JSON 创建（用于持久化，可选功能）
  factory EditedImage.fromJson(Map<String, dynamic> json) {
    return EditedImage(
      assetId: json['assetId'] as String,
      editedFile: File(json['editedFilePath'] as String),
      editedAt: DateTime.parse(json['editedAt'] as String),
      isLivePhoto: json['isLivePhoto'] as bool? ?? false,
      originalFilePath: json['originalFilePath'] as String?,
    );
  }

  /// 转换为 JSON（用于持久化，可选功能）
  Map<String, dynamic> toJson() {
    return {
      'assetId': assetId,
      'editedFilePath': editedFile.path,
      'editedAt': editedAt.toIso8601String(),
      'isLivePhoto': isLivePhoto,
      'originalFilePath': originalFilePath,
    };
  }
}
