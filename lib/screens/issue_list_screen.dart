import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../providers/config_provider.dart';
import '../providers/github_provider.dart';
import '../services/github.dart';
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
    final labelsAsync = ref.watch(labelsProvider);
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
                labelsAsync.when(
                  data: (labels) => _buildLabelFilter(['all', ...labels], isDark),
                  loading: () => Container(
                    height: 50,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (error, stack) => SizedBox.shrink(),
                ),

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
            'Blog Feed',
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
                  label: 'All Posts',
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
                  label: 'Open',
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
            onTap: () => _editIssue(filteredIssues[index]),
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
}
