import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../providers/config_provider.dart';
import '../models/app_config.dart';
import '../widgets/oss_config_dialog.dart';
import '../services/version_service.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildSectionTitle(context, '核心配置'),
          _buildGitHubTile(),
          _buildDisplayDomainTile(),
          _buildOssTile(),
          const Divider(indent: 16, endIndent: 16),
          _buildSectionTitle(context, '数据管理'),
          _buildImportTile(),
          _buildExportTile(),
          const Divider(indent: 16, endIndent: 16),
          _buildSectionTitle(context, '关于'),
          _buildAboutTile(),
          _buildCheckUpdateTile(),
          _buildSourceCodeTile(),
        ],
      ),
    );
  }

  /// 构建区域标题
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  /// 构建GitHub配置项
  Widget _buildGitHubTile() {
    final config = ref.watch(configProvider);
    final subtitle = config.github.isValid
        ? '${config.github.owner}/${config.github.repo}'
        : '未配置';

    return ListTile(
      leading: const Icon(Icons.code_rounded),
      title: const Text('GitHub仓库'),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showGitHubConfigDialog(),
    );
  }

  /// 构建全局回显域名配置项
  Widget _buildDisplayDomainTile() {
    final config = ref.watch(configProvider);
    final subtitle = config.displayDomain.isNotEmpty
        ? config.displayDomain
        : '未配置';

    return ListTile(
      leading: const Icon(Icons.image_search_rounded),
      title: const Text('图片回显域名'),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showDisplayDomainDialog(),
    );
  }

  /// 构建OSS配置项
  Widget _buildOssTile() {
    final ossList = ref.watch(configProvider).ossList;
    final enabledCount = ossList.where((oss) => oss.enabled).length;
    return ListTile(
      leading: const Icon(Icons.cloud_upload_rounded),
      title: const Text('对象存储 (OSS)'),
      subtitle: Text('${ossList.length}个配置, $enabledCount个已启用'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showOSSConfigDialog(),
    );
  }

  /// 构建导入配置项
  Widget _buildImportTile() {
    return ListTile(
      leading: const Icon(Icons.file_download_rounded),
      title: const Text('导入配置'),
      subtitle: const Text('从剪贴板或文件导入配置'),
      onTap: _importConfig,
    );
  }

  /// 构建导出配置项
  Widget _buildExportTile() {
    return ListTile(
      leading: const Icon(Icons.file_upload_rounded),
      title: const Text('导出配置'),
      subtitle: const Text('将当前配置导出到剪贴板'),
      onTap: _exportConfig,
    );
  }

  /// 构建关于信息项
  Widget _buildAboutTile() {
    return ListTile(
      leading: const Icon(Icons.info_outline_rounded),
      title: Text('GitHub Issue Editor v$_appVersion'),
      subtitle: const Text('作者: leoon. Gamil: dsleoon@gmail.com'),
    );
  }

  /// 构建检查更新项
  Widget _buildCheckUpdateTile() {
    return ListTile(
      leading: _isCheckingUpdate
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : const Icon(Icons.system_update_rounded),
      title: const Text('检查更新'),
      onTap: _isCheckingUpdate ? null : _checkForUpdate,
    );
  }

  /// 构建源码仓库项
  Widget _buildSourceCodeTile() {
    return ListTile(
      leading: const Icon(Icons.open_in_new_rounded),
      title: const Text('查看源码'),
      subtitle: const Text('leoonliang/github-issue-editor'),
      onTap: () async {
        final uri = Uri.parse('https://github.com/leoonliang/github-issue-editor');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
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
                  decoration: const InputDecoration(labelText: 'Owner'),
                ),
                TextField(
                  controller: repoController,
                  decoration: const InputDecoration(labelText: 'Repository'),
                ),
                TextField(
                  controller: tokenController,
                  decoration: const InputDecoration(labelText: 'Token'),
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
            FilledButton(
              onPressed: () {
                final github = GitHubConfig(
                  owner: ownerController.text.trim(),
                  repo: repoController.text.trim(),
                  token: tokenController.text.trim(),
                );
                ref.read(configProvider.notifier).updateGitHubConfig(github);
                Navigator.pop(context);
                _showSuccessSnackBar('GitHub 配置已保存');
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  /// 显示回显域名配置对话框
  void _showDisplayDomainDialog() {
    final config = ref.read(configProvider);
    final controller = TextEditingController(text: config.displayDomain);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('图片回显域名'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '域名',
              hintText: 'https://img.example.com',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(configProvider.notifier)
                    .updateDisplayDomain(controller.text.trim());
                Navigator.pop(context);
                _showSuccessSnackBar('回显域名已保存');
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
    showDialog(
      context: context,
      builder: (context) {
        // 使用 Consumer 来确保对话框内的列表能够响应状态变化
        return Consumer(builder: (context, ref, child) {
          final ossList = ref.watch(configProvider).ossList;
          return AlertDialog(
            title: Row(
              children: [
                const Text('对象存储 (OSS)'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () async {
                    final result = await showDialog<OSSConfig>(
                      context: context,
                      builder: (context) => const OSSConfigDialog(),
                    );
                    if (result != null) {
                      ref.read(configProvider.notifier).addOSSConfig(result);
                    }
                  },
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ossList.isEmpty
                  ? const Center(child: Text('暂无配置'))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: ossList.length,
                      itemBuilder: (context, index) {
                        final oss = ossList[index];
                        return _buildOSSItem(oss);
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('完成'),
              ),
            ],
          );
        });
      },
    );
  }

  /// 构建单个OSS配置项
  Widget _buildOSSItem(OSSConfig oss) {
    return ListTile(
      title: Text(oss.name),
      subtitle: Text(
        '${oss.bucket} - ${oss.enabled ? "已启用" : "已禁用"}',
        style: TextStyle(color: oss.enabled ? Colors.green : Colors.grey),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: oss.enabled,
            onChanged: (value) {
              ref.read(configProvider.notifier).toggleOSSEnabled(oss.id);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _editOSSConfig(oss);
              } else if (value == 'delete') {
                _deleteOSSConfig(oss);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('编辑')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('删除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// 编辑OSS配置
  Future<void> _editOSSConfig(OSSConfig oss) async {
    final result = await showDialog<OSSConfig>(
      context: context,
      builder: (context) => OSSConfigDialog(config: oss),
    );

    if (result != null) {
      await ref.read(configProvider.notifier).updateOSSConfig(oss.id, result);
      _showSuccessSnackBar('OSS 配置已更新');
    }
  }

  /// 删除OSS配置
  Future<void> _deleteOSSConfig(OSSConfig oss) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "${oss.name}" 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(configProvider.notifier).deleteOSSConfig(oss.id);
      _showSuccessSnackBar('OSS 配置已删除');
    }
  }

  /// 导出配置（复制到剪贴板）
  Future<void> _exportConfig() async {
    try {
      final config = ref.read(configProvider);
      final configJson = jsonEncode(config.toJson());
      await Clipboard.setData(ClipboardData(text: configJson));
      _showSuccessSnackBar('配置已复制到剪贴板');
    } catch (e) {
      _showErrorSnackBar('导出失败: $e');
    }
  }

  /// 导入配置（弹窗输入）
  Future<void> _importConfig() async {
    final configJson = await _showImportDialog();
    if (configJson == null || configJson.isEmpty) return;

    try {
      final json = jsonDecode(configJson) as Map<String, dynamic>;
      final config = AppConfig.fromJson(json);

      final confirmed = await _showImportConfirmationDialog(config);
      if (confirmed == true) {
        await ref.read(configProvider.notifier).saveConfig(config);
        _showSuccessSnackBar('✅ 配置已导入');
      }
    } catch (e) {
      _showErrorSnackBar('❌ 配置格式不正确，请检查 JSON');
    }
  }

  Future<String?> _showImportDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入配置'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          autofocus: true,
          decoration: const InputDecoration(hintText: '粘贴配置JSON'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showImportConfirmationDialog(AppConfig config) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认导入'),
        content: Text(
          '将覆盖当前配置：\n'
          'GitHub: ${config.github.owner}/${config.github.repo}\n'
          'OSS: ${config.ossList.length} 个配置',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定')),
        ],
      ),
    );
  }

  /// 检查更新
  Future<void> _checkForUpdate() async {
    if (_isCheckingUpdate) return;
    setState(() => _isCheckingUpdate = true);

    try {
      final versionService = VersionService();
      final updateInfo = await versionService.checkForUpdate(_appVersion);

      if (!mounted) return;

      if (updateInfo['hasError'] == true) {
        _showErrorSnackBar('检查更新失败: ${updateInfo['errorMessage']}');
      } else if (updateInfo['hasUpdate'] == true) {
        _showUpdateDialog(updateInfo);
      } else {
        _showSuccessSnackBar('当前已是最新版本');
      }
    } catch (e) {
      _showErrorSnackBar('检查更新失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  /// 显示更新对话框
  void _showUpdateDialog(Map<String, dynamic> updateInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发现新版本'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('最新版本: ${updateInfo['latestVersion']}'),
              const SizedBox(height: 16),
              const Text('更新内容:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(updateInfo['releaseNotes']),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('稍后')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final url = updateInfo['downloadUrl'] as String;
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('立即下载'),
          ),
        ],
      ),
    );
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
