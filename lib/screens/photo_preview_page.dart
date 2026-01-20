import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:motion_photos/motion_photos.dart';

/// 微信风格的照片预览页面
/// 支持左右滑动浏览所有照片，底部显示已选择的照片
class PhotoPreviewPage extends StatefulWidget {
  final List<AssetEntity> allPhotos; // 所有照片列表
  final int initialIndex; // 初始显示的照片索引
  final List<AssetEntity> selectedPhotos; // 已选择的照片
  final Map<String, bool> livePhotoSettings; // 实况照片设置

  const PhotoPreviewPage({
    Key? key,
    required this.allPhotos,
    required this.initialIndex,
    required this.selectedPhotos,
    required this.livePhotoSettings,
  }) : super(key: key);

  @override
  State<PhotoPreviewPage> createState() => _PhotoPreviewPageState();
}

class _PhotoPreviewPageState extends State<PhotoPreviewPage> {
  late PageController _pageController;
  late int _currentIndex;
  late List<AssetEntity> _selectedPhotos;
  late Map<String, bool> _livePhotoSettings;
  bool _currentIsLivePhoto = false; // 当前照片是否是实况
  final Map<String, bool> _livePhotoCache = {}; // 缓存照片的live状态

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _selectedPhotos = List.from(widget.selectedPhotos);
    _livePhotoSettings = Map.from(widget.livePhotoSettings);
    _pageController = PageController(initialPage: widget.initialIndex);
    _checkCurrentPhotoIsLive();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 检查照片是否是实况（带缓存）
  Future<bool> _checkPhotoIsLive(AssetEntity photo) async {
    // 视频不是实况照片
    if (photo.type == AssetType.video) {
      _livePhotoCache[photo.id] = false;
      return false;
    }

    // 先查缓存
    if (_livePhotoCache.containsKey(photo.id)) {
      return _livePhotoCache[photo.id]!;
    }

    // 检测
    try {
      final file = await photo.file;
      if (file != null) {
        final isLive = await MotionPhotos(file.path).isMotionPhoto();
        _livePhotoCache[photo.id] = isLive;
        return isLive;
      }
    } catch (e) {
      print('Error checking live photo: $e');
    }

    _livePhotoCache[photo.id] = false;
    return false;
  }

  /// 检查当前照片是否是实况
  Future<void> _checkCurrentPhotoIsLive() async {
    final currentPhoto = widget.allPhotos[_currentIndex];

    // 如果是视频，不检查实况
    if (currentPhoto.type == AssetType.video) {
      if (mounted) {
        setState(() {
          _currentIsLivePhoto = false;
        });
      }
      return;
    }

    final isLive = await _checkPhotoIsLive(currentPhoto);
    if (mounted) {
      setState(() {
        _currentIsLivePhoto = isLive;
      });
    }
  }

  /// 当前照片是否被选中
  bool get _isCurrentSelected {
    return _selectedPhotos.contains(widget.allPhotos[_currentIndex]);
  }

  /// 当前照片的实况设置
  bool get _currentLiveEnabled {
    final currentPhoto = widget.allPhotos[_currentIndex];
    return _livePhotoSettings[currentPhoto.id] ?? true;
  }

  /// 切换当前照片的实况设置
  void _toggleCurrentLive() {
    if (!_currentIsLivePhoto) return;
    final currentPhoto = widget.allPhotos[_currentIndex];
    // 视频不能切换实况设置
    if (currentPhoto.type == AssetType.video) return;

    setState(() {
      _livePhotoSettings[currentPhoto.id] = !(_livePhotoSettings[currentPhoto.id] ?? true);
    });
  }

  /// 切换当前照片的选择状态
  void _toggleSelection() {
    setState(() {
      final currentPhoto = widget.allPhotos[_currentIndex];
      if (_selectedPhotos.contains(currentPhoto)) {
        _selectedPhotos.remove(currentPhoto);
      } else {
        _selectedPhotos.add(currentPhoto);
        // 默认启用实况
        if (!_livePhotoSettings.containsKey(currentPhoto.id)) {
          _livePhotoSettings[currentPhoto.id] = true;
        }
      }
    });
  }

  /// 点击底部已选择的照片，跳转到该照片
  void _jumpToPhoto(AssetEntity photo) {
    final index = widget.allPhotos.indexOf(photo);
    if (index >= 0) {
      _pageController.jumpToPage(index);
    }
  }

  /// 完成选择，返回结果
  void _complete() {
    Navigator.pop(context, {
      'selectedPhotos': _selectedPhotos,
      'livePhotoSettings': _livePhotoSettings,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 主预览区域 - PageView
          PageView.builder(
            controller: _pageController,
            itemCount: widget.allPhotos.length,
            onPageChanged: (index) {
              if (_currentIndex != index) {
                _currentIndex = index;
                _checkCurrentPhotoIsLive();
                // 使用单独的setState来最小化重建范围
                if (mounted) {
                  setState(() {});
                }
              }
            },
            itemBuilder: (context, index) {
              return _PhotoPreviewItem(
                key: ValueKey(widget.allPhotos[index].id),
                asset: widget.allPhotos[index],
              );
            },
          ),

          // 顶栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(),
          ),

          // 实况开闭按钮（左下角，当前照片是实况时显示）
          if (_currentIsLivePhoto)
            Positioned(
              left: 16,
              bottom: _selectedPhotos.isNotEmpty ? 144 : 88,
              child: _buildLiveToggleButton(),
            ),

          // 底部已选择的照片列表（如果有选择）
          if (_selectedPhotos.isNotEmpty)
            Positioned(
              bottom: 56,
              left: 0,
              right: 0,
              child: _SelectedPhotosList(
                key: ValueKey(_selectedPhotos.length), // 使用长度作为key来减少重建
                selectedPhotos: _selectedPhotos,
                currentIndex: _currentIndex,
                allPhotos: widget.allPhotos,
                livePhotoSettings: _livePhotoSettings,
                livePhotoCache: _livePhotoCache,
                onPhotoTap: _jumpToPhoto,
                onCheckPhotoIsLive: _checkPhotoIsLive,
              ),
            ),

          // 底部操作栏
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  /// 构建实况切换按钮
  Widget _buildLiveToggleButton() {
    return GestureDetector(
      onTap: _toggleCurrentLive,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _currentLiveEnabled
              ? const Color(0xFF07C160)
              : Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _currentLiveEnabled ? Icons.check_circle : Icons.album,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 6),
            const Text(
              '实况',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建顶栏
  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context, {
                'selectedPhotos': _selectedPhotos,
                'livePhotoSettings': _livePhotoSettings,
              });
            },
          ),
          const SizedBox(width: 8),
          // 当前位置
          Text(
            '${_currentIndex + 1}/${widget.allPhotos.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          // 选择按钮（微信风格）
          GestureDetector(
            onTap: _toggleSelection,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isCurrentSelected
                        ? const Color(0xFF07C160)
                        : Colors.transparent,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: _isCurrentSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                const Text(
                  '选择',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建已选择的照片列表（已移除，使用独立Widget）

  /// 构建底部操作栏
  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          // 编辑按钮
          TextButton.icon(
            onPressed: () {
              // TODO: 实现编辑功能
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('编辑功能即将推出')),
              );
            },
            icon: const Icon(Icons.edit, color: Colors.white),
            label: const Text('编辑', style: TextStyle(color: Colors.white)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          const Spacer(),
          // 完成按钮
          ElevatedButton(
            onPressed: _selectedPhotos.isEmpty ? null : _complete,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              _selectedPhotos.isEmpty
                  ? '完成'
                  : '完成(${_selectedPhotos.length})',
            ),
          ),
        ],
      ),
    );
  }
}

/// 单张照片预览组件
class _PhotoPreviewItem extends StatefulWidget {
  final AssetEntity asset;

  const _PhotoPreviewItem({
    Key? key,
    required this.asset,
  }) : super(key: key);

  @override
  State<_PhotoPreviewItem> createState() => _PhotoPreviewItemState();
}

class _PhotoPreviewItemState extends State<_PhotoPreviewItem> {
  VideoPlayerController? _videoController;
  bool _isPlayingVideo = false;
  String? _videoPath;
  bool _isLivePhoto = false;

  @override
  void initState() {
    super.initState();
    _checkAndExtractVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  /// 检查并提取实况视频
  Future<void> _checkAndExtractVideo() async {
    // 如果是视频类型，不需要检查实况
    if (widget.asset.type == AssetType.video) {
      return;
    }

    try {
      final file = await widget.asset.file;
      if (file != null) {
        final motionPhotos = MotionPhotos(file.path);
        final isLive = await motionPhotos.isMotionPhoto();

        if (isLive && mounted) {
          setState(() {
            _isLivePhoto = true;
          });

          final videoBytes = await motionPhotos.getMotionVideo();
          if (videoBytes != null && mounted) {
            final tempDir = Directory.systemTemp;
            final tempVideoPath = '${tempDir.path}/temp_live_${DateTime.now().millisecondsSinceEpoch}.mp4';
            final tempFile = File(tempVideoPath);
            await tempFile.writeAsBytes(videoBytes);

            setState(() {
              _videoPath = tempVideoPath;
            });
          }
        }
      }
    } catch (e) {
      print('Error checking live photo: $e');
    }
  }

  /// 播放视频（用于纯视频文件）
  Future<void> _playPureVideo() async {
    if (widget.asset.type != AssetType.video) return;

    try {
      final file = await widget.asset.file;
      if (file == null) return;

      if (_videoController != null) {
        await _videoController!.dispose();
      }

      _videoController = VideoPlayerController.file(file);
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
    } catch (e) {
      print('Error playing video: $e');
    }
  }

  /// 长按播放视频
  Future<void> _playVideo() async {
    if (_videoPath == null || !_isLivePhoto) return;

    if (_videoController != null) {
      await _videoController!.dispose();
    }

    _videoController = VideoPlayerController.file(File(_videoPath!));
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
    return GestureDetector(
      onLongPress: _isLivePhoto ? _playVideo : null,
      onLongPressEnd: (_) => _stopVideo(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 图片或视频缩略图
          if (!_isPlayingVideo)
            FutureBuilder<dynamic>(
              future: widget.asset.type == AssetType.video
                  ? widget.asset.thumbnailDataWithSize(const ThumbnailSize(1000, 1000))
                  : widget.asset.file,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: widget.asset.type == AssetType.video
                        ? Image.memory(
                            snapshot.data as Uint8List,
                            fit: BoxFit.contain,
                          )
                        : Image.file(
                            snapshot.data as File,
                            fit: BoxFit.contain,
                          ),
                  );
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),

          // 视频播放按钮（中间）
          if (widget.asset.type == AssetType.video && !_isPlayingVideo)
            GestureDetector(
              onTap: _playPureVideo,
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

          // 视频播放器
          if (_isPlayingVideo && _videoController != null)
            GestureDetector(
              onTap: _stopVideo,
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            ),
        ],
      ),
    );
  }
}

/// 独立的选择照片列表Widget，避免PageView切换时重建
class _SelectedPhotosList extends StatefulWidget {
  final List<AssetEntity> selectedPhotos;
  final int currentIndex;
  final List<AssetEntity> allPhotos;
  final Map<String, bool> livePhotoSettings;
  final Map<String, bool> livePhotoCache;
  final Function(AssetEntity) onPhotoTap;
  final Future<bool> Function(AssetEntity) onCheckPhotoIsLive;

  const _SelectedPhotosList({
    Key? key,
    required this.selectedPhotos,
    required this.currentIndex,
    required this.allPhotos,
    required this.livePhotoSettings,
    required this.livePhotoCache,
    required this.onPhotoTap,
    required this.onCheckPhotoIsLive,
  }) : super(key: key);

  @override
  State<_SelectedPhotosList> createState() => _SelectedPhotosListState();
}

class _SelectedPhotosListState extends State<_SelectedPhotosList> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: widget.selectedPhotos.length,
        itemBuilder: (context, index) {
          final photo = widget.selectedPhotos[index];
          final enableLive = widget.livePhotoSettings[photo.id] ?? true;
          final isCurrentPhoto = photo == widget.allPhotos[widget.currentIndex];

          return GestureDetector(
            onTap: () => widget.onPhotoTap(photo),
            child: Container(
              width: 60,
              height: 60,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isCurrentPhoto
                      ? Theme.of(context).primaryColor
                      : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 缩略图
                    FutureBuilder<Uint8List?>(
                      future: photo.thumbnailDataWithSize(
                          const ThumbnailSize.square(100)),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return Image.memory(snapshot.data!,
                              fit: BoxFit.cover);
                        }
                        return Container(color: Colors.grey[800]);
                      },
                    ),
                    // Live标记（只在真正是live photo时显示）
                    FutureBuilder<bool>(
                      future: widget.onCheckPhotoIsLive(photo),
                      builder: (context, snapshot) {
                        final isLive = snapshot.data ?? false;
                        if (!isLive) return const SizedBox.shrink();

                        return Positioned(
                          left: 2,
                          bottom: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 3, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Stack(
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.album,
                                        color: Colors.white, size: 8),
                                    SizedBox(width: 1),
                                    Text(
                                      'Live',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                // 删除线
                                if (!enableLive)
                                  Positioned.fill(
                                    child: Center(
                                      child: Container(
                                        height: 1,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    // 顺序号
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
