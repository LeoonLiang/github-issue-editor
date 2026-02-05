import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../providers/config_provider.dart';
import '../models/app_config.dart';
import '../services/version_service.dart';
import '../theme/app_colors.dart';

/// 设置页面
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // 版本信息
  String _appVersion = '';
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  /// 加载应用版本信息
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (e) {
      print('Error loading app version: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // GitHub Configuration 分组
          _buildSectionTitle('GitHub Configuration', isDark),
          _buildSettingsCard(
            isDark: isDark,
            children: [
              _buildSettingItem(
                icon: Icons.key,
                iconColor: AppColors.primary,
                title: 'GitHub Token',
                subtitle: 'Manage your personal access token',
                onTap: () => _showGitHubConfigDialog(),
                isDark: isDark,
              ),
              _buildDivider(isDark),
              _buildSettingItem(
                icon: Icons.storage,
                iconColor: AppColors.primary,
                title: 'Repository',
                subtitle: () {
                  final config = ref.watch(configProvider);
                  return config.github.isValid
                      ? '${config.github.owner}/${config.github.repo}'
                      : 'Select issue storage repository';
                }(),
                onTap: () => _showGitHubConfigDialog(),
                isDark: isDark,
              ),
              _buildDivider(isDark),
              _buildSettingItem(
                icon: Icons.image_search,
                iconColor: AppColors.primary,
                title: 'Display Domain',
                subtitle: () {
                  final config = ref.watch(configProvider);
                  return config.displayDomain.isNotEmpty
                      ? config.displayDomain
                      : 'Configure image回显域名';
                }(),
                onTap: () => _showDisplayDomainDialog(),
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Media Storage 分组
          _buildSectionTitle('Media Storage', isDark),
          _buildSettingsCard(
            isDark: isDark,
            children: [
              _buildSettingItem(
                icon: Icons.cloud_upload,
                iconColor: AppColors.primary,
                title: 'S3 Configuration',
                subtitle: () {
                  final ossList = ref.watch(configProvider).ossList;
                  final enabledCount = ossList.where((oss) => oss.enabled).length;
                  return '${ossList.length} configs, $enabledCount enabled';
                }(),
                onTap: () => _showOSSConfigDialog(),
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Maintenance 分组
          _buildSectionTitle('Maintenance', isDark),
          _buildSettingsCard(
            isDark: isDark,
            children: [
              _buildSettingItem(
                icon: Icons.download,
                iconColor: AppColors.primary,
                title: 'Backup & Restore',
                subtitle: 'Export or import your local configuration',
                onTap: () => _showBackupRestoreDialog(),
                isDark: isDark,
              ),
              _buildDivider(isDark),
              _buildSettingItem(
                icon: Icons.update,
                iconColor: AppColors.primary,
                title: 'Check for Updates',
                subtitle: 'Current version: v$_appVersion',
                onTap: _isCheckingUpdate ? null : _checkForUpdate,
                isDark: isDark,
                trailing: _isCheckingUpdate
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // About 分组
          _buildSectionTitle('About', isDark),
          _buildSettingsCard(
            isDark: isDark,
            children: [
              _buildSettingItem(
                icon: Icons.info_outline,
                iconColor: AppColors.primary,
                title: 'GitHub Issue Editor',
                subtitle: 'Version $_appVersion • Made by leoonliang',
                isDark: isDark,
                showArrow: false,
              ),
              _buildDivider(isDark),
              _buildSettingItem(
                icon: Icons.open_in_browser,
                iconColor: AppColors.primary,
                title: 'Source Code',
                subtitle: 'leoonliang/github-issue-editor',
                onTap: () async {
                  final uri = Uri.parse('https://github.com/leoonliang/github-issue-editor');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 构建区域标题
  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      ),
    );
  }

  /// 构建设置卡片容器
  Widget _buildSettingsCard({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  /// 构建单个设置项
  Widget _buildSettingItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    VoidCallback? onTap,
    Widget? trailing,
    bool showArrow = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 左侧图标容器
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),

              const SizedBox(width: 16),

              // 中间文本
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // 右侧
              if (trailing != null)
                trailing
              else if (showArrow)
                Icon(
                  Icons.chevron_right,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建分隔线
  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 80), // 对齐文本开始位置
      child: Divider(
        height: 1,
        thickness: 1,
        color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
      ),
    );
  }

  /// 显示 GitHub 配置对话框
  void _showGitHubConfigDialog() {
    final config = ref.read(configProvider);
    final ownerController = TextEditingController(text: config.github.owner);
    final repoController = TextEditingController(text: config.github.repo);
    final tokenController = TextEditingController(text: config.github.token);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('GitHub 配置'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ownerController,
                  decoration: const InputDecoration(
                    labelText: '仓库所有者',
                    hintText: '例如: leoonliang',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: repoController,
                  decoration: const InputDecoration(
                    labelText: '仓库名称',
                    hintText: '例如: blog',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tokenController,
                  decoration: const InputDecoration(
                    labelText: 'GitHub Token',
                    hintText: 'ghp_xxxxxxxxxxxx',
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final newConfig = ref.read(configProvider).copyWith(
                      github: GitHubConfig(
                        owner: ownerController.text.trim(),
                        repo: repoController.text.trim(),
                        token: tokenController.text.trim(),
                      ),
                    );
                ref.read(configProvider.notifier).saveConfig(newConfig);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('配置已保存'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  /// 显示显示域名配置对话框
  void _showDisplayDomainDialog() {
    final config = ref.read(configProvider);
    final domainController = TextEditingController(text: config.displayDomain);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('图片回显域名'),
          content: TextField(
            controller: domainController,
            decoration: const InputDecoration(
              labelText: '域名',
              hintText: '例如: https://example.com',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final newConfig = ref.read(configProvider).copyWith(
                      displayDomain: domainController.text.trim(),
                    );
                ref.read(configProvider.notifier).saveConfig(newConfig);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('配置已保存'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  /// 显示 OSS 配置对话框
  void _showOSSConfigDialog() {
    // 跳转到 OSS 配置页面（简化版：直接显示一个提示）
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('OSS 配置'),
        content: const Text('OSS 配置功能待实现'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 显示备份恢复对话框
  void _showBackupRestoreDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('备份与恢复'),
          content: const Text('选择操作'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _importConfig();
              },
              child: const Text('导入配置'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _exportConfig();
              },
              child: const Text('导出配置'),
            ),
          ],
        );
      },
    );
  }

  /// 导入配置
  Future<void> _importConfig() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('导入配置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('粘贴配置 JSON：'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: '{"github": {...}, ...}',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('导入'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      try {
        final json = jsonDecode(result);
        final newConfig = AppConfig.fromJson(json);
        ref.read(configProvider.notifier).saveConfig(newConfig);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('配置导入成功'),
            backgroundColor: AppColors.success,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('配置导入失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// 导出配置
  Future<void> _exportConfig() async {
    final config = ref.read(configProvider);
    final json = jsonEncode(config.toJson());

    await Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('配置已复制到剪贴板'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  /// 检查更新
  Future<void> _checkForUpdate() async {
    setState(() => _isCheckingUpdate = true);

    try {
      final versionService = VersionService();
      final result = await versionService.checkForUpdate(_appVersion);

      if (!mounted) return;

      if (result['hasUpdate'] == true) {
        final newVersion = result['latestVersion'];
        final downloadUrl = result['downloadUrl'];
        final releaseNotes = result['releaseNotes'] ?? '';

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('发现新版本 $newVersion'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('当前版本: $_appVersion'),
                  const SizedBox(height: 16),
                  if (releaseNotes.isNotEmpty) ...[
                    const Text('更新内容:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(releaseNotes),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final uri = Uri.parse(downloadUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('下载更新'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('当前已是最新版本'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('检查更新失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }
}
