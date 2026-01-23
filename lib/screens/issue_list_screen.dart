import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/config_provider.dart';
import '../providers/github_provider.dart';
import '../services/github.dart';
import 'publish_screen.dart';

class IssueListScreen extends ConsumerStatefulWidget {
  const IssueListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<IssueListScreen> createState() => _IssueListScreenState();
}

class _IssueListScreenState extends ConsumerState<IssueListScreen> {
  String _selectedLabel = 'all';
  String _selectedState = 'all'; // all, open, closed
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('文章列表', style: TextStyle(fontWeight: FontWeight.bold)),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        backgroundColor: Colors.grey[50], // 浅灰色背景
        actions: [
          // 状态筛选按钮
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_alt),
            tooltip: '筛选状态',
            onSelected: (value) {
              setState(() {
                _selectedState = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'all',
                child: _buildStateMenuItem(
                  'all',
                  Icons.article_outlined,
                  '全部',
                  Colors.black,
                ),
              ),
              PopupMenuItem(
                value: 'open',
                child: _buildStateMenuItem(
                  'open',
                  Icons.lock_open_outlined,
                  '开放',
                  Colors.green,
                ),
              ),
              PopupMenuItem(
                value: 'closed',
                child: _buildStateMenuItem(
                  'closed',
                  Icons.lock_outline,
                  '已关闭',
                  Colors.red,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新',
            onPressed: () {
              final params =
                  IssuesParams(label: _selectedLabel, state: _selectedState);
              ref.read(issuesProvider(params).notifier).refresh();
              ref.invalidate(labelsProvider);
            },
          ),
        ],
      ),
      body: !config.isConfigured
          ? _buildEmptyState()
          : Column(
              children: [
                // 标签过滤器
                labelsAsync.when(
                  data: (labels) => _buildLabelFilter(['all', ...labels]),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stack) => Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('加载标签失败: $error',
                        style: const TextStyle(color: Colors.red)),
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                // Issues 列表
                Expanded(
                  child: _buildIssueList(),
                ),
              ],
            ),
      // 右下角发布按钮
      floatingActionButton: config.isConfigured
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PublishScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.edit_document),
              label: const Text('发布'),
            )
          : null,
    );
  }

  /// 状态筛选菜单项
  Widget _buildStateMenuItem(
    String value,
    IconData icon,
    String text,
    Color color,
  ) {
    final isSelected = _selectedState == value;
    return Row(
      children: [
        Icon(
          isSelected ? Icons.check_circle_outline : icon,
          size: 20,
          color: color,
        ),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(color: isSelected ? color : null)),
      ],
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
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: 跳转到设置页
            },
            icon: const Icon(Icons.settings_outlined),
            label: const Text('前往设置'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// 标签过滤器
  Widget _buildLabelFilter(List<String> labels) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      color: Colors.grey[50],
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        itemBuilder: (context, index) {
          final label = labels[index];
          final isSelected = _selectedLabel == label;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                label == 'all' ? '全部' : label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedLabel = label;
                });
              },
              selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Issue 列表
  Widget _buildIssueList() {
    final params = IssuesParams(label: _selectedLabel, state: _selectedState);
    final issuesState = ref.watch(issuesProvider(params));

    if (issuesState.error != null && issuesState.issues.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 80, color: Colors.red[200]),
            const SizedBox(height: 24),
            Text(
              '加载失败',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              issuesState.error!,
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

    if (issuesState.issues.isEmpty && !issuesState.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              '暂无文章',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '尝试切换筛选条件或发布新文章',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(issuesProvider(params).notifier).refresh();
      },
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        itemCount: issuesState.issues.length + (issuesState.hasMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 0),
        itemBuilder: (context, index) {
          if (index >= issuesState.issues.length) {
            // 加载更多指示器
            return Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: issuesState.isLoading
                  ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : const SizedBox.shrink(),
            );
          }
          return _buildIssueItem(issuesState.issues[index]);
        },
      ),
    );
  }

  /// 单个 Issue 项
  Widget _buildIssueItem(GitHubIssue issue) {
    final isOpen = issue.state == 'open';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Text(
          issue.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            if (issue.body.isNotEmpty)
              Text(
                issue.body.replaceAll(RegExp(r'#+\s.*'), '').trim(), // 简单移除Markdown标题
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 12),
            // 底部元数据
            Row(
              children: [
                // 状态图标
                Icon(
                  isOpen ? Icons.check_circle_outline : Icons.cancel_outlined,
                  size: 14,
                  color: isOpen ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  isOpen ? '开放' : '已关闭',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOpen ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // 创建日期
                Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  _formatDate(issue.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            // 标签
            if (issue.labels.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: issue.labels.map((label) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getLabelColor(label).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: _getLabelColor(label).withBlue(50).withGreen(50),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ]
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _editIssue(issue);
            } else if (value == 'quick_edit') {
              _quickEditIssue(issue);
            } else if (value == 'close') {
              _closeIssue(issue);
            } else if (value == 'view') {
              _viewIssue(issue);
            }
          },
          itemBuilder: (context) => [
            _buildPopupMenuItem(Icons.open_in_browser_outlined, '查看', 'view'),
            _buildPopupMenuItem(Icons.edit_note_outlined, '快速编辑', 'quick_edit'),
            _buildPopupMenuItem(Icons.edit_outlined, '完整编辑', 'edit'),
            if (isOpen)
              _buildPopupMenuItem(
                Icons.close_rounded,
                '关闭',
                'close',
                color: Colors.red,
              ),
          ],
        ),
        onTap: () {
          _editIssue(issue); // 点击直接进入编辑
        },
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(
    IconData icon,
    String text,
    String value, {
    Color? color,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  /// 根据标签名称生成颜色
  Color _getLabelColor(String label) {
    // 使用标签名称的哈希值生成颜色
    final hash = label.hashCode;
    final colors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];
    return colors[hash.abs() % colors.length];
  }

  /// 格式化日期
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  /// 在浏览器中查看
  void _viewIssue(GitHubIssue issue) {
    // TODO: 使用 url_launcher 打开浏览器
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('即将打开: ${issue.htmlUrl}'),
        action: SnackBarAction(label: '打开', onPressed: () {}),
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

  /// 快速编辑 Issue（仅编辑标题和内容）
  Future<void> _quickEditIssue(GitHubIssue issue) async {
    final titleController = TextEditingController(text: issue.title);
    final contentController = TextEditingController(text: issue.body);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('快速编辑'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: '标题',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(
                    labelText: '内容',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 15,
                  minLines: 5,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final githubService = ref.read(githubServiceProvider);
        if (githubService != null) {
          await githubService.updateGitHubIssue(
            issue.number,
            titleController.text.trim(),
            contentController.text.trim(),
            issue.labels,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('更新成功'),
                backgroundColor: Colors.green,
              ),
            );
            // 刷新列表
            final params =
                IssuesParams(label: _selectedLabel, state: _selectedState);
            ref.read(issuesProvider(params).notifier).refresh();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('更新失败: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }

    titleController.dispose();
    contentController.dispose();
  }

  /// 关闭 Issue
  Future<void> _closeIssue(GitHubIssue issue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认关闭'),
        content: Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: '确定要关闭文章 "'),
              TextSpan(
                text: issue.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '" 吗？此操作不可逆。'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认关闭'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final githubService = ref.read(githubServiceProvider);
        if (githubService != null) {
          await githubService.closeGitHubIssue(issue.number);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('文章已关闭'),
                backgroundColor: Colors.green,
              ),
            );
            // 刷新列表
            final params =
                IssuesParams(label: _selectedLabel, state: _selectedState);
            ref.read(issuesProvider(params).notifier).refresh();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('关闭失败: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
