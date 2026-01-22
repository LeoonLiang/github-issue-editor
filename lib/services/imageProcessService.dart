import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:thumbhash/thumbhash.dart' as Thumbhash;
import 'package:image_picker/image_picker.dart';
import 'package:motion_photos/motion_photos.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/upload_models.dart';
import '../models/app_config.dart';
import 'ossService.dart';
import 'image_edit_service.dart';

/// 图片处理服务 - 负责图片压缩、thumbhash 生成、实况照片处理等
class ImageProcessService {
  final OssService _ossService = OssService();
  final List<OSSConfig> _enabledOssList;
  final String _displayDomain;

  ImageProcessService(this._enabledOssList, this._displayDomain);

  /// 生成指定长度的随机字符串
  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
      length,
      (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ));
  }

  /// 提取实况照片的静态图片
  Future<File?> _extractStillImage(
    String originalPath,
    VideoIndex videoIndex, {
    String? outputFileName,
  }) async {
    try {
      File originalFile = File(originalPath);
      Uint8List originalBytes = await originalFile.readAsBytes();

      // 截取 JPEG 部分（去掉视频数据）
      int imageDataLength = videoIndex.start;
      Uint8List imageBytes = originalBytes.sublist(0, imageDataLength);

      // 生成新图片文件路径
      Directory tempDir = await getTemporaryDirectory();
      String safeFileName = outputFileName ?? 'extracted_image.jpg';
      String newImagePath = path.join(tempDir.path, safeFileName);

      // 保存 JPEG 数据到新文件
      File newImageFile = File(newImagePath);
      await newImageFile.writeAsBytes(imageBytes);

      return newImageFile;
    } catch (e) {
      print('Error extracting still image: $e');
      return null;
    }
  }

  /// 生成 thumbhash
  Future<String> _generateThumbhash(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(bytes);

      if (decodedImage == null) return '';

      final width = decodedImage.width;
      final height = decodedImage.height;

      // 生成缩略图用于 ThumbHash（最大 100x100，等比缩放）
      final thumbWidth = width > height ? 100 : (100 * width ~/ height);
      final thumbHeight = height > width ? 100 : (100 * height ~/ width);

      final thumbnail = img.copyResize(
        decodedImage,
        width: thumbWidth,
        height: thumbHeight,
      );

      // RGBA 数据
      final rgbaBytes =
          Uint8List.fromList(thumbnail.getBytes(format: img.Format.rgba));

      final thumbhashBytes = Thumbhash.rgbaToThumbHash(
        thumbnail.width,
        thumbnail.height,
        rgbaBytes,
      );

      return base64.encode(thumbhashBytes);
    } catch (e) {
      print('Error generating thumbhash: $e');
      return '';
    }
  }

  /// 获取图片尺寸
  Future<Map<String, int>> _getImageDimensions(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(bytes);

      if (decodedImage != null) {
        return {
          'width': decodedImage.width,
          'height': decodedImage.height,
        };
      }
    } catch (e) {
      print('Error getting image dimensions: $e');
    }
    return {'width': 0, 'height': 0};
  }

  /// 处理单张图片并上传（核心方法）
  /// 返回 Stream<double> 用于进度跟踪
  Stream<UploadResult> processAndUpload(XFile image, {bool enableLiveVideo = true, bool isVideo = false}) async* {
    print('========== 开始处理图片 ==========');
    print('图片路径: ${image.path}');
    print('是否为视频: $isVideo');
    print('启用的OSS数量: ${_enabledOssList.length}');
    for (var oss in _enabledOssList) {
      print('OSS配置: ${oss.name} - ${oss.endpoint}/${oss.bucket}');
    }

    final randomStr = _generateRandomString(12);
    print('生成随机文件名: $randomStr');

    // 如果是视频文件，直接上传
    if (isVideo) {
      print('>>> 处理视频文件');
      try {
        final originalFile = File(image.path);
        final originalExtension = path.extension(originalFile.path);
        final originalFileName = '$randomStr$originalExtension';
        print('原始文件: ${originalFile.path}');
        print('目标文件名: $originalFileName');

        print('开始上传视频文件...');
        final videoUrls = await _ossService.uploadFileToS3(
          originalFile.path,
          'video/$originalFileName',
          _enabledOssList,
          fileType: 'video/mp4',
        );
        if (videoUrls.isNotEmpty) {
          final videoUrl = _selectBestUrl(videoUrls, 'video/$originalFileName');
          print('视频上传成功: $videoUrl');

          // 获取视频尺寸（可选）
          int width = 0, height = 0;
          // 视频没有 thumbhash

          print('========== 视频处理完成 ==========');
          print('最终结果: videoUrl=$videoUrl, ${width}x$height');

          yield UploadResult(
            imageUrl: videoUrl,
            videoUrl: '',
            width: width,
            height: height,
            thumbhash: '',
            isVideo: true,
          );
          return;
        } else {
          throw Exception('视频上传失败：所有OSS均上传失败');
        }
      } catch (e, stackTrace) {
        print('!!! 视频文件处理失败: $e');
        print('堆栈跟踪: $stackTrace');
        rethrow;
      }
    }

    // 以下是原有的图片处理逻辑

    // 声明变量
    String imageUrl = '', videoUrl = '';
    File? finalImageFile;

    // 检查是否为编辑后的图片（路径包含 'edited_images'）
    final isEditedImage = image.path.contains('edited_images');
    String? originalFilePathForVideo;
    bool isEditedLivePhoto = false;

    if (isEditedImage) {
      print('>>> 检测到编辑后的图片');
      // 从文件名中提取 assetId (格式: {assetId}_{timestamp}.jpg)
      final fileName = path.basename(image.path);
      final assetId = fileName.split('_').first;
      print('提取的 AssetId: $assetId');

      // 从 ImageEditService 获取编辑信息
      final editedInfo = ImageEditService.instance.getEditedInfo(assetId);
      if (editedInfo != null && editedInfo.isLivePhoto && editedInfo.originalFilePath != null) {
        print('>>> 编辑后的图片是 live photo，原始路径: ${editedInfo.originalFilePath}');
        isEditedLivePhoto = true;
        originalFilePathForVideo = editedInfo.originalFilePath;
      }
    }

    // 对于编辑后的 live photo：图片已经是编辑后的纯图片，视频需要从原始文件提取
    if (isEditedLivePhoto && originalFilePathForVideo != null && enableLiveVideo) {
      print('>>> 处理编辑后的实况照片（编辑图片 + 原始视频）');
      try {
        // 图片部分：直接上传编辑后的图片
        final editedImageFile = File(image.path);
        print('开始上传编辑后的图片...');
        final imageUrls = await _ossService.uploadFileToS3(
          editedImageFile.path,
          'img/$randomStr.jpg',
          _enabledOssList,
        );

        if (imageUrls.isEmpty) {
          throw Exception('图片上传失败：所有OSS均上传失败');
        }

        imageUrl = _selectBestUrl(imageUrls, 'img/$randomStr.jpg');
        finalImageFile = editedImageFile;
        print('编辑后图片上传成功: $imageUrl');

        // 视频部分：从原始文件中提取并上传
        print('开始从原始文件提取视频...');
        final originalMotionPhotos = MotionPhotos(originalFilePathForVideo);
        final tempDir = await getTemporaryDirectory();
        final motionVideoFile = await originalMotionPhotos.getMotionVideoFile(
          tempDir,
          fileName: 'motion_video_$randomStr.mp4',
        );
        print('提取视频文件: ${motionVideoFile.path}');

        print('开始上传实况照片视频部分...');
        final videoUrls = await _ossService.uploadFileToS3(
          motionVideoFile.path,
          'video/$randomStr.mp4',
          _enabledOssList,
          fileType: 'video/mp4',
        );
        if (videoUrls.isNotEmpty) {
          videoUrl = _selectBestUrl(videoUrls, 'video/$randomStr.mp4');
          print('视频上传成功: $videoUrl');
        } else {
          print('!!! 视频上传失败');
          videoUrl = '';
        }
      } catch (e, stackTrace) {
        print('!!! 处理编辑后的实况照片失败: $e');
        print('堆栈跟踪: $stackTrace');
        rethrow;
      }
    } else {
      // 原有的实况照片处理逻辑
      final motionPhotos = MotionPhotos(image.path);
      final bool isMotionPhoto = await motionPhotos.isMotionPhoto();
      print('是否为实况照片: $isMotionPhoto');

      // 处理实况照片
      if (isMotionPhoto && enableLiveVideo) {
        print('>>> 处理实况照片（带视频）');
        try {
        // 用户选择上传实况视频
        VideoIndex? videoIndex = await motionPhotos.getMotionVideoIndex();
        print('获取视频索引成功');

        File? motionImageFile = await _extractStillImage(
          image.path,
          videoIndex!,
          outputFileName: 'motion_image_$randomStr.jpg',
        );
        print('提取静态图片: ${motionImageFile?.path}');

        final tempDir = await getTemporaryDirectory();
        final motionVideoFile = await motionPhotos.getMotionVideoFile(
          tempDir,
          fileName: 'motion_video_$randomStr.mp4',
        );
        print('提取视频文件: ${motionVideoFile.path}');

        if (motionImageFile != null) {
          print('开始上传实况照片图片部分...');
          final imageUrls = await _ossService.uploadFileToS3(
            motionImageFile.path,
            'img/$randomStr.jpg',
            _enabledOssList,
          );
          // 使用智能选择，优先选择有公网域名的URL
          if (imageUrls.isNotEmpty) {
            imageUrl = _selectBestUrl(imageUrls, 'img/$randomStr.jpg');
            finalImageFile = motionImageFile;
            print('图片上传成功: $imageUrl');
          } else {
            throw Exception('图片上传失败：所有OSS均上传失败');
          }
        }

        print('开始上传实况照片视频部分...');
        final videoUrls = await _ossService.uploadFileToS3(
          motionVideoFile.path,
          'video/$randomStr.mp4',
          _enabledOssList,
          fileType: 'video/mp4',
        );
        // 使用智能选择，优先选择有公网域名的URL
        if (videoUrls.isNotEmpty) {
          videoUrl = _selectBestUrl(videoUrls, 'video/$randomStr.mp4');
          print('视频上传成功: $videoUrl');
        } else {
          throw Exception('视频上传失败：所有OSS均上传失败');
        }
        } catch (e, stackTrace) {
          print('!!! 实况照片处理失败: $e');
          print('堆栈跟踪: $stackTrace');
          rethrow;
        }
      } else if (isMotionPhoto && !enableLiveVideo) {
        print('>>> 处理实况照片（仅静态图片）');
        try {
          // 用户选择不上传实况视频，仅上传静态图片
          VideoIndex? videoIndex = await motionPhotos.getMotionVideoIndex();
          print('获取视频索引成功');

          File? motionImageFile = await _extractStillImage(
            image.path,
            videoIndex!,
            outputFileName: 'motion_image_$randomStr.jpg',
          );
          print('提取静态图片: ${motionImageFile?.path}');

          if (motionImageFile != null) {
            print('开始上传静态图片...');
            final imageUrls = await _ossService.uploadFileToS3(
              motionImageFile.path,
              'img/$randomStr.jpg',
              _enabledOssList,
            );
            if (imageUrls.isNotEmpty) {
              imageUrl = _selectBestUrl(imageUrls, 'img/$randomStr.jpg');
              finalImageFile = motionImageFile;
              print('图片上传成功: $imageUrl');
            } else {
              throw Exception('图片上传失败：所有OSS均上传失败');
            }
          }
          // 不上传视频，videoUrl保持为空
        } catch (e, stackTrace) {
          print('!!! 实况照片（静态）处理失败: $e');
          print('堆栈跟踪: $stackTrace');
          rethrow;
        }
      } else {
        print('>>> 处理普通图片');
        try {
          // 处理普通图片
          final originalFile = File(image.path);
          final originalExtension = path.extension(originalFile.path);
          final originalFileName = '$randomStr$originalExtension';
          print('原始文件: ${originalFile.path}');
          print('目标文件名: $originalFileName');

          print('开始上传普通图片...');
          final imageUrls = await _ossService.uploadFileToS3(
            originalFile.path,
            'img/$originalFileName',
            _enabledOssList,
          );
          if (imageUrls.isNotEmpty) {
            imageUrl = _selectBestUrl(imageUrls, 'img/$originalFileName');
            finalImageFile = originalFile;
            print('图片上传成功: $imageUrl');
          } else {
            throw Exception('图片上传失败：所有OSS均上传失败');
          }
        } catch (e, stackTrace) {
          print('!!! 普通图片处理失败: $e');
          print('堆栈跟踪: $stackTrace');
          rethrow;
        }
      }
    }

    // 获取图片信息
    print('开始获取图片元数据...');
    int width = 0, height = 0;
    String thumbhash = '';

    if (finalImageFile != null) {
      print('处理最终图片文件: ${finalImageFile.path}');
      final dimensions = await _getImageDimensions(finalImageFile);
      width = dimensions['width']!;
      height = dimensions['height']!;
      print('图片尺寸: ${width}x$height');

      thumbhash = await _generateThumbhash(finalImageFile);
      print('thumbhash: $thumbhash');
    }

    print('========== 图片处理完成 ==========');
    print('最终结果: imageUrl=$imageUrl, videoUrl=$videoUrl, ${width}x$height');

    yield UploadResult(
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      width: width,
      height: height,
      thumbhash: thumbhash,
      isVideo: false,
    );
  }

  /// 从上传结果中选择最佳URL（优先使用全局回显域名）
  String _selectBestUrl(Map<String, String> uploadResults, String fileName) {
    if (uploadResults.isEmpty) {
      return '';
    }

    // 优先使用全局回显域名
    if (_displayDomain.isNotEmpty) {
      String domain = _displayDomain;
      // 如果域名没有协议前缀，自动添加 https://
      if (!domain.startsWith('http://') && !domain.startsWith('https://')) {
        domain = 'https://$domain';
      }

      // 直接使用上传时的文件名（不包含 bucket）
      final displayUrl = '$domain/$fileName';
      print('使用全局回显域名: $displayUrl');
      return displayUrl;
    }

    // 其次检查每个 OSS 配置，优先选择有 publicDomain 的
    for (var i = 0; i < _enabledOssList.length; i++) {
      final oss = _enabledOssList[i];
      final url = uploadResults[oss.name];

      if (url != null && oss.publicDomain.isNotEmpty) {
        // 这个 OSS 配置了公网域名，优先使用
        print('选择有公网域名的 OSS: ${oss.name} -> $url');
        return url;
      }
    }

    // 如果都没有配置公网域名，就选第一个
    final anyUrl = uploadResults.values.first;
    print('使用第一个上传成功的 URL: $anyUrl');
    return anyUrl;
  }

  /// 生成缩略图 URL（用于显示）
  String getThumbnailUrl(String imageUrl) {
    // 不添加参数，直接使用原图URL
    // 因为不同OSS的参数格式不同，可能导致400错误
    // 缓存管理器会自动处理图片缓存
    return imageUrl;
  }
}
