import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:thumbhash/thumbhash.dart' as th;
import 'dart:convert';
import '../models/issue_image_info.dart';

/// 九宫格图片预览组件
class ImageGridPreview extends StatelessWidget {
  final List<IssueImageInfo> images;
  final VoidCallback? onTap;

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
    } else if (imageCount <= 4) {
      return _buildGrid2x2(context, images);
    } else {
      return _buildGrid3x3(context, images.take(9).toList(), imageCount);
    }
  }

  /// 单张图片（16:9 横向大图）
  Widget _buildSingleImage(BuildContext context, IssueImageInfo image) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _buildImageWidget(image),
        ),
      ),
    );
  }

  /// 2x2 网格
  Widget _buildGrid2x2(BuildContext context, List<IssueImageInfo> images) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: images.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: onTap,
            child: _buildImageWidget(images[index]),
          );
        },
      ),
    );
  }

  /// 3x3 网格
  Widget _buildGrid3x3(BuildContext context, List<IssueImageInfo> images, int totalCount) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 1,
        child: GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            final isLastItem = index == images.length - 1 && totalCount > 9;

            return GestureDetector(
              onTap: onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImageWidget(images[index]),

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
            );
          },
        ),
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
