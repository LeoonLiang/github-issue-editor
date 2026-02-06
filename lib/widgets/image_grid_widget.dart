import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reorderables/reorderables.dart';
import 'package:video_player/video_player.dart';
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
