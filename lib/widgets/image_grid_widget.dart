import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reorderables/reorderables.dart';
import 'package:video_player/video_player.dart';
import '../models/upload_models.dart';
import '../providers/upload_provider.dart';
import '../screens/custom_image_picker.dart';
import 'image_upload_card.dart';

/// 图片网格展示组件
class ImageGridWidget extends ConsumerWidget {
  ImageGridWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadStates = ref.watch(uploadQueueProvider);
    final uploadNotifier = ref.read(uploadQueueProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (uploadStates.isNotEmpty) ...[
          ReorderableWrap(
            spacing: 8,
            runSpacing: 8,
            onReorder: (oldIndex, newIndex) {
              // 由于添加按钮在第一个位置，需要调整索引
              uploadNotifier.reorderImages(oldIndex - 1, newIndex - 1);
            },
            children: [
              // 添加图片按钮放在第一个
              Container(
                key: const ValueKey('add_button'),
                width: (MediaQuery.of(context).size.width - 32) / 3 - 8,
                child: _buildAddButton(context, ref, uploadStates.length),
              ),
              // 已上传的图片
              ...uploadStates.map((uploadState) {
                return Container(
                  key: ValueKey(uploadState.id),
                  width: (MediaQuery.of(context).size.width - 32) / 3 - 8,
                  child: ImageUploadCard(
                    uploadState: uploadState,
                    onDelete: () {
                      _showDeleteConfirmDialog(
                        context,
                        () => uploadNotifier.removeImage(uploadState.id),
                      );
                    },
                    onRetry: uploadState.canRetry
                        ? () => uploadNotifier.retryUpload(uploadState.id)
                        : null,
                    onTap: () {
                      if (uploadState.isSuccess) {
                        _showImagePreview(context, uploadState);
                      } else if (uploadState.isFailed) {
                        _showErrorDialog(context, uploadState);
                      }
                    },
                  ),
                );
              }).toList(),
            ],
          ),
        ] else
          // 空状态 - 首次添加按钮
          Align(
            alignment: Alignment.centerLeft,
            child: _buildAddButton(context, ref, 0),
          ),
      ],
    );
  }

  /// 构建添加按钮
  Widget _buildAddButton(BuildContext context, WidgetRef ref, int currentCount) {
    final size = (MediaQuery.of(context).size.width - 32) / 3 - 8;

    return GestureDetector(
      onTap: () => _pickImages(context, ref, currentCount),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            Icons.add,
            size: 32,
            color: const Color(0xFFBBBBBB),
          ),
        ),
      ),
    );
  }

  /// 选择图片 - 使用自定义选择器
  Future<void> _pickImages(BuildContext context, WidgetRef ref, int currentCount) async {
    final uploadNotifier = ref.read(uploadQueueProvider.notifier);

    // 不限制数量
    // 打开自定义图片选择器
    final List<SelectedImageInfo>? images = await Navigator.push<List<SelectedImageInfo>>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomImagePicker(
          maxCount: 9999, // 不限制
          alreadySelectedCount: currentCount,
        ),
      ),
    );

    if (images == null || images.isEmpty) return;

    await uploadNotifier.addImagesWithLiveOptions(images);
  }

  /// 显示删除确认对话框
  void _showDeleteConfirmDialog(BuildContext context, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: const Text('确定要删除这张图片吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  /// 显示错误详情对话框
  void _showErrorDialog(BuildContext context, ImageUploadState uploadState) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 8),
              const Text('上传失败'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '错误详情:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  uploadState.error ?? '未知错误',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 16),
                const Text(
                  '可能的原因:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '• 没有启用的OSS配置\n'
                  '• OSS配置信息不正确\n'
                  '• 网络连接问题\n'
                  '• 权限不足',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // 跳转到设置页
                final controller = DefaultTabController.of(context);
                if (controller != null) {
                  controller.animateTo(2);
                }
              },
              child: const Text('前往设置'),
            ),
          ],
        );
      },
    );
  }

  /// 显示图片预览
  void _showImagePreview(BuildContext context, ImageUploadState uploadState) {
    if (uploadState.result == null) return;

    showDialog(
      context: context,
      builder: (context) => _ImagePreviewDialog(uploadState: uploadState),
    );
  }

  /// 显示实况视频预览
  void _showLiveVideoPreview(BuildContext context, ImageUploadState uploadState) {
    if (uploadState.result == null || uploadState.result!.videoUrl.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => _LiveVideoPreviewDialog(uploadState: uploadState),
    );
  }

  /// 复制到剪贴板
  void _copyToClipboard(BuildContext context, String text) {
    // 使用 Clipboard
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制到剪贴板'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

/// 图片/视频预览对话框
class _ImagePreviewDialog extends StatefulWidget {
  final ImageUploadState uploadState;

  const _ImagePreviewDialog({
    Key? key,
    required this.uploadState,
  }) : super(key: key);

  @override
  State<_ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<_ImagePreviewDialog> {
  VideoPlayerController? _videoController;
  bool _isPlaying = false;
  bool _isInitializing = false;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _playVideo() async {
    if (_isInitializing) return;

    setState(() {
      _isInitializing = true;
    });

    try {
      if (_videoController != null) {
        await _videoController!.dispose();
      }

      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.uploadState.result!.imageUrl),
      );

      await _videoController!.initialize();

      setState(() {
        _isPlaying = true;
        _isInitializing = false;
      });

      await _videoController!.play();

      _videoController!.addListener(() {
        if (_videoController!.value.position >= _videoController!.value.duration) {
          _stopVideo();
        }
      });
    } catch (e) {
      print('Error playing video: $e');
      setState(() {
        _isInitializing = false;
      });
    }
  }

  void _stopVideo() {
    if (_videoController != null) {
      _videoController!.pause();
      _videoController!.seekTo(Duration.zero);
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  /// 复制到剪贴板
  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制到剪贴板'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// 显示实况视频预览
  void _showLiveVideoPreview(BuildContext context, ImageUploadState uploadState) {
    if (uploadState.result == null || uploadState.result!.videoUrl.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => _LiveVideoPreviewDialog(uploadState: uploadState),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 图片或视频
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                  ),
                  child: widget.uploadState.isVideo
                      ? _buildVideoPreview()
                      : GestureDetector(
                          onLongPress: () {
                            // 如果有 liveVideo，长按播放视频
                            if (widget.uploadState.result!.videoUrl.isNotEmpty) {
                              Navigator.of(context).pop(); // 关闭当前预览
                              _showLiveVideoPreview(context, widget.uploadState);
                            }
                          },
                          child: Image.network(
                            widget.uploadState.result!.imageUrl,
                            fit: BoxFit.contain,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                // 链接展示区域
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 图片/视频链接
                      Row(
                        children: [
                          Icon(
                            widget.uploadState.isVideo ? Icons.videocam : Icons.image,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.uploadState.result!.imageUrl,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, color: Colors.white, size: 16),
                            onPressed: () {
                              _copyToClipboard(context, widget.uploadState.result!.imageUrl);
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      // 实况视频链接（如果有）
                      if (widget.uploadState.result!.videoUrl.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.videocam, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.uploadState.result!.videoUrl,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, color: Colors.white, size: 16),
                              onPressed: () {
                                _copyToClipboard(context, widget.uploadState.result!.videoUrl);
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Markdown
                      Row(
                        children: [
                          const Icon(Icons.code, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.uploadState.result!.toMarkdown(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, color: Colors.white, size: 16),
                            onPressed: () {
                              _copyToClipboard(context, widget.uploadState.result!.toMarkdown());
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // LivePhoto 长按提示
          if (widget.uploadState.result!.videoUrl.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.album, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        '长按图片播放视频',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            top: 40,
            right: 20,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    // 如果正在播放
    if (_isPlaying && _videoController != null && _videoController!.value.isInitialized) {
      return GestureDetector(
        onTap: _stopVideo,
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
      );
    }

    // 未播放状态 - 显示播放按钮
    return Container(
      color: Colors.grey[800],
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 视频图标
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam,
                color: Colors.white.withOpacity(0.5),
                size: 80,
              ),
              const SizedBox(height: 12),
              Text(
                '视频文件',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // 播放按钮
          if (!_isInitializing)
            GestureDetector(
              onTap: _playVideo,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
          // 加载中
        ],
      ),
    );
  }
}

/// 实况视频预览对话框
class _LiveVideoPreviewDialog extends StatefulWidget {
  final ImageUploadState uploadState;

  const _LiveVideoPreviewDialog({
    Key? key,
    required this.uploadState,
  }) : super(key: key);

  @override
  State<_LiveVideoPreviewDialog> createState() => _LiveVideoPreviewDialogState();
}

class _LiveVideoPreviewDialogState extends State<_LiveVideoPreviewDialog> {
  VideoPlayerController? _videoController;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.uploadState.result!.videoUrl),
      );

      await _videoController!.initialize();
      await _videoController!.setLooping(true);
      await _videoController!.play();

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      print('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Center(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              child: _isInitializing
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : _videoController != null && _videoController!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        )
                      : const Center(
                          child: Text(
                            '视频加载失败',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.album, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Live Photo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
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
}
