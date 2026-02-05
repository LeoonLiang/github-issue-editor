import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:thumbhash/thumbhash.dart' as th;
import 'dart:convert';
import '../models/issue_image_info.dart';

/// 九宫格图片预览组件
class ImageGridPreview extends StatelessWidget {
  final List<IssueImageInfo> images;
  final Function(int)? onTap;

  const ImageGridPreview({
    Key? key,
    required this.images,
    this.onTap,
  }) : super(key: key);

  /// 从 Markdown 解析图片信息
  static List<IssueImageInfo> parseImagesFromMarkdown(String markdown) {
    if (markdown.isEmpty) return [];

    final List<IssueImageInfo> images = [];

    // 正则表达式匹配：![image](url){...}
    final RegExp imageRegex = RegExp(
      r'!\[image\]\((https?://[^\)]+)\)\{([^\}]+)\}',
      multiLine: true,
    );

    final matches = imageRegex.allMatches(markdown);

    for (final match in matches) {
      final url = match.group(1);
      final metadata = match.group(2);

      if (url == null || metadata == null) continue;

      // 解析元数据
      String? thumbhash;
      int? width;
      int? height;
      String? liveVideo;

      // 匹配 thumbhash
      final thumbhashMatch = RegExp(r'thumbhash="([^"]+)"').firstMatch(metadata);
      if (thumbhashMatch != null) {
        thumbhash = thumbhashMatch.group(1);
      }

      // 匹配 width
      final widthMatch = RegExp(r'width=(\d+)').firstMatch(metadata);
      if (widthMatch != null) {
        width = int.tryParse(widthMatch.group(1) ?? '');
      }

      // 匹配 height
      final heightMatch = RegExp(r'height=(\d+)').firstMatch(metadata);
      if (heightMatch != null) {
        height = int.tryParse(heightMatch.group(1) ?? '');
      }

      // 匹配 liveVideo
      final liveVideoMatch = RegExp(r'liveVideo="([^"]+)"').firstMatch(metadata);
      if (liveVideoMatch != null) {
        liveVideo = liveVideoMatch.group(1);
      }

      images.add(IssueImageInfo(
        url: url,
        thumbhash: thumbhash,
        width: width,
        height: height,
        liveVideo: liveVideo,
      ));
    }

    return images;
  }

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return SizedBox.shrink();

    final imageCount = images.length;

    if (imageCount == 1) {
      return _buildSingleImage(context, images[0]);
    } else {
      return _buildImageGrid(context, images, imageCount);
    }
  }

  /// 单张图片（自适应比例）
  Widget _buildSingleImage(BuildContext context, IssueImageInfo image) {
    return GestureDetector(
      onTap: () => onTap?.call(0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width - 32, // 左右各16的padding
            maxHeight: 300, // 最大高度限制
          ),
          child: CachedNetworkImage(
            imageUrl: image.url,
            fit: BoxFit.contain, // 保持比例，不裁剪
            placeholder: (context, url) {
              return Container(
                color: Colors.grey[300],
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[300],
              child: Icon(Icons.broken_image, color: Colors.grey[600]),
            ),
          ),
        ),
      ),
    );
  }

  /// 图片网格（2列或3列）
  Widget _buildImageGrid(BuildContext context, List<IssueImageInfo> images, int totalCount) {
    final displayImages = images.take(9).toList();
    final count = displayImages.length;
    final column = count <= 4 ? 2 : 3;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final spacing = 2.0;
          final size = (width - spacing * (column - 1)) / column;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: List.generate(count, (i) {
              final isLastItem = i == count - 1 && totalCount > 9;

              return SizedBox(
                width: size,
                height: size,
                child: GestureDetector(
                  onTap: () => onTap?.call(i),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImageWidget(displayImages[i]),

                      // 显示 "+N" 蒙层
                      if (isLastItem)
                        Container(
                          color: Colors.black.withOpacity(0.6),
                          child: Center(
                            child: Text(
                              '+${totalCount - 9}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  /// 构建单个图片 Widget（支持 ThumbHash 占位符）
  Widget _buildImageWidget(IssueImageInfo image) {
    return CachedNetworkImage(
      imageUrl: image.url,
      fit: BoxFit.cover,
      placeholder: (context, url) {
        // 使用 ThumbHash 作为占位符
        if (image.thumbhash != null && image.thumbhash!.isNotEmpty) {
          return _buildThumbHashPlaceholder(image.thumbhash!);
        }
        return Container(
          color: Colors.grey[300],
          child: Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[300],
        child: Icon(Icons.broken_image, color: Colors.grey[600]),
      ),
    );
  }

  /// 构建 ThumbHash 占位符
  Widget _buildThumbHashPlaceholder(String thumbhashBase64) {
    // 暂时使用灰色占位符，ThumbHash 功能待优化
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
