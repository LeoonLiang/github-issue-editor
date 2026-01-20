import 'package:image_picker/image_picker.dart';

/// 上传状态枚举
enum UploadStatus {
  pending,   // 等待上传
  uploading, // 上传中
  success,   // 上传成功
  failed,    // 上传失败
}

/// 上传结果（包含所有需要的信息）
class UploadResult {
  final String imageUrl;
  final String videoUrl;
  final int width;
  final int height;
  final String thumbhash;
  final bool isVideo; // 是否是视频文件

  UploadResult({
    required this.imageUrl,
    required this.videoUrl,
    required this.width,
    required this.height,
    required this.thumbhash,
    this.isVideo = false,
  });

  /// 生成 Markdown 格式
  String toMarkdown() {
    // 如果是纯视频文件，使用 video 标签
    if (isVideo) {
      return '<video src="$imageUrl" controls width=$width height=$height></video>';
    }
    // 如果是实况照片，使用自定义格式
    else if (videoUrl.isNotEmpty) {
      return '![image]($imageUrl){liveVideo="$videoUrl" width=$width height=$height thumbhash="$thumbhash"}';
    }
    // 普通图片
    else {
      return '![image]($imageUrl){width=$width height=$height thumbhash="$thumbhash"}';
    }
  }
}

/// 单张图片上传状态
class ImageUploadState {
  final String id;              // 唯一标识
  final XFile file;             // 原始文件
  final String? thumbnailUrl;   // 缩略图 URL（用于显示）
  final UploadStatus status;    // 状态
  final double progress;        // 上传进度 0.0-1.0
  final UploadResult? result;   // 上传完成后的结果
  final String? error;          // 错误信息
  final bool isLivePhoto;       // 是否为实况照片
  final bool enableLiveVideo;   // 是否上传实况视频
  final bool isVideo;           // 是否为视频文件

  ImageUploadState({
    required this.id,
    required this.file,
    this.thumbnailUrl,
    this.status = UploadStatus.pending,
    this.progress = 0.0,
    this.result,
    this.error,
    this.isLivePhoto = false,
    this.enableLiveVideo = false,
    this.isVideo = false,
  });

  /// 复制并更新部分字段
  ImageUploadState copyWith({
    String? id,
    XFile? file,
    String? thumbnailUrl,
    UploadStatus? status,
    double? progress,
    UploadResult? result,
    String? error,
    bool? isLivePhoto,
    bool? enableLiveVideo,
    bool? isVideo,
  }) {
    return ImageUploadState(
      id: id ?? this.id,
      file: file ?? this.file,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      result: result ?? this.result,
      error: error ?? this.error,
      isLivePhoto: isLivePhoto ?? this.isLivePhoto,
      enableLiveVideo: enableLiveVideo ?? this.enableLiveVideo,
      isVideo: isVideo ?? this.isVideo,
    );
  }

  /// 是否正在上传
  bool get isUploading => status == UploadStatus.uploading;

  /// 是否成功
  bool get isSuccess => status == UploadStatus.success;

  /// 是否失败
  bool get isFailed => status == UploadStatus.failed;

  /// 是否可以重试
  bool get canRetry => status == UploadStatus.failed;
}
