import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../models/issue_image_info.dart';

/// 图片预览对话框
class ImagePreviewDialog extends StatefulWidget {
  final List<IssueImageInfo> images;
  final int initialIndex;

  const ImagePreviewDialog({
    Key? key,
    required this.images,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<ImagePreviewDialog> {
  late PageController _pageController;
  late int _currentIndex;
  VideoPlayerController? _videoController;
  bool _isPlayingLive = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _initializeVideoForCurrentImage();

    // 隐藏状态栏，实现全屏沉浸式体验
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose();

    // 恢复状态栏显示
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );

    super.dispose();
  }

  /// 初始化当前图片的视频（如果有 Live Photo）
  void _initializeVideoForCurrentImage() {
    _videoController?.dispose();
    _videoController = null;
    _isPlayingLive = false;

    final currentImage = widget.images[_currentIndex];
    if (currentImage.liveVideo != null && currentImage.liveVideo!.isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(currentImage.liveVideo!),
      )..initialize().then((_) {
          if (mounted) {
            setState(() {});
          }
        });
    }
  }

  /// 切换 Live Photo 播放
  void _toggleLivePhoto() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return;
    }

    setState(() {
      if (_isPlayingLive) {
        _videoController!.pause();
        _videoController!.seekTo(Duration.zero);
        _isPlayingLive = false;
      } else {
        _videoController!.play();
        _isPlayingLive = true;
      }
    });

    // 视频播放完成后自动回到图片
    _videoController!.addListener(() {
      if (_videoController!.value.position >= _videoController!.value.duration) {
        if (mounted) {
          setState(() {
            _videoController!.seekTo(Duration.zero);
            _videoController!.pause();
            _isPlayingLive = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero), // 无圆角
      child: Stack(
        children: [
          // 图片轮播
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                _initializeVideoForCurrentImage();
              });
            },
            itemBuilder: (context, index) {
              return _buildImagePage(widget.images[index]);
            },
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
                SizedBox(width: 16),
              ],
            ),
          ),

          // Live Photo 按钮
          if (widget.images[_currentIndex].liveVideo != null &&
              widget.images[_currentIndex].liveVideo!.isNotEmpty)
            Positioned(
              bottom: 32, // 底部导航栏已隐藏，无需额外 padding
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: _toggleLivePhoto,
                  icon: Icon(_isPlayingLive ? Icons.pause : Icons.play_arrow),
                  label: Text(_isPlayingLive ? '暂停 Live' : '播放 Live'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.9),
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建单个图片页面
  Widget _buildImagePage(IssueImageInfo image) {
    return GestureDetector(
      onTap: () {
        // 如果有 Live Photo，点击播放/暂停
        if (image.liveVideo != null && image.liveVideo!.isNotEmpty) {
          _toggleLivePhoto();
        }
      },
      child: Center(
        child: Stack(
          children: [
            // 静态图片
            if (!_isPlayingLive)
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: image.url,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => Center(
                    child: Icon(Icons.broken_image, color: Colors.white, size: 64),
                  ),
                ),
              ),

            // Live Photo 视频
            if (_isPlayingLive &&
                _videoController != null &&
                _videoController!.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              ),

            // Live 标识
            if (image.liveVideo != null &&
                image.liveVideo!.isNotEmpty &&
                !_isPlayingLive)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
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
      ),
    );
  }
}
