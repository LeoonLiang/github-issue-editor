import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/github.dart';
import '../theme/app_colors.dart';
import '../models/issue_image_info.dart';
import 'image_grid_preview.dart';
import 'image_preview_dialog.dart';

/// Issue 卡片组件
class IssueCard extends StatelessWidget {
  final GitHubIssue issue;
  final VoidCallback? onEdit;
  final VoidCallback? onQuickEdit;

  const IssueCard({
    Key? key,
    required this.issue,
    this.onEdit,
    this.onQuickEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final images = ImageGridPreview.parseImagesFromMarkdown(issue.body);

    // 计算相对时间
    final timeAgo = _getTimeAgo(issue.createdAt);

    // 提取内容预览（去除图片 Markdown）
    final contentPreview = _getContentPreview(issue.body);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // 顶部：状态标签 + Issue 编号 + 标签 + 时间
              Row(
              crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 状态标签
                  _buildStateLabel(issue.state, isDark),
                  SizedBox(width: 8),

                  // Issue 编号
                  _buildIssueNumberLabel(issue.number, isDark),

                // 标签列表
                if (issue.labels.isNotEmpty) ...[
                  SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: issue.labels
                          .map((label) => _buildLabel(label, isDark))
                          .toList(),
                    ),
                  ),
                ] else
                  Spacer(),

                  // 时间戳
                  Text(
                    timeAgo,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),

              // 标题
              Text(
                issue.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // 内容预览
              if (contentPreview.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  contentPreview,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // 九宫格图片预览
              if (images.isNotEmpty) ...[
                SizedBox(height: 16),
                ImageGridPreview(
                  images: images,
                onTap: (index) => _handleImagePreview(context, images, index),
                ),
              ],

              SizedBox(height: 16),

              // 底部操作栏
              _buildActionBar(context, isDark),
            ],
          ),
        ),
    );
  }

  /// 构建状态标签
  Widget _buildStateLabel(String state, bool isDark) {
    final isOpen = state.toLowerCase() == 'open';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen
            ? (isDark ? AppColors.successDark : AppColors.successLight)
            : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isOpen ? '开放' : '已关闭',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: isOpen
              ? (isDark ? AppColors.success : Color(0xFF059669))
              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        ),
      ),
    );
  }

  /// 构建 Issue 编号标签
  Widget _buildIssueNumberLabel(int number, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.primaryDark.withOpacity(0.3) : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '#$number',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: AppColors.primary,
        ),
      ),
    );
  }

  /// 构建标签
  Widget _buildLabel(String label, bool isDark) {
    // 为不同标签生成不同颜色
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.amber,
      Colors.cyan,
    ];
    final colorIndex = label.hashCode.abs() % colors.length;
    final color = colors[colorIndex];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.3) : color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isDark ? color.withOpacity(0.5) : color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isDark ? color.shade300 : color.shade700,
        ),
      ),
    );
  }

  /// 构建底部操作栏
  Widget _buildActionBar(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 快速编辑按钮
        TextButton(
          onPressed: onQuickEdit,
          style: TextButton.styleFrom(
            foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: Size(0, 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            '快速编辑',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        SizedBox(width: 8),

        // 编辑按钮（优先级最高）
        ElevatedButton(
          onPressed: onEdit,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark
                ? AppColors.primaryDark.withOpacity(0.3)
                : AppColors.primaryLight,
            foregroundColor: AppColors.primary,
            elevation: 0,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: Size(0, 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            '编辑',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// 处理查看 Issue
  void _handleViewIssue() async {
    final uri = Uri.parse(issue.htmlUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// 处理图片预览
  void _handleImagePreview(
      BuildContext context, List<IssueImageInfo> images, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => ImagePreviewDialog(
        images: images,
        initialIndex: initialIndex,
      ),
    );
  }

  /// 获取相对时间
  String _getTimeAgo(String createdAt) {
    try {
      final DateTime created = DateTime.parse(createdAt);
      final DateTime now = DateTime.now();
      final Duration difference = now.difference(created);

      if (difference.inDays > 365) {
        final years = (difference.inDays / 365).floor();
        return '$years 年前';
      } else if (difference.inDays > 30) {
        final months = (difference.inDays / 30).floor();
        return '$months 个月前';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} 天前';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} 小时前';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} 分钟前';
      } else {
        return '刚刚';
      }
    } catch (e) {
      return '';
    }
  }

  /// 获取内容预览（去除图片 Markdown）
  String _getContentPreview(String body) {
    if (body.isEmpty) return '';

    // 去除图片 Markdown
    String preview = body.replaceAll(
      RegExp(r'!\[image\]\([^\)]+\)\{[^\}]+\}', multiLine: true),
      '',
    );

    // 去除多余的空行
    preview = preview.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    preview = preview.trim();

    return preview;
  }
}
