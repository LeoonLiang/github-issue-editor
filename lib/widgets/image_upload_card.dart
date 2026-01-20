import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/upload_models.dart';

/// 单张图片上传卡片
class ImageUploadCard extends StatelessWidget {
  final ImageUploadState uploadState;
  final VoidCallback onDelete;
  final VoidCallback? onRetry;
  final VoidCallback? onTap;

  const ImageUploadCard({
    Key? key,
    required this.uploadState,
    required this.onDelete,
    this.onRetry,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // 主容器
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: uploadState.isFailed
                  ? Border.all(color: Colors.red, width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: _buildImageContent(context),
              ),
            ),
          ),

          // 上传进度覆盖层
          if (uploadState.isUploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        value: uploadState.progress,
                        strokeWidth: 3,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        backgroundColor: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(uploadState.progress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 删除按钮
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),

          // 实况照片标记 - 显示是实况还是静态
          if (uploadState.isLivePhoto)
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      uploadState.enableLiveVideo ? Icons.album : Icons.image,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      uploadState.enableLiveVideo ? 'Live' : '静态',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 成功标记
          if (uploadState.isSuccess)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),

          // 失败状态 - 重试按钮
          if (uploadState.isFailed)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      if (onRetry != null)
                        ElevatedButton(
                          onPressed: onRetry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          child: const Text('重试'),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // 等待状态
          if (uploadState.status == UploadStatus.pending)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '等待中...',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建图片内容
  Widget _buildImageContent(BuildContext context) {
    // 如果是视频，显示视频占位符
    if (uploadState.isVideo) {
      return Container(
        color: Colors.grey[800],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam,
                color: Colors.white,
                size: 40,
              ),
              const SizedBox(height: 4),
              Text(
                '视频',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 如果已成功上传，显示网络图片
    if (uploadState.isSuccess && uploadState.thumbnailUrl != null) {
      return CachedNetworkImage(
        imageUrl: uploadState.thumbnailUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[300],
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[300],
          child: const Icon(Icons.error, color: Colors.red),
        ),
      );
    }

    // 否则显示本地文件
    return Image.file(
      File(uploadState.file.path),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        );
      },
    );
  }
}
