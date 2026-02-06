import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../models/issue_image_info.dart';

/// 上传链接数据（用于显示链接菜单）
class UploadLinkData {
  final String imageUrl;
  final String? videoUrl;
  final String markdown;

  UploadLinkData({
    required this.imageUrl,
    this.videoUrl,
    required this.markdown,
  });
}

/// 图片预览对话框
class ImagePreviewDialog extends StatefulWidget {
  final List<IssueImageInfo> images;
  final int initialIndex;
  final UploadLinkData? uploadLinkData; // 可选的上传链接数据

  const ImagePreviewDialog({
    Key? key,
    required this.images,
    this.initialIndex = 0,
    this.uploadLinkData,
  }) : super(key: key);

  @override
  State<ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<ImagePreviewDialog> {
  late int _currentIndex;
  bool _showLinksMenu = false; // 链接菜单显示状态
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // 隐藏状态栏，实现全屏沉浸式体验
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    _pageController.dispose();

    // 恢复状态栏显示
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero), // 无圆角
      child: Stack(
        children: [
          // 图片轮播 - 使用 PhotoViewGallery 解决手势冲突和缩放重置
          PhotoViewGallery.builder(
            pageController: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            builder: (context, index) {
              final image = widget.images[index];
              return PhotoViewGalleryPageOptions.customChild(
                child: _ImagePreviewItem(
                  key: ValueKey(image.url),
                  image: image,
                ),
                minScale: PhotoViewComputedScale.contained * 0.8,
                maxScale: PhotoViewComputedScale.covered * 2.0,
                initialScale: PhotoViewComputedScale.contained,
              );
            },
            scrollPhysics: const BouncingScrollPhysics(),
            backgroundDecoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),

          // 顶部关闭按钮和页码指示器
          Positioned(
            top: 8, // 状态栏已隐藏，无需额外 padding
            left: 0,
            right: 0,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.images.length}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // 链接菜单按钮（仅在有上传链接数据时显示）
                if (widget.uploadLinkData != null)
                  IconButton(
                    icon: Icon(
                      _showLinksMenu ? Icons.expand_less : Icons.link,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _showLinksMenu = !_showLinksMenu;
                      });
                    },
                  ),
                if (widget.uploadLinkData == null) SizedBox(width: 16),
              ],
            ),
          ),

          // 链接菜单（下拉展示）
          if (_showLinksMenu && widget.uploadLinkData != null)
            Positioned(
              top: 60,
              right: 8,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 图片链接
                    _buildLinkRow(
                      icon: Icons.image,
                      label: '图片链接',
                      url: widget.uploadLinkData!.imageUrl,
                    ),
                    // 视频链接（如果有）
                    if (widget.uploadLinkData!.videoUrl != null &&
                        widget.uploadLinkData!.videoUrl!.isNotEmpty) ...[
                      const Divider(color: Colors.white24, height: 20),
                      _buildLinkRow(
                        icon: Icons.videocam,
                        label: 'Live 视频',
                        url: widget.uploadLinkData!.videoUrl!,
                      ),
                    ],
                    const Divider(color: Colors.white24, height: 20),
                    // Markdown
                    _buildLinkRow(
                      icon: Icons.code,
                      label: 'Markdown',
                      url: widget.uploadLinkData!.markdown,
                    ),
                  ],
                ),
              ),
            ),

        ],
      ),
    );
  }

  /// 构建单个链接行
  Widget _buildLinkRow({
    required IconData icon,
    required String label,
    required String url,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _copyToClipboard(url),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    url,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.copy, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 复制到剪贴板
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制到剪贴板'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

/// 单张图片预览组件（复用 photo_preview_page 的实现）
class _ImagePreviewItem extends StatefulWidget {
  final IssueImageInfo image;

  const _ImagePreviewItem({
    Key? key,
    required this.image,
  }) : super(key: key);

  @override
  State<_ImagePreviewItem> createState() => _ImagePreviewItemState();
}

class _ImagePreviewItemState extends State<_ImagePreviewItem> {
  VideoPlayerController? _videoController;
  bool _isPlayingVideo = false;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  /// 长按播放视频
  Future<void> _playVideo() async {
    if (widget.image.liveVideo == null || widget.image.liveVideo!.isEmpty) {
      return;
    }

    if (_videoController != null) {
      await _videoController!.dispose();
    }

    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.image.liveVideo!),
    );
    await _videoController!.initialize();

    setState(() {
      _isPlayingVideo = true;
    });

    await _videoController!.play();

    _videoController!.addListener(() {
      if (_videoController!.value.position >= _videoController!.value.duration) {
        _stopVideo();
      }
    });
  }

  /// 停止播放视频
  void _stopVideo() {
    if (_videoController != null) {
      _videoController!.pause();
      _videoController!.seekTo(Duration.zero);
      if (mounted) {
        setState(() {
          _isPlayingVideo = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLivePhoto = widget.image.liveVideo != null && widget.image.liveVideo!.isNotEmpty;

    return GestureDetector(
      onLongPress: isLivePhoto ? _playVideo : null,
      onLongPressEnd: (_) => _stopVideo(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 图片 - PhotoViewGallery 已提供缩放，这里只显示图片
          if (!_isPlayingVideo)
            CachedNetworkImage(
              imageUrl: widget.image.url,
              fit: BoxFit.contain,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorWidget: (context, url, error) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white, size: 64),
              ),
            ),

          // 视频播放器
          if (_isPlayingVideo && _videoController != null && _videoController!.value.isInitialized)
            GestureDetector(
              onTap: _stopVideo,
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            ),

          // Live 标识
          if (isLivePhoto && !_isPlayingVideo)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.album, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
