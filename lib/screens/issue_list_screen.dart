import 'package:flutter/material.dart';
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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
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
        title: const Text('文章列表'),
        actions: [
          // 状态筛选按钮
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: '筛选状态',
            onSelected: (value) {
              setState(() {
                _selectedState = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(
                      _selectedState == 'all' ? Icons.check : Icons.article,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('全部'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'open',
                child: Row(
                  children: [
                    Icon(
                      _selectedState == 'open' ? Icons.check : Icons.lock_open,
                      size: 18,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    const Text('开放', style: TextStyle(color: Colors.green)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'closed',
                child: Row(
                  children: [
                    Icon(
                      _selectedState == 'closed' ? Icons.check : Icons.lock,
                      size: 18,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    const Text('已关闭', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final params = IssuesParams(label: _selectedLabel, state: _selectedState);
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
                    padding: const EdgeInsets.all(8.0),
                    child: Text('加载标签失败: $error', style: const TextStyle(color: Colors.red)),
                  ),
                ),
                const Divider(height: 1),
                // Issues 列表
                Expanded(
                  child: _buildIssueList(),
                ),
              ],
            ),
      // 右下角发布按钮
      floatingActionButton: config.isConfigured
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PublishScreen(),
                  ),
                );
              },
              child: const Icon(Icons.edit),
            )
          : null,
    );
  }

  /// 空状态提示
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.settings_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '请先配置 GitHub 和 OSS',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              // 跳转到设置页（索引改为1）
              DefaultTabController.of(context)?.animateTo(1);
            },
            icon: const Icon(Icons.settings),
            label: const Text('前往设置'),
          ),
        ],
      ),
    );
  }

  /// 标签过滤器
  Widget _buildLabelFilter(List<String> labels) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        itemBuilder: (context, index) {
          final label = labels[index];
          final isSelected = _selectedLabel == label;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label == 'all' ? '全部' : label),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedLabel = label;
                });
              },
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
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              issuesState.error!,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(issuesProvider(params).notifier).refresh();
              },
              icon: const Icon(Icons.refresh),
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
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '暂无文章',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
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
        itemCount: issuesState.issues.length + (issuesState.hasMore ? 1 : 0),
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= issuesState.issues.length) {
            // 加载更多指示器
            return Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: issuesState.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
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

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 显示部分正文内容
          if (issue.body.isNotEmpty)
            Text(
              issue.body,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.normal,
                color: Colors.black87,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 8),
          // 标题（小字）
          Text(
            issue.title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // 标签和创建时间
          Row(
            children: [
              // 标签
              if (issue.labels.isNotEmpty)
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: issue.labels.map((label) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _getLabelColor(label),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(width: 8),
              // 状态图标和时间
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOpen ? Icons.lock_open : Icons.lock,
                    size: 12,
                    color: isOpen ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(issue.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'edit') {
            _editIssue(issue);
          } else if (value == 'close') {
            _closeIssue(issue);
          } else if (value == 'view') {
            _viewIssue(issue);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'view',
            child: Row(
              children: [
                Icon(Icons.open_in_browser, size: 18),
                SizedBox(width: 8),
                Text('查看'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, size: 18),
                SizedBox(width: 8),
                Text('编辑'),
              ],
            ),
          ),
          // 只有开放状态才显示关闭选项
          if (isOpen)
            const PopupMenuItem(
              value: 'close',
              child: Row(
                children: [
                  Icon(Icons.close, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('关闭', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
        ],
      ),
      onTap: () {
        _viewIssueDetails(issue);
      },
    );
  }

  /// 根据标签名称生成颜色
  Color _getLabelColor(String label) {
    // 使用标签名称的哈希值生成颜色
    final hash = label.hashCode;
    final colors = [
      const Color(0xFFEC4141), // 红色
      const Color(0xFF4CAF50), // 绿色
      const Color(0xFF2196F3), // 蓝色
      const Color(0xFFFF9800), // 橙色
      const Color(0xFF9C27B0), // 紫色
      const Color(0xFF00BCD4), // 青色
      const Color(0xFFFFEB3B), // 黄色
      const Color(0xFF795548), // 棕色
      const Color(0xFF607D8B), // 蓝灰色
      const Color(0xFFE91E63), // 粉色
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

  /// 查看 Issue 详情
  void _viewIssueDetails(GitHubIssue issue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(issue.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (issue.labels.isNotEmpty) ...[
                Wrap(
                  spacing: 4,
                  children: issue.labels.map((label) {
                    return Chip(label: Text(label));
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              Text(issue.body),
              const SizedBox(height: 12),
              Text(
                '创建于: ${_formatDate(issue.createdAt)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 在浏览器中查看
  void _viewIssue(GitHubIssue issue) {
    // TODO: 使用 url_launcher 打开浏览器
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('打开 ${issue.htmlUrl}')),
    );
  }

  /// 编辑 Issue
  Future<void> _editIssue(GitHubIssue issue) async {
    final titleController = TextEditingController(text: issue.title);
    final bodyController = TextEditingController(text: issue.body);
    final availableLabels = await ref.read(labelsProvider.future);
    final selectedLabels = List<String>.from(issue.labels);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('编辑文章'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: '标题',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: bodyController,
                  decoration: const InputDecoration(
                    labelText: '内容',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 10,
                ),
                const SizedBox(height: 16),
                const Text('标签:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: availableLabels.map((label) {
                    final isSelected = selectedLabels.contains(label);
                    return FilterChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedLabels.add(label);
                          } else {
                            selectedLabels.remove(label);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
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
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        final githubService = ref.read(githubServiceProvider);
        if (githubService != null) {
          await githubService.updateGitHubIssue(
            issue.number,
            titleController.text,
            bodyController.text,
            selectedLabels,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('文章已更新')),
            );
            // 刷新列表
            final params = IssuesParams(label: _selectedLabel, state: _selectedState);
            ref.read(issuesProvider(params).notifier).refresh();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('更新失败: $e')),
          );
        }
      }
    }

    titleController.dispose();
    bodyController.dispose();
  }

  /// 关闭 Issue
  Future<void> _closeIssue(GitHubIssue issue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认关闭'),
        content: Text('确定要关闭 "${issue.title}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('关闭'),
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
              const SnackBar(content: Text('Issue 已关闭')),
            );
            // 刷新列表
            final params = IssuesParams(label: _selectedLabel, state: _selectedState);
            ref.read(issuesProvider(params).notifier).refresh();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('关闭失败: $e')),
          );
        }
      }
    }
  }
}
