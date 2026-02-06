import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import '../providers/config_provider.dart';
import '../providers/github_provider.dart';
import '../providers/labels_provider.dart';
import '../services/github.dart';
import '../models/app_config.dart';
import '../theme/app_colors.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/issue_card.dart';
import 'publish_screen.dart';

class IssueListScreen extends ConsumerStatefulWidget {
  const IssueListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<IssueListScreen> createState() => _IssueListScreenState();
}

class _IssueListScreenState extends ConsumerState<IssueListScreen> {
  String _selectedLabel = 'all';
  String _selectedState = 'all'; // all, open, closed
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // 距离底部还有200px时开始加载
      final params = IssuesParams(label: _selectedLabel, state: _selectedState);
      ref.read(issuesProvider(params).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configProvider);
    final labelsState = ref.watch(labelsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context, config, isDark),
      body: !config.isConfigured
          ? _buildEmptyState()
          : Column(
              children: [
                SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top),

                // 搜索栏
                SearchBarWidget(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),

                // 标签过滤器
                labelsState.isLoading
                    ? Container(
                        height: 50,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : _buildLabelFilter(['all', ...labelsState.labels], isDark),

                // Issues 列表
                Expanded(
                  child: _buildIssueList(),
                ),
              ],
            ),
    );
  }

  /// 构建 AppBar（毛玻璃效果）
  PreferredSizeWidget _buildAppBar(BuildContext context, config, bool isDark) {
    return AppBar(
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: isDark
                ? AppColors.darkBackground.withOpacity(0.8)
                : AppColors.lightBackground.withOpacity(0.8),
          ),
        ),
      ),
      title: Column(
        children: [
          Text(
            config.isConfigured
                ? '${config.github.owner}/${config.github.repo}'
                : 'Blog Feed',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (config.isConfigured)
            Text(
              'repo: ${config.github.owner}/${config.github.repo}',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
        ],
      ),
      centerTitle: true,
      actions: [
        // 圆形加号按钮
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.add, size: 24),
              color: Colors.white,
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PublishScreen(),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// 标签过滤器
  Widget _buildLabelFilter(List<String> labels, bool isDark) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length + 1, // +1 for state filter chips
        separatorBuilder: (context, index) => SizedBox(width: 8),
        itemBuilder: (context, index) {
          // State filter chips (Open/Closed)
          if (index == 0) {
            return Row(
              children: [
                _buildChip(
                  label: '全部文章',
                  isSelected: _selectedLabel == 'all' && _selectedState == 'all',
                  onTap: () {
                    setState(() {
                      _selectedLabel = 'all';
                      _selectedState = 'all';
                    });
                  },
                  isDark: isDark,
                ),
                SizedBox(width: 8),
                _buildChip(
                  label: '开放中',
                  icon: Icons.radio_button_checked,
                  iconColor: AppColors.success,
                  isSelected: _selectedState == 'open',
                  onTap: () {
                    setState(() {
                      _selectedState = 'open';
                    });
                  },
                  isDark: isDark,
                ),
                SizedBox(width: 8),
              ],
            );
          }

          final label = labels[index - 1];
          if (label == 'all') return SizedBox.shrink();

          return _buildChip(
            label: label,
            isSelected: _selectedLabel == label,
            onTap: () {
              setState(() {
                _selectedLabel = label;
              });
            },
            isDark: isDark,
          );
        },
      ),
    );
  }

  /// 构建单个 Chip
  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    IconData? icon,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : (iconColor ?? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
              ),
              SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 空状态提示
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.settings_suggest_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            '请先配置 GitHub 和 OSS',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '完成配置后即可开始管理文章',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  /// Issue 列表
  Widget _buildIssueList() {
    final params = IssuesParams(label: _selectedLabel, state: _selectedState);
    final issuesState = ref.watch(issuesProvider(params));

    // 应用搜索过滤
    List<GitHubIssue> filteredIssues = issuesState.issues;
    if (_searchQuery.isNotEmpty) {
      filteredIssues = filteredIssues.where((issue) {
        final query = _searchQuery.toLowerCase();
        return issue.title.toLowerCase().contains(query) ||
               issue.body.toLowerCase().contains(query);
      }).toList();
    }

    if (issuesState.error != null && issuesState.issues.isEmpty) {
      return _buildErrorState(params);
    }

    if (filteredIssues.isEmpty && !issuesState.isLoading) {
      return _buildEmptySearchState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(issuesProvider(params).notifier).refresh();
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80), // 为底部导航栏留空间
        itemCount: filteredIssues.length + (issuesState.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= filteredIssues.length) {
            // 加载更多指示器
            return Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: issuesState.isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : SizedBox.shrink(),
            );
          }

          return IssueCard(
            issue: filteredIssues[index],
            onEdit: () => _editIssue(filteredIssues[index]),
            onQuickEdit: () => _quickEditIssue(filteredIssues[index]),
          );
        },
      ),
    );
  }

  /// 错误状态
  Widget _buildErrorState(IssuesParams params) {
    final issuesState = ref.watch(issuesProvider(params));
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 80, color: AppColors.error.withOpacity(0.5)),
          const SizedBox(height: 24),
          Text(
            '加载失败',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            issuesState.error ?? 'Unknown error',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(issuesProvider(params).notifier).refresh();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  /// 空搜索结果状态
  Widget _buildEmptySearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isEmpty ? '暂无文章' : '没有找到匹配的文章',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? '尝试切换筛选条件或发布新文章'
                : '尝试使用其他关键词搜索',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  /// 编辑 Issue
  Future<void> _editIssue(GitHubIssue issue) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublishScreen(issue: issue),
      ),
    ).then((_) {
      // 从发布页面返回后刷新列表
      final params = IssuesParams(label: _selectedLabel, state: _selectedState);
      ref.read(issuesProvider(params).notifier).refresh();
    });
  }

  /// 快速编辑 Issue（查看和编辑 Markdown 源数据）
  Future<void> _quickEditIssue(GitHubIssue issue) async {
    // 从缓存获取标签列表
    final availableLabels = await ref.read(labelsProvider.notifier).getLabels();
    final config = ref.read(configProvider);
    final githubService = GitHubService(config.github);

    final result = await showModalBottomSheet<_QuickEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _QuickEditDialog(
        initialTitle: issue.title,
        initialBody: issue.body,
        initialLabels: issue.labels,
        availableLabels: availableLabels,
        htmlUrl: issue.htmlUrl,
        state: issue.state,
      ),
    );

    // 如果用户点击了保存，更新 Issue
    if (result != null) {
      try {
        await githubService.updateGitHubIssue(
          issue.number,
          result.title,
          result.body,
          result.labels,
        );

        // 如果需要关闭 Issue
        if (result.shouldClose) {
          await githubService.closeGitHubIssue(issue.number);
        }

        // 刷新列表
        final params =
            IssuesParams(label: _selectedLabel, state: _selectedState);
        ref.read(issuesProvider(params).notifier).refresh();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.shouldClose ? 'Issue 已更新并关闭' : '保存成功'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('保存失败: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}

/// 快速编辑结果
class _QuickEditResult {
  final String title;
  final String body;
  final List<String> labels;
  final bool shouldClose;

  _QuickEditResult({
    required this.title,
    required this.body,
    required this.labels,
    this.shouldClose = false,
  });
}

/// 快速编辑对话框
class _QuickEditDialog extends StatefulWidget {
  final String initialTitle;
  final String initialBody;
  final List<String> initialLabels;
  final List<String> availableLabels;
  final String htmlUrl;
  final String state;

  const _QuickEditDialog({
    required this.initialTitle,
    required this.initialBody,
    required this.initialLabels,
    required this.availableLabels,
    required this.htmlUrl,
    required this.state,
  });

  @override
  State<_QuickEditDialog> createState() => _QuickEditDialogState();
}

class _QuickEditDialogState extends State<_QuickEditDialog> {
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  late Set<String> _selectedLabels;
  bool _shouldClose = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _bodyController = TextEditingController(text: widget.initialBody);
    _selectedLabels = Set.from(widget.initialLabels);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOpen = widget.state.toLowerCase() == 'open';
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.92,
      decoration: BoxDecoration(
        color: isDark
            ? Color(0xFF101622).withOpacity(0.95)
            : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 25,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖动手柄
          Container(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // 标题栏
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 16, 16),
            child: Row(
              children: [
                Text(
                  '快速编辑',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                    letterSpacing: -0.5,
                  ),
                ),
                Spacer(),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, size: 18),
                    color: isDark ? Colors.white : Colors.black,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),

          // 内容区域
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题输入
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(bottom: 8, left: 4),
                        child: Text(
                          '标题',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.white.withOpacity(0.8)
                                : Colors.black.withOpacity(0.6),
                          ),
                        ),
                      ),
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: '输入标题...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.black.withOpacity(0.1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.black.withOpacity(0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: AppColors.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.black.withOpacity(0.02),
                          contentPadding: EdgeInsets.all(15),
                        ),
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Markdown 内容
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(bottom: 8, left: 4),
                        child: Row(
                          children: [
                            Text(
                              '内容',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white.withOpacity(0.8)
                                    : Colors.black.withOpacity(0.6),
                              ),
                            ),
                            Spacer(),
                            Text(
                              'Markdown 格式',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white.withOpacity(0.4)
                                    : Colors.black.withOpacity(0.3),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextField(
                        controller: _bodyController,
                        decoration: InputDecoration(
                          hintText: '在这里编辑 Markdown...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.black.withOpacity(0.1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.black.withOpacity(0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: AppColors.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.black.withOpacity(0.02),
                          contentPadding: EdgeInsets.all(15),
                        ),
                        maxLines: 8,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // 标签部分
                  Text(
                    '标签',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),

                  SizedBox(height: 12),

                  if (widget.availableLabels.isEmpty)
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: isDark
                                ? Colors.white.withOpacity(0.5)
                                : Colors.black.withOpacity(0.4),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '暂无可用标签',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white.withOpacity(0.6)
                                  : Colors.black.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.availableLabels.map((label) {
                        final isSelected = _selectedLabels.contains(label);
                        final colors = [
                          Colors.blue,
                          Colors.green,
                          Colors.orange,
                          Colors.purple,
                          Colors.pink,
                          Colors.teal,
                        ];
                        final colorIndex = label.hashCode.abs() % colors.length;
                        final color = colors[colorIndex];

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedLabels.remove(label);
                              } else {
                                _selectedLabels.add(label);
                              }
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.black.withOpacity(0.05)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.black.withOpacity(0.1)),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white : color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white.withOpacity(0.7)
                                            : Colors.black.withOpacity(0.7)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  SizedBox(height: 20),

                  // GitHub 查看按钮
                  Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(widget.htmlUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: Icon(Icons.open_in_new, size: 16),
                      label: Text('在 GitHub 查看'),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? Colors.white.withOpacity(0.6)
                            : Colors.black.withOpacity(0.5),
                        backgroundColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.02),
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.05),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 关闭选项
                  if (isOpen) ...[
                    SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(isDark ? 0.1 : 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.3),
                        ),
                      ),
                      child: CheckboxListTile(
                        title: Row(
                          children: [
                            Icon(Icons.cancel_outlined,
                                size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              '关闭此 Issue',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: EdgeInsets.only(left: 26, top: 4),
                          child: Text('保存后将关闭此 Issue'),
                        ),
                        value: _shouldClose,
                        onChanged: (value) {
                          setState(() {
                            _shouldClose = value ?? false;
                          });
                        },
                        activeColor: Colors.red,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                  ],

                  SizedBox(height: 100), // 底部按钮栏的空间
                ],
              ),
            ),
          ),

          // 底部固定按钮栏
          Container(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
            decoration: BoxDecoration(
              color: isDark
                  ? Color(0xFF101622).withOpacity(0.8)
                  : Colors.white.withOpacity(0.8),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      foregroundColor: isDark ? Colors.white : Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '取消',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        _QuickEditResult(
                          title: _titleController.text,
                          body: _bodyController.text,
                          labels: _selectedLabels.toList(),
                          shouldClose: _shouldClose,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      shadowColor: AppColors.primary.withOpacity(0.3),
                    ),
                    child: Text(
                      '保存',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
