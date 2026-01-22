import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:motion_photos/motion_photos.dart';
import 'package:video_player/video_player.dart';
import 'photo_preview_page.dart';
import '../services/image_edit_service.dart';

/// 选中的图片信息（包含实况选项）
class SelectedImageInfo {
  final XFile file;
  final bool isLivePhoto;
  final bool enableLiveVideo; // 是否上传实况视频
  final bool isVideo; // 是否是视频文件

  SelectedImageInfo({
    required this.file,
    required this.isLivePhoto,
    required this.enableLiveVideo,
    this.isVideo = false,
  });
}

/// 自定义图片选择器（朋友圈风格）
class CustomImagePicker extends StatefulWidget {
  final int maxCount; // 最多选择数量
  final int alreadySelectedCount; // 已经选择的数量

  const CustomImagePicker({
    Key? key,
    this.maxCount = 9,
    this.alreadySelectedCount = 0,
  }) : super(key: key);

  @override
  State<CustomImagePicker> createState() => _CustomImagePickerState();
}

class _CustomImagePickerState extends State<CustomImagePicker> {
  List<AssetEntity> _mediaList = [];
  List<AssetEntity> _selectedAssets = []; // 按选择顺序存储
  Map<String, bool> _livePhotoEnabled = {}; // 保存每个资源的实况上传选项（asset.id -> enabled）
  bool _isLoading = true;
  String _currentAlbumName = '所有照片';

  // 新增：存储所有相册
  List<AssetPathEntity> _allAlbums = [];
  AssetPathEntity? _currentAlbum;

  // 分页加载相关
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  int _currentPage = 1; // 已加载的页数(从1开始,因为第0页已经加载)
  int _totalCount = 0; // 相册总照片数
  static const int _pageSize = 500; // 每页加载500张

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _requestPermissionAndLoadPhotos();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 滚动监听,接近底部时加载更多
  void _onScroll() {
    if (_isLoadingMore || _currentAlbum == null) return;

    // 当滚动到距离底部1000像素时开始加载更多
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll < 1000) {
      // 检查是否还有更多照片要加载
      if (_mediaList.length < _totalCount) {
        _loadMorePhotos();
      }
    }
  }

  /// 请求权限并加载照片
  Future<void> _requestPermissionAndLoadPhotos() async {
    // 使用 PhotoManager 的权限请求（根据官方文档推荐）
    final PermissionState ps = await PhotoManager.requestPermissionExtend(
      requestOption: PermissionRequestOption(
        iosAccessLevel: IosAccessLevel.readWrite,
        androidPermission: AndroidPermission(
          type: RequestType.common, // 图片和视频
          mediaLocation: false,
        ),
      ),
    );

    print('PhotoManager permission state: ${ps.name}, hasAccess: ${ps.hasAccess}, isAuth: ${ps.isAuth}');

    // Android 14 返回 limited 权限时，引导用户选择更多照片
    if (ps == PermissionState.limited) {
      print('Limited permission detected, presenting photo selector...');
      if (mounted) {
        final bool? shouldSelectMore = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('选择更多照片'),
            content: const Text('当前只能访问部分照片。要访问所有照片，请在下一步选择"允许访问所有照片"。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('选择照片'),
              ),
            ],
          ),
        );

        if (shouldSelectMore == true) {
          // 调用系统照片选择器，让用户选择更多照片
          await PhotoManager.presentLimited();
          // 重新加载照片
          await _loadPhotos();
          return;
        }
      }
    }

    if (ps.isAuth || ps.hasAccess || ps == PermissionState.limited) {
      await _loadPhotos();
    } else {
      // 权限被拒绝
      if (mounted) {
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('需要相册权限'),
            content: const Text('请在设置中允许访问照片和视频权限'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('去设置'),
              ),
            ],
          ),
        );

        if (shouldOpenSettings == true) {
          await PhotoManager.openSetting();
        }
      }
    }
  }

  /// 加载相册照片
  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);

    try {
      // 设置过滤选项：按创建时间降序排列（最新的在前）
      final FilterOptionGroup filterOption = FilterOptionGroup(
        createTimeCond: DateTimeCond(
          min: DateTime(1970),
          max: DateTime.now(),
        ),
        orders: [
          const OrderOption(
            type: OrderOptionType.createDate,
            asc: false, // false = 降序，最新的在前
          ),
        ],
      );

      // 获取所有图片和视频相册
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.common, // 同时加载图片和视频
        hasAll: true,
        onlyAll: false,
        filterOption: filterOption,
      );

      print('Found ${albums.length} albums');

      if (albums.isEmpty) {
        print('No albums found');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _allAlbums = [];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('没有找到相册')),
          );
        }
        return;
      }

      // 保存所有相册列表
      _allAlbums = albums;

      // 打印所有相册信息，特别注意 Camera 相册
      print('=== All Albums ===');
      for (var i = 0; i < albums.length; i++) {
        final album = albums[i];
        final count = await album.assetCountAsync;
        final isCameraAlbum = album.name.toLowerCase().contains('camera') ||
                              album.name.toLowerCase().contains('相机') ||
                              album.name.toLowerCase().contains('dcim');
        print('Album $i: ${album.name}, count: $count, isAll: ${album.isAll}, isCamera: $isCameraAlbum');
      }
      print('==================');

      // 如果还没有选择相册，自动选择第一个（通常是 isAll 的相册）
      if (_currentAlbum == null) {
        // 查找相册的优先级：
        // 1. 优先找 isAll = true 的相册（包含所有照片）
        // 2. 其次找名字完全匹配 "Camera" 的相册
        // 3. 再找包含 camera/相机 关键词且照片数最多的相册
        // 4. 最后找所有相册中照片数最多的
        AssetPathEntity selectedAlbum;

        // 先找 isAll 相册
        try {
          selectedAlbum = albums.firstWhere((album) => album.isAll);
          print('Found isAll album: ${selectedAlbum.name}');
        } catch (e) {
          // 如果没有 isAll，找 Camera 相册
          // 优先匹配名字完全是 "Camera" 的
          try {
            selectedAlbum = albums.firstWhere((album) =>
              album.name.toLowerCase() == 'camera' ||
              album.name.toLowerCase() == '相机'
            );
            print('Found exact Camera album: ${selectedAlbum.name}');
          } catch (e) {
            // 找包含 camera/相机/dcim 的相册，选择照片数最多的
            final cameraAlbums = albums.where((album) =>
              album.name.toLowerCase().contains('camera') ||
              album.name.toLowerCase().contains('相机') ||
              album.name.toLowerCase().contains('dcim')
            ).toList();

            if (cameraAlbums.isNotEmpty) {
              selectedAlbum = cameraAlbums.first;
              int maxCount = 0;
              for (var album in cameraAlbums) {
                final count = await album.assetCountAsync;
                if (count > maxCount) {
                  maxCount = count;
                  selectedAlbum = album;
                }
              }
              print('Found Camera-like album with most photos: ${selectedAlbum.name}, count: $maxCount');
            } else {
              // 如果都没找到，选择照片数最多的相册
              selectedAlbum = albums.first;
              int maxCount = 0;
              for (var album in albums) {
                final count = await album.assetCountAsync;
                if (count > maxCount) {
                  maxCount = count;
                  selectedAlbum = album;
                }
              }
              print('Selected album with most photos: ${selectedAlbum.name}');
            }
          }
        }

        _currentAlbum = selectedAlbum;
      }

      // 加载当前相册的照片
      await _loadAlbumPhotos(_currentAlbum!);

    } catch (e, stackTrace) {
      print('Error loading photos: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载照片失败: $e')),
        );
      }
    }
  }

  /// 加载指定相册的照片
  Future<void> _loadAlbumPhotos(AssetPathEntity album) async {
    setState(() {
      _isLoading = true;
      _currentPage = 1; // 重置分页
    });

    try {
      print('Loading album: ${album.name}, isAll: ${album.isAll}');

      // 获取相册总数
      _totalCount = await album.assetCountAsync;
      print('Total photos in ${album.name}: $_totalCount');

      if (_totalCount == 0) {
        if (mounted) {
          setState(() {
            _mediaList = [];
            _currentAlbumName = album.name;
            _currentAlbum = album;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('该相册中没有照片')),
          );
        }
        return;
      }

      // 首次加载，加载第一页
      final int firstPageSize = _totalCount > 1000 ? 1000 : _totalCount;

      // 按时间倒序加载（最新的照片在前面）
      final List<AssetEntity> media = await album.getAssetListRange(
        start: 0,
        end: firstPageSize,
      );

      print('Loaded ${media.length} photos from ${album.name} (newest first)');

      if (mounted) {
        setState(() {
          _mediaList = media;
          _currentAlbumName = album.name;
          _currentAlbum = album;
          _currentPage = firstPageSize ~/ _pageSize; // 计算已加载的页数
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('Error loading album photos: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载相册失败: $e')),
        );
      }
    }
  }

  /// 加载更多照片(分页)
  Future<void> _loadMorePhotos() async {
    if (_isLoadingMore || _currentAlbum == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final int start = _mediaList.length;
      final int end = (start + _pageSize) > _totalCount ? _totalCount : (start + _pageSize);

      if (start >= _totalCount) {
        setState(() => _isLoadingMore = false);
        return;
      }

      print('Loading more photos: $start to $end (total: $_totalCount)');

      final List<AssetEntity> moreMedia = await _currentAlbum!.getAssetListRange(
        start: start,
        end: end,
      );

      print('Loaded ${moreMedia.length} more photos');

      if (mounted) {
        setState(() {
          _mediaList.addAll(moreMedia);
          _currentPage++;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Error loading more photos: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  /// 切换相册
  Future<void> _switchAlbum(AssetPathEntity album) async {
    if (_currentAlbum == album) return;
    await _loadAlbumPhotos(album);
  }

  /// 显示相册选择器
  Future<void> _showAlbumPicker(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 400,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: const Text(
                  '选择相册',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _allAlbums.length,
                  itemBuilder: (context, index) {
                    final album = _allAlbums[index];
                    return FutureBuilder<int>(
                      future: album.assetCountAsync,
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        final isSelected = _currentAlbum == album;

                        return ListTile(
                          title: Text(album.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$count',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (isSelected)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(
                                    Icons.check,
                                    color: Colors.blue,
                                  ),
                                ),
                            ],
                          ),
                          selected: isSelected,
                          onTap: () {
                            Navigator.pop(context);
                            _switchAlbum(album);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 切换选择状态
  void _toggleSelection(AssetEntity asset) {
    setState(() {
      if (_selectedAssets.contains(asset)) {
        // 取消选择
        _selectedAssets.remove(asset);
      } else {
        // 添加选择（不限制数量）
        _selectedAssets.add(asset);
      }
    });
  }

  /// 预览照片
  Future<void> _previewPhoto(AssetEntity asset, bool isLivePhoto) async {
    if (!mounted) return;

    // 找到当前照片在所有照片中的索引
    final initialIndex = _mediaList.indexOf(asset);
    if (initialIndex < 0) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoPreviewPage(
          allPhotos: _mediaList,
          initialIndex: initialIndex,
          selectedPhotos: _selectedAssets,
          livePhotoSettings: _livePhotoEnabled,
        ),
      ),
    );

    // result包含：{selectedPhotos: List<AssetEntity>, livePhotoSettings: Map<String, bool>}
    if (result != null) {
      setState(() {
        _selectedAssets = List<AssetEntity>.from(result['selectedPhotos']);
        _livePhotoEnabled = Map<String, bool>.from(result['livePhotoSettings']);
      });
    }
  }

  /// 预览已选择的照片
  Future<void> _previewSelectedPhotos() async {
    if (_selectedAssets.isEmpty || !mounted) return;

    // 从第一张选择的照片开始预览
    final firstSelected = _selectedAssets.first;
    final initialIndex = _mediaList.indexOf(firstSelected);
    if (initialIndex < 0) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoPreviewPage(
          allPhotos: _mediaList,
          initialIndex: initialIndex,
          selectedPhotos: _selectedAssets,
          livePhotoSettings: _livePhotoEnabled,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedAssets = List<AssetEntity>.from(result['selectedPhotos']);
        _livePhotoEnabled = Map<String, bool>.from(result['livePhotoSettings']);
      });
    }
  }

  /// 获取选择顺序（1-based）
  int? _getSelectionOrder(AssetEntity asset) {
    final index = _selectedAssets.indexOf(asset);
    return index >= 0 ? index + 1 : null;
  }

  /// 确认选择
  Future<void> _confirmSelection() async {
    if (_selectedAssets.isEmpty) {
      Navigator.pop(context, <SelectedImageInfo>[]);
      return;
    }

    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // 转换为 SelectedImageInfo
    final List<SelectedImageInfo> selectedImages = [];
    for (final asset in _selectedAssets) {
      // 优先使用编辑后的文件，否则使用原始文件
      final file = await ImageEditService.instance.getFinalFile(asset);
      if (file != null) {
        // 检查是否为实况照片
        bool isLive = false;
        bool wasEdited = ImageEditService.instance.isEdited(asset.id);

        if (wasEdited) {
          // 编辑后的图片：从 ImageEditService 获取原始 live photo 状态
          final editedInfo = ImageEditService.instance.getEditedInfo(asset.id);
          isLive = editedInfo?.isLivePhoto ?? false;
        } else {
          // 未编辑的图片：检查实况
          try {
            isLive = await MotionPhotos(file.path).isMotionPhoto();
          } catch (e) {
            print('Error checking live photo: $e');
          }
        }

        selectedImages.add(SelectedImageInfo(
          file: XFile(file.path),
          isLivePhoto: isLive,
          enableLiveVideo: _livePhotoEnabled[asset.id] ?? true, // 默认启用
          isVideo: asset.type == AssetType.video,
        ));
      }
    }

    Navigator.pop(context); // 关闭加载对话框
    Navigator.pop(context, selectedImages); // 返回结果
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black87,
        iconTheme: const IconThemeData(color: Colors.white),
        title: GestureDetector(
          onTap: _allAlbums.isNotEmpty ? () {
            print('Album picker tapped, albums count: ${_allAlbums.length}');
            _showAlbumPicker(context);
          } : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentAlbumName == 'Recent' ? '最近图片' : _currentAlbumName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_allAlbums.isNotEmpty)
                  const Icon(Icons.arrow_drop_down, color: Colors.white, size: 28),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mediaList.isEmpty
              ? const Center(child: Text('没有照片'))
              : Column(
                  children: [
                    // 照片数量显示
                    if (_totalCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        color: Colors.grey[200],
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '已加载 ${_mediaList.length} / $_totalCount 张照片',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    // 照片网格
                    Expanded(
                      child: GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(2),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        itemCount: _mediaList.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          // 底部加载指示器
                          if (index == _mediaList.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          final asset = _mediaList[index];
                          final isSelected = _selectedAssets.contains(asset);
                          final selectionOrder = _getSelectionOrder(asset);
                          final enableLiveVideo = _livePhotoEnabled[asset.id] ?? true;

                          return _PhotoItem(
                            asset: asset,
                            isSelected: isSelected,
                            selectionOrder: selectionOrder,
                            enableLiveVideo: enableLiveVideo,
                            onTap: () async {
                              // 点击图片预览照片
                              // 先检测是否是实况照片
                              bool isLive = false;
                              try {
                                final file = await asset.file;
                                if (file != null) {
                                  isLive = await MotionPhotos(file.path).isMotionPhoto();
                                }
                              } catch (e) {
                                print('Error checking live photo: $e');
                              }
                              _previewPhoto(asset, isLive);
                            },
                            onLongPress: () => _toggleSelection(asset),
                            onSelectTap: () => _toggleSelection(asset),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black87,
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.2)),
          ),
        ),
        child: Row(
          children: [
            // 左侧：预览按钮
            Expanded(
              child: TextButton(
                onPressed: _selectedAssets.isEmpty ? null : _previewSelectedPhotos,
                child: Text(
                  '预览',
                  style: TextStyle(
                    color: _selectedAssets.isEmpty ? Colors.grey[400] : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            // 右侧：完成按钮
            Expanded(
              child: TextButton(
                onPressed: _selectedAssets.isEmpty ? null : _confirmSelection,
                child: Text(
                  _selectedAssets.isEmpty
                      ? '完成'
                      : '完成(${_selectedAssets.length})',
                  style: TextStyle(
                    color: _selectedAssets.isEmpty ? Colors.grey[400] : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个图片项组件
class _PhotoItem extends StatefulWidget {
  final AssetEntity asset;
  final bool isSelected;
  final int? selectionOrder;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onSelectTap; // 点击选择框
  final bool enableLiveVideo; // 是否启用实况上传

  const _PhotoItem({
    Key? key,
    required this.asset,
    required this.isSelected,
    required this.selectionOrder,
    required this.onTap,
    required this.onLongPress,
    required this.onSelectTap,
    required this.enableLiveVideo,
  }) : super(key: key);

  @override
  State<_PhotoItem> createState() => _PhotoItemState();
}

class _PhotoItemState extends State<_PhotoItem> with AutomaticKeepAliveClientMixin {
  bool _isLivePhoto = false;
  bool _isChecking = false;
  bool _hasChecked = false;
  Uint8List? _cachedThumbnail;

  @override
  bool get wantKeepAlive => true; // 保持状态，避免重建

  @override
  void initState() {
    super.initState();
    // 立即开始检测实况照片（异步，避免阻塞UI）
    _checkIfLivePhoto();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(_PhotoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果asset变化了，重新加载
    if (oldWidget.asset != widget.asset) {
      _hasChecked = false;
      _cachedThumbnail = null;
      _checkIfLivePhoto();
      _loadThumbnail();
    }
  }

  /// 加载缩略图
  Future<void> _loadThumbnail() async {
    if (_cachedThumbnail != null) return;

    try {
      final thumbnail = await widget.asset.thumbnailDataWithSize(const ThumbnailSize.square(200));
      if (mounted && thumbnail != null) {
        setState(() {
          _cachedThumbnail = thumbnail;
        });
      }
    } catch (e) {
      print('Error loading thumbnail: $e');
    }
  }

  /// 检查是否为实况照片
  Future<void> _checkIfLivePhoto() async {
    if (_isChecking || _hasChecked) return;

    setState(() => _isChecking = true);

    try {
      final file = await widget.asset.file;
      if (file != null && mounted) {
        // 添加超时机制，避免卡住
        final isLive = await Future.any([
          MotionPhotos(file.path).isMotionPhoto(),
          Future.delayed(const Duration(milliseconds: 500), () => false),
        ]);

        if (mounted) {
          setState(() {
            _isLivePhoto = isLive;
            _isChecking = false;
            _hasChecked = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isChecking = false;
            _hasChecked = true;
          });
        }
      }
    } catch (e) {
      print('Error checking live photo: $e');
      if (mounted) {
        setState(() {
          _isChecking = false;
          _hasChecked = true;
        });
      }
    }
  }

  /// 格式化视频时长
  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes}:${secs.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用，AutomaticKeepAliveClientMixin要求

    return GestureDetector(
      onTap: widget.onTap, // 点击预览
      onLongPress: widget.onLongPress, // 长按选择
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 图片缩略图（使用缓存）
          if (_cachedThumbnail != null)
            Image.memory(
              _cachedThumbnail!,
              fit: BoxFit.cover,
            )
          else
            Container(
              color: Colors.grey[300],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),

          // 遮罩层（选中时）
          if (widget.isSelected)
            Container(
              color: Colors.white.withOpacity(0.3),
            ),

          // Live Photo 标记（左下角，仅实况照片）
          if (!_isChecking && _isLivePhoto && widget.asset.type != AssetType.video)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Stack(
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.album, color: Colors.white, size: 12),
                        SizedBox(width: 2),
                        Text(
                          'Live',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    // 删除线（如果禁用实况）
                    if (!widget.enableLiveVideo)
                      Positioned.fill(
                        child: Center(
                          child: Container(
                            height: 1.5,
                            color: Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // 视频时长标记（左下角）
          if (widget.asset.type == AssetType.video && widget.asset.duration > 0)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatDuration(widget.asset.duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // 选择框和顺序（右上角）
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () {
                widget.onSelectTap(); // 点击选择框直接选择，不进入预览
              },
              child: widget.isSelected
                  ? Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '${widget.selectionOrder}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 照片预览页面
class _PhotoPreviewPage extends StatefulWidget {
  final AssetEntity asset;
  final File file;
  final bool isLivePhoto;
  final bool isSelected;
  final bool enableLiveVideo;

  const _PhotoPreviewPage({
    Key? key,
    required this.asset,
    required this.file,
    required this.isLivePhoto,
    required this.isSelected,
    required this.enableLiveVideo,
  }) : super(key: key);

  @override
  State<_PhotoPreviewPage> createState() => _PhotoPreviewPageState();
}

class _PhotoPreviewPageState extends State<_PhotoPreviewPage> {
  bool _isSelected = false;
  bool _enableLiveVideo = true; // 是否上传实况视频
  VideoPlayerController? _videoController;
  bool _isPlayingVideo = false;
  String? _videoPath;

  @override
  void initState() {
    super.initState();
    _isSelected = widget.isSelected;
    _enableLiveVideo = widget.enableLiveVideo;

    // 如果是实况照片，提取视频
    if (widget.isLivePhoto) {
      _extractVideo();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  /// 提取实况视频
  Future<void> _extractVideo() async {
    try {
      final motionPhotos = MotionPhotos(widget.file.path);
      final isLive = await motionPhotos.isMotionPhoto();

      if (isLive) {
        final videoBytes = await motionPhotos.getMotionVideo();
        if (videoBytes != null && mounted) {
          // 保存视频到临时文件
          final tempDir = Directory.systemTemp;
          final tempVideoPath = '${tempDir.path}/temp_live_${DateTime.now().millisecondsSinceEpoch}.mp4';
          final tempFile = File(tempVideoPath);
          await tempFile.writeAsBytes(videoBytes);

          setState(() {
            _videoPath = tempVideoPath;
          });
        }
      }
    } catch (e) {
      print('Error extracting video: $e');
    }
  }

  /// 播放纯视频
  Future<void> _playPureVideo() async {
    if (widget.asset.type != AssetType.video) return;

    if (_videoController != null) {
      await _videoController!.dispose();
    }

    _videoController = VideoPlayerController.file(widget.file);
    await _videoController!.initialize();

    setState(() {
      _isPlayingVideo = true;
    });

    await _videoController!.play();

    // 视频播放完后自动停止
    _videoController!.addListener(() {
      if (_videoController!.value.position >= _videoController!.value.duration) {
        setState(() {
          _isPlayingVideo = false;
        });
        _videoController?.pause();
        _videoController?.seekTo(Duration.zero);
      }
    });
  }

  /// 长按播放视频
  Future<void> _playVideo() async {
    if (_videoPath == null) return;

    if (_videoController != null) {
      await _videoController!.dispose();
    }

    _videoController = VideoPlayerController.file(File(_videoPath!));
    await _videoController!.initialize();

    setState(() {
      _isPlayingVideo = true;
    });

    await _videoController!.play();

    // 视频播放完后自动停止
    _videoController!.addListener(() {
      if (_videoController!.value.position >= _videoController!.value.duration) {
        setState(() {
          _isPlayingVideo = false;
        });
      }
    });
  }

  /// 停止播放视频
  void _stopVideo() {
    if (_videoController != null) {
      _videoController!.pause();
      _videoController!.seekTo(Duration.zero);
      setState(() {
        _isPlayingVideo = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 返回实况选项和选择状态
        Navigator.pop(context, {
          'toggleSelect': false,
          'enableLiveVideo': _enableLiveVideo,
        });
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black87,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            '照片预览',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            // 选择/取消选择按钮
            IconButton(
              icon: Icon(
                _isSelected ? Icons.check_circle : Icons.check_circle_outline,
                color: _isSelected ? Colors.blue : Colors.white,
                size: 28,
              ),
              onPressed: () {
                Navigator.pop(context, {
                  'toggleSelect': true,
                  'enableLiveVideo': _enableLiveVideo,
                });
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // 图片/视频预览区域
            Expanded(
              child: Center(
                child: GestureDetector(
                  onLongPress: widget.isLivePhoto && _videoPath != null ? _playVideo : null,
                  onLongPressEnd: (_) => _stopVideo(),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 背景图片或视频缩略图
                      if (!_isPlayingVideo)
                        FutureBuilder<dynamic>(
                          future: widget.asset.type == AssetType.video
                              ? widget.asset.thumbnailDataWithSize(const ThumbnailSize(1000, 1000))
                              : widget.asset.file,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.done &&
                                snapshot.data != null) {
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
                            return const CircularProgressIndicator();
                          },
                        ),

                      // 视频播放按钮（纯视频）
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

                      // Live提示（非播放时，仅实况照片，不包括视频）
                      if (widget.isLivePhoto && !_isPlayingVideo && _videoPath != null && widget.asset.type != AssetType.video)
                        Positioned(
                          bottom: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.album, color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  '长按预览实况',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // 实况照片控制区域（不包括视频）
            if (widget.isLivePhoto && widget.asset.type != AssetType.video)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  border: Border(
                    top: BorderSide(color: Colors.grey[800]!),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          _enableLiveVideo ? Icons.album : Icons.image,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _enableLiveVideo ? '实况照片' : '静态照片',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: _enableLiveVideo,
                          onChanged: (value) {
                            setState(() => _enableLiveVideo = value);
                          },
                          activeColor: Colors.blue,
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _enableLiveVideo ? '将同时上传照片和实况视频' : '仅上传静态照片',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
