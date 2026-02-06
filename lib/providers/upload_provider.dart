import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/upload_models.dart';
import '../services/imageProcessService.dart';
import '../screens/custom_image_picker.dart';
import 'config_provider.dart';

/// 图片处理服务 Provider
final imageProcessServiceProvider = Provider<ImageProcessService>((ref) {
  final config = ref.watch(configProvider);
  final enabledOssList = config.enabledOSSList;
  final displayDomain = config.editor.displayDomain;
  final imagePrefix = config.editor.imagePrefix;
  final videoPrefix = config.editor.videoPrefix;
  final githubImage = config.githubImage;
  return ImageProcessService(
    enabledOssList,
    displayDomain,
    imagePrefix,
    videoPrefix,
    githubImageConfig: githubImage,
  );
});

/// 上传队列状态管理
class UploadQueueNotifier extends StateNotifier<List<ImageUploadState>> {
  final ImageProcessService _imageProcessService;
  static const int maxConcurrentUploads = 3; // 最大并发上传数
  final Uuid _uuid = const Uuid();

  UploadQueueNotifier(this._imageProcessService) : super([]);

  /// 添加图片到队列
  Future<void> addImages(List<XFile> files) async {
    final newStates = files.map((file) {
      return ImageUploadState(
        id: _uuid.v4(),
        file: file,
        status: UploadStatus.pending,
      );
    }).toList();

    state = [...state, ...newStates];

    // 触发上传
    _processQueue();
  }

  /// 添加带实况选项的图片到队列
  Future<void> addImagesWithLiveOptions(List<SelectedImageInfo> selectedImages) async {
    final newStates = selectedImages.map((imageInfo) {
      return ImageUploadState(
        id: _uuid.v4(),
        file: imageInfo.file,
        status: UploadStatus.pending,
        isLivePhoto: imageInfo.isLivePhoto,
        enableLiveVideo: imageInfo.enableLiveVideo,
        isVideo: imageInfo.isVideo,
      );
    }).toList();

    state = [...state, ...newStates];

    // 触发上传
    _processQueue();
  }

  /// 处理上传队列（控制并发）
  Future<void> _processQueue() async {
    // 获取当前正在上传的数量
    final uploadingCount = state.where((s) => s.isUploading).length;
    print('>>> 处理上传队列: 当前上传中=${uploadingCount}, 最大并发=${maxConcurrentUploads}');

    // 如果已达到最大并发数，等待
    if (uploadingCount >= maxConcurrentUploads) {
      print('已达到最大并发数，等待...');
      return;
    }

    // 获取待上传的图片
    final pendingItems = state.where((s) => s.status == UploadStatus.pending).toList();
    print('待上传图片数: ${pendingItems.length}');

    // 计算可以开始的上传数量
    final availableSlots = maxConcurrentUploads - uploadingCount;
    final itemsToUpload = pendingItems.take(availableSlots).toList();
    print('本次开始上传: ${itemsToUpload.length} 张');

    // 开始上传
    for (final item in itemsToUpload) {
      print('开始上传图片: ${item.id}');
      _uploadImage(item);
    }
  }

  /// 上传单张图片
  Future<void> _uploadImage(ImageUploadState uploadState) async {
    print('\n########## 开始上传图片 ##########');
    print('图片ID: ${uploadState.id}');
    print('图片路径: ${uploadState.file.path}');
    print('是否实况照片: ${uploadState.isLivePhoto}');
    print('是否上传实况视频: ${uploadState.enableLiveVideo}');

    // 更新状态为上传中
    _updateState(uploadState.id, uploadState.copyWith(
      status: UploadStatus.uploading,
      progress: 0.0,
    ));

    try {
      // 使用 ImageProcessService 处理和上传（传递实况视频选项和视频标记）
      print('调用 ImageProcessService.processAndUpload...');
      await for (final result in _imageProcessService.processAndUpload(
        uploadState.file,
        enableLiveVideo: uploadState.enableLiveVideo,
        isVideo: uploadState.isVideo,
      )) {
        print('收到上传结果: ${result.imageUrl}');

        // 生成缩略图 URL
        final thumbnailUrl = _imageProcessService.getThumbnailUrl(result.imageUrl);
        print('生成缩略图URL: $thumbnailUrl');

        // 更新状态为成功
        _updateState(uploadState.id, uploadState.copyWith(
          status: UploadStatus.success,
          progress: 1.0,
          result: result,
          thumbnailUrl: thumbnailUrl,
        ));
        print('✓ 图片上传成功');

        // 继续处理队列中的下一个
        _processQueue();
      }
    } catch (e, stackTrace) {
      print('!!!!!! 图片上传失败 !!!!!!');
      print('图片ID: ${uploadState.id}');
      print('错误类型: ${e.runtimeType}');
      print('错误详情: $e');
      print('堆栈跟踪:');
      print(stackTrace);

      // 更新状态为失败
      _updateState(uploadState.id, uploadState.copyWith(
        status: UploadStatus.failed,
        error: e.toString(),
      ));

      // 继续处理队列中的下一个
      _processQueue();
    }
    print('########## 图片上传流程结束 ##########\n');
  }

  /// 更新单个上传状态
  void _updateState(String id, ImageUploadState newState) {
    state = [
      for (final item in state)
        if (item.id == id) newState else item,
    ];
  }

  /// 删除图片
  void removeImage(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  /// 重新排序
  void reorderImages(int oldIndex, int newIndex) {
    final items = [...state];
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    state = items;
  }

  /// 重试上传失败的图片
  Future<void> retryUpload(String id) async {
    final item = state.firstWhere((s) => s.id == id);
    if (item.isFailed) {
      _updateState(id, item.copyWith(
        status: UploadStatus.pending,
        error: null,
      ));
      _processQueue();
    }
  }

  /// 清空所有
  void clear() {
    state = [];
  }

  /// 获取所有成功上传的结果（按顺序）
  List<UploadResult> getSuccessResults() {
    return state
        .where((s) => s.isSuccess && s.result != null)
        .map((s) => s.result!)
        .toList();
  }

  /// 是否有正在上传的图片
  bool get hasUploading {
    return state.any((s) => s.isUploading);
  }

  /// 是否所有图片都已完成（成功或失败）
  bool get allCompleted {
    return state.isNotEmpty && state.every((s) => s.isSuccess || s.isFailed);
  }
}

/// 上传队列 Provider
final uploadQueueProvider =
    StateNotifierProvider<UploadQueueNotifier, List<ImageUploadState>>((ref) {
  final imageProcessService = ref.watch(imageProcessServiceProvider);
  return UploadQueueNotifier(imageProcessService);
});

/// 编辑器状态管理
class EditorState {
  final String title;
  final String content;
  final String selectedLabel;
  final bool useGrid;

  EditorState({
    this.title = '',
    this.content = '',
    this.selectedLabel = '',
    this.useGrid = true,
  });

  EditorState copyWith({
    String? title,
    String? content,
    String? selectedLabel,
    bool? useGrid,
  }) {
    return EditorState(
      title: title ?? this.title,
      content: content ?? this.content,
      selectedLabel: selectedLabel ?? this.selectedLabel,
      useGrid: useGrid ?? this.useGrid,
    );
  }
}

/// 编辑器状态 Provider
class EditorNotifier extends StateNotifier<EditorState> {
  EditorNotifier() : super(EditorState());

  void setTitle(String title) {
    state = state.copyWith(title: title);
  }

  void setContent(String content) {
    state = state.copyWith(content: content);
  }

  void setSelectedLabel(String label) {
    state = state.copyWith(selectedLabel: label);
  }

  void setUseGrid(bool useGrid) {
    state = state.copyWith(useGrid: useGrid);
  }

  void clear() {
    state = EditorState();
  }
}

final editorProvider = StateNotifierProvider<EditorNotifier, EditorState>((ref) {
  return EditorNotifier();
});
