import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reorderables/reorderables.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/upload_models.dart';
import '../models/issue_image_info.dart';
import '../providers/upload_provider.dart';
import '../screens/custom_image_picker.dart';
import 'image_upload_card.dart';
import 'image_preview_dialog.dart';

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
              // 由于添加按钮在最后一个位置，需要确保不拖动添加按钮
              if (oldIndex >= uploadStates.length || newIndex >= uploadStates.length) {
                return; // 忽略添加按钮的拖动
              }
              uploadNotifier.reorderImages(oldIndex, newIndex);
            },
            children: [
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
                        _showImagePreview(context, ref, uploadState);
                      } else if (uploadState.isFailed) {
                        _showErrorDialog(context, uploadState);
                      }
                    },
                  ),
                );
              }).toList(),
              // 添加图片按钮放在最后
              Container(
                key: const ValueKey('add_button'),
                width: (MediaQuery.of(context).size.width - 32) / 3 - 8,
                child: _buildAddButton(context, ref, uploadStates.length),
              ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _pickImages(context, ref, currentCount),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isDark ? Color(0xFF2d3748) : Color(0xFFd1d5db),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Color(0xFF4a5568) : Color(0xFFe5e7eb),
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.add,
            size: 32,
            color: isDark ? Color(0xFF9ca3af) : Color(0xFF6b7280),
          ),
        ),
      ),
    );
  }

  /// 选择图片 - 显示相册/相机选择
  Future<void> _pickImages(BuildContext context, WidgetRef ref, int currentCount) async {
    // 显示选择对话框
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('从相册选择'),
                onTap: () => Navigator.pop(context, 'album'),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('拍照'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('取消'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );

    if (choice == null) return;

    if (choice == 'album') {
      await _pickFromAlbum(context, ref, currentCount);
    } else if (choice == 'camera') {
      await _pickFromCamera(context, ref);
    }
  }

  /// 从相册选择
  Future<void> _pickFromAlbum(BuildContext context, WidgetRef ref, int currentCount) async {
    final uploadNotifier = ref.read(uploadQueueProvider.notifier);

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

  /// 从相机拍照
  Future<void> _pickFromCamera(BuildContext context, WidgetRef ref) async {
    final uploadNotifier = ref.read(uploadQueueProvider.notifier);
    final picker = ImagePicker();

    try {
      // 调用相机拍照
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo == null) return;

      // 询问用户是否需要编辑
      final shouldEdit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('拍照成功'),
          content: const Text('是否需要编辑这张照片？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('直接使用'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('编辑'),
            ),
          ],
        ),
      );

      File finalFile = File(photo.path);

      // 如果需要编辑，打开编辑器
      if (shouldEdit == true && context.mounted) {
        bool isEditingComplete = false;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProImageEditor.file(
              finalFile,
              configs: ProImageEditorConfigs(
                i18n: const I18n(
                  various: I18nVarious(
                    loadingDialogMsg: '请稍等...',
                    closeEditorWarningTitle: '关闭编辑器？',
                    closeEditorWarningMessage: '确定要关闭编辑器吗？您的更改将不会被保存。',
                    closeEditorWarningConfirmBtn: '确定',
                    closeEditorWarningCancelBtn: '取消',
                  ),
                  paintEditor: I18nPaintEditor(
                    bottomNavigationBarText: '画笔',
                    back: '返回',
                    done: '完成',
                    lineWidth: '线宽',
                    changeOpacity: '调整透明度',
                    moveAndZoom: '缩放',
                  ),
                  textEditor: I18nTextEditor(
                    bottomNavigationBarText: '文字',
                    inputHintText: '输入文字',
                    back: '返回',
                    done: '完成',
                  ),
                  cropRotateEditor: I18nCropRotateEditor(
                    bottomNavigationBarText: '裁剪/旋转',
                    rotate: '旋转',
                    ratio: '比例',
                    back: '返回',
                    done: '完成',
                  ),
                  filterEditor: I18nFilterEditor(
                    bottomNavigationBarText: '滤镜',
                    back: '返回',
                    done: '完成',
                  ),
                  blurEditor: I18nBlurEditor(
                    bottomNavigationBarText: '模糊',
                    back: '返回',
                    done: '完成',
                  ),
                ),
              ),
              callbacks: ProImageEditorCallbacks(
                onImageEditingComplete: (Uint8List bytes) async {
                  if (isEditingComplete) return;
                  isEditingComplete = true;

                  try {
                    // 保存编辑后的图片到临时文件
                    final tempDir = await getTemporaryDirectory();
                    final fileName = 'camera_edited_${DateTime.now().millisecondsSinceEpoch}.jpg';
                    final filePath = path.join(tempDir.path, fileName);
                    final file = File(filePath);
                    await file.writeAsBytes(bytes);

                    finalFile = file;

                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    print('保存编辑失败: $e');
                    isEditingComplete = false;
                  }
                },
              ),
            ),
          ),
        );
      }

      // 上传图片
      if (context.mounted) {
        final result = SelectedImageInfo(
          file: XFile(finalFile.path),
          isLivePhoto: false,
          enableLiveVideo: false,
          isVideo: false,
        );

        await uploadNotifier.addImagesWithLiveOptions([result]);
      }
    } catch (e) {
      print('Error picking from camera: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: $e')),
        );
      }
    }
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
  void _showImagePreview(BuildContext context, WidgetRef ref, ImageUploadState currentUploadState) {
    if (currentUploadState.result == null) return;

    // 获取所有已上传成功的图片
    final allUploadStates = ref.read(uploadQueueProvider);
    final successfulUploads = allUploadStates.where((state) => state.isSuccess).toList();

    // 转换为 IssueImageInfo 格式
    final images = successfulUploads.map((state) {
      return IssueImageInfo(
        url: state.result!.imageUrl,
        liveVideo: state.result!.videoUrl.isNotEmpty
            ? state.result!.videoUrl
            : null,
      );
    }).toList();

    // 找到当前点击图片的索引
    final currentIndex = successfulUploads.indexWhere((state) => state.id == currentUploadState.id);

    // 准备上传链接数据（用于当前图片）
    final uploadLinkData = UploadLinkData(
      imageUrl: currentUploadState.result!.imageUrl,
      videoUrl: currentUploadState.result!.videoUrl.isNotEmpty
          ? currentUploadState.result!.videoUrl
          : null,
      markdown: currentUploadState.result!.toMarkdown(),
    );

    showDialog(
      context: context,
      builder: (context) => ImagePreviewDialog(
        images: images,
        initialIndex: currentIndex >= 0 ? currentIndex : 0,
        uploadLinkData: uploadLinkData,
      ),
    );
  }

}
