import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:motion_photos/motion_photos.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import '../services/image_edit_service.dart';

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
  final ImageEditService _editService = ImageEditService.instance; // 图片编辑服务
  bool _isEditingComplete = false; // 防止编辑完成回调多次执行

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

  /// 处理图片编辑
  Future<void> _handleEdit() async {
    final currentAsset = widget.allPhotos[_currentIndex];

    // 视频不支持编辑
    if (currentAsset.type == AssetType.video) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('仅支持图片编辑')),
      );
      return;
    }

    try {
      // 获取原始文件路径（用于 live photo 视频提取）
      final originalFile = await currentAsset.file;
      final originalFilePath = originalFile?.path;

      // 获取当前图片文件（优先使用已编辑版本）
      final file = await _editService.getFinalFile(currentAsset);
      if (file == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法加载图片')),
        );
        return;
      }

      // 重置编辑完成标志
      _isEditingComplete = false;

      // 跳转到图片编辑器
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProImageEditor.file(
            file,
            configs: ProImageEditorConfigs(
              // 启用所有可用的编辑工具（暂不包括 sticker，需要自定义贴纸资源）
              mainEditor: const MainEditorConfigs(
                tools: [
                  SubEditorMode.paint,      // 画笔
                  SubEditorMode.text,       // 文字
                  SubEditorMode.cropRotate, // 裁剪/旋转
                  SubEditorMode.tune,       // 调整
                  SubEditorMode.filter,     // 滤镜
                  SubEditorMode.blur,       // 模糊
                  SubEditorMode.emoji,      // 表情
                  // SubEditorMode.sticker, // 贴纸（需要提供 builder）
                ],
              ),
              i18n: const I18n(
                various: I18nVarious(
                  loadingDialogMsg: '请稍等...',
                  closeEditorWarningTitle: '关闭编辑器？',
                  closeEditorWarningMessage: '确定要关闭编辑器吗？您的更改将不会被保存。',
                  closeEditorWarningConfirmBtn: '确定',
                  closeEditorWarningCancelBtn: '取消',
                ),
                layerInteraction: I18nLayerInteraction(
                  remove: '移除',
                  edit: '编辑',
                  rotateScale: '旋转和缩放',
                ),
                tuneEditor: I18nTuneEditor(
                  bottomNavigationBarText: '调整',
                  back: '返回',
                  done: '完成',
                  brightness: '亮度',
                  contrast: '对比度',
                  saturation: '饱和度',
                  exposure: '曝光',
                  hue: '色调',
                  temperature: '色温',
                  sharpness: '锐度',
                  fade: '褪色',
                  luminance: '明度',
                  undo: '撤销',
                  redo: '重做',
                ),
                paintEditor: I18nPaintEditor(
                  bottomNavigationBarText: '画笔',
                  moveAndZoom: '缩放',
                  freestyle: '自由画笔',
                  arrow: '箭头',
                  line: '直线',
                  rectangle: '矩形',
                  circle: '圆形',
                  dashLine: '虚线',
                  dashDotLine: '点划线',
                  hexagon: '六边形',
                  polygon: '多边形',
                  blur: '模糊',
                  pixelate: '像素化',
                  lineWidth: '线条粗细',
                  eraser: '橡皮擦',
                  toggleFill: '填充切换',
                  changeOpacity: '更改透明度',
                  undo: '撤销',
                  redo: '重做',
                  done: '完成',
                  back: '返回',
                  smallScreenMoreTooltip: '更多',
                  opacity: '透明度',
                  color: '颜色',
                  strokeWidth: '线条宽度',
                  fill: '填充',
                  cancel: '取消',
                ),
                textEditor: I18nTextEditor(
                  bottomNavigationBarText: '文字',
                  inputHintText: '输入文字',
                  done: '完成',
                  back: '返回',
                  textAlign: '对齐',
                  fontScale: '字体大小',
                  backgroundMode: '背景',
                  smallScreenMoreTooltip: '更多',
                ),
                cropRotateEditor: I18nCropRotateEditor(
                  bottomNavigationBarText: '裁剪/旋转',
                  rotate: '旋转',
                  flip: '翻转',
                  ratio: '比例',
                  back: '返回',
                  done: '完成',
                  cancel: '取消',
                  undo: '撤销',
                  redo: '重做',
                  smallScreenMoreTooltip: '更多',
                  reset: '重置',
                ),
                filterEditor: I18nFilterEditor(
                  bottomNavigationBarText: '滤镜',
                  back: '返回',
                  done: '完成',
                  filters: I18nFilters(
                    none: '无',
                    addictiveBlue: '冷色',
                    addictiveRed: '暖色',
                    aden: 'Aden',
                    amaro: 'Amaro',
                    ashby: 'Ashby',
                    brannan: 'Brannan',
                    brooklyn: 'Brooklyn',
                    charmes: 'Charmes',
                    clarendon: 'Clarendon',
                    crema: 'Crema',
                    dogpatch: 'Dogpatch',
                    earlybird: 'Earlybird',
                    f1977: '1977',
                    gingham: 'Gingham',
                    ginza: 'Ginza',
                    hefe: 'Hefe',
                    helena: 'Helena',
                    hudson: 'Hudson',
                    inkwell: '墨水',
                    juno: 'Juno',
                    kelvin: 'Kelvin',
                    lark: 'Lark',
                    loFi: 'Lo-Fi',
                    ludwig: 'Ludwig',
                    maven: 'Maven',
                    mayfair: 'Mayfair',
                    moon: '月光',
                    nashville: 'Nashville',
                    perpetua: 'Perpetua',
                    reyes: 'Reyes',
                    rise: 'Rise',
                    sierra: 'Sierra',
                    skyline: 'Skyline',
                    slumber: 'Slumber',
                    stinson: 'Stinson',
                    sutro: 'Sutro',
                    toaster: 'Toaster',
                    valencia: 'Valencia',
                    vesper: 'Vesper',
                    walden: 'Walden',
                    willow: 'Willow',
                    xProII: 'X-Pro II',
                  ),
                ),
                blurEditor: I18nBlurEditor(
                  bottomNavigationBarText: '模糊',
                  back: '返回',
                  done: '完成',
                ),
                emojiEditor: I18nEmojiEditor(
                  bottomNavigationBarText: '表情',
                ),
                stickerEditor: I18nStickerEditor(
                  bottomNavigationBarText: '贴纸',
                ),
                cancel: '取消',
                undo: '撤销',
                redo: '重做',
                done: '完成',
                remove: '移除',
                doneLoadingMsg: '正在应用更改...',
                importStateHistoryMsg: '初始化编辑器',
              ),
            ),
            callbacks: ProImageEditorCallbacks(
              onImageEditingComplete: (Uint8List bytes) async {
                // 防止多次执行
                if (_isEditingComplete) return;
                _isEditingComplete = true;

                try {
                  // 保存编辑后的数据（包括 live photo 信息）
                  await _editService.saveEditedImage(
                    currentAsset.id,
                    bytes,
                    isLivePhoto: _currentIsLivePhoto,
                    originalFilePath: originalFilePath,
                  );

                  // 如果编辑的是实况照片，自动禁用实况功能
                  if (_currentIsLivePhoto) {
                    _livePhotoSettings[currentAsset.id] = false;
                  }

                  // 使用 microtask 关闭编辑器
                  if (mounted) {
                    Future.microtask(() {
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    });
                  }
                } catch (e) {
                  print('保存编辑失败: $e');
                  _isEditingComplete = false; // 重置标志以允许重试
                }
              },
            ),
          ),
        ),
      );

      // 编辑器关闭后刷新预览页 UI
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('编辑图片失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('编辑失败: $e')),
        );
      }
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

          // 已编辑徽章（右上角）
          if (_editService.isEdited(widget.allPhotos[_currentIndex].id))
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.edit, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '已编辑',
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
                editedAssetIds: _editService.editedAssetIds,
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
            onPressed: _handleEdit,
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
  final ImageEditService _editService = ImageEditService.instance;

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
                  : _editService.getFinalFile(widget.asset), // 使用编辑后的图片（如果存在）
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
  final List<String> editedAssetIds; // 已编辑的资源ID列表

  const _SelectedPhotosList({
    Key? key,
    required this.selectedPhotos,
    required this.currentIndex,
    required this.allPhotos,
    required this.livePhotoSettings,
    required this.livePhotoCache,
    required this.onPhotoTap,
    required this.onCheckPhotoIsLive,
    required this.editedAssetIds,
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
                    // 已编辑标识（右下角小圆点）
                    if (widget.editedAssetIds.contains(photo.id))
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 8,
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
