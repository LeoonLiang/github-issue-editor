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
  final _formKey = GlobalKey<FormState>();

  // GitHub配置
  late TextEditingController _githubOwnerController;
  late TextEditingController _githubRepoController;
  late TextEditingController _githubTokenController;
  String _lastLoadedOwner = '';
  String _lastLoadedRepo = '';
  String _lastLoadedToken = '';

  // 全局图片回显域名
  late TextEditingController _displayDomainController;
  String _lastLoadedDisplayDomain = '';

  // 版本信息
  String _appVersion = '';
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    // 初始化为空控制器
    _githubOwnerController = TextEditingController();
    _githubRepoController = TextEditingController();
    _githubTokenController = TextEditingController();
    _displayDomainController = TextEditingController();

    // 获取应用版本信息
    _loadAppVersion();
  }

  /// 更新控制器内容（仅在配置变化时）
  void _updateControllersIfNeeded(AppConfig config) {
    if (_lastLoadedOwner != config.github.owner) {
      _lastLoadedOwner = config.github.owner;
      _githubOwnerController.text = config.github.owner;
    }
    if (_lastLoadedRepo != config.github.repo) {
      _lastLoadedRepo = config.github.repo;
      _githubRepoController.text = config.github.repo;
    }
    if (_lastLoadedToken != config.github.token) {
      _lastLoadedToken = config.github.token;
      _githubTokenController.text = config.github.token;
    }
    if (_lastLoadedDisplayDomain != config.displayDomain) {
      _lastLoadedDisplayDomain = config.displayDomain;
      _displayDomainController.text = config.displayDomain;
    }
  }

  @override
  void dispose() {
    _githubOwnerController.dispose();
    _githubRepoController.dispose();
    _githubTokenController.dispose();
    _displayDomainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configProvider);

    // 当配置变化时更新控制器
    _updateControllersIfNeeded(config);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildGitHubSection(),
          const SizedBox(height: 24),
          _buildOSSSection(),
          const SizedBox(height: 24),
          _buildActions(),
          const SizedBox(height: 24),
          _buildAboutSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 构建GitHub配置区域
  Widget _buildGitHubSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.code, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  const Text(
                    'GitHub 配置',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _githubOwnerController,
                decoration: const InputDecoration(
                  labelText: 'Owner',
                  hintText: '例如：username',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入GitHub用户名';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _githubRepoController,
                decoration: const InputDecoration(
                  labelText: 'Repository',
                  hintText: '例如：blog',
                  prefixIcon: Icon(Icons.folder),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入仓库名';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _githubTokenController,
                decoration: const InputDecoration(
                  labelText: 'Personal Access Token',
                  hintText: 'ghp_xxxxxxxxxxxx',
                  prefixIcon: Icon(Icons.key),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入GitHub Token';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveGitHubConfig,
                  icon: const Icon(Icons.save),
                  label: const Text('保存 GitHub 配置'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建OSS配置区域
  Widget _buildOSSSection() {
    final ossList = ref.watch(configProvider).ossList;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'OSS 配置',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: _addOSSConfig,
                  tooltip: '添加 OSS',
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 全局图片回显域名配置
            TextFormField(
              controller: _displayDomainController,
              decoration: const InputDecoration(
                labelText: '全局图片回显域名（可选）',
                hintText: 'https://img.example.com',
                prefixIcon: Icon(Icons.image),
                helperText: '用于在应用中显示图片，无论上传到哪个OSS都使用这个域名回显',
                helperMaxLines: 2,
              ),
              onChanged: (value) {
                // 自动保存
                _saveDisplayDomain();
              },
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            if (ossList.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_off,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '暂无 OSS 配置',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _addOSSConfig,
                      icon: const Icon(Icons.add),
                      label: const Text('添加第一个配置'),
                    ),
                  ],
                ),
              )
            else
              ...ossList.map((oss) => _buildOSSItem(oss)),
          ],
        ),
      ),
    );
  }

  /// 构建单个OSS配置项
  Widget _buildOSSItem(OSSConfig oss) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: oss.enabled
              ? Theme.of(context).primaryColor
              : Colors.grey,
          child: const Icon(
            Icons.cloud,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          oss.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: oss.enabled ? null : Colors.grey,
          ),
        ),
        subtitle: Text(
          '${oss.bucket} - ${oss.enabled ? "已启用" : "已禁用"}',
          style: TextStyle(
            fontSize: 12,
            color: oss.enabled ? Colors.green : Colors.grey,
          ),
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
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('删除', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _exportConfig,
            icon: const Icon(Icons.upload),
            label: const Text('导出配置'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _importConfig,
            icon: const Icon(Icons.download),
            label: const Text('导入配置'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  /// 保存GitHub配置
  Future<void> _saveGitHubConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final github = GitHubConfig(
        owner: _githubOwnerController.text.trim(),
        repo: _githubRepoController.text.trim(),
        token: _githubTokenController.text.trim(),
      );

      await ref.read(configProvider.notifier).updateGitHubConfig(github);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GitHub 配置已保存')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  /// 保存全局图片回显域名
  Future<void> _saveDisplayDomain() async {
    try {
      await ref.read(configProvider.notifier).updateDisplayDomain(
        _displayDomainController.text.trim(),
      );
    } catch (e) {
      // 静默失败，因为是自动保存
      print('保存回显域名失败: $e');
    }
  }

  /// 添加OSS配置
  Future<void> _addOSSConfig() async {
    final result = await showDialog<OSSConfig>(
      context: context,
      builder: (context) => const OSSConfigDialog(),
    );

    if (result != null) {
      await ref.read(configProvider.notifier).addOSSConfig(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OSS 配置已添加')),
        );
      }
    }
  }

  /// 编辑OSS配置
  Future<void> _editOSSConfig(OSSConfig oss) async {
    final result = await showDialog<OSSConfig>(
      context: context,
      builder: (context) => OSSConfigDialog(config: oss),
    );

    if (result != null) {
      await ref.read(configProvider.notifier).updateOSSConfig(oss.id, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OSS 配置已更新')),
        );
      }
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OSS 配置已删除')),
        );
      }
    }
  }

  /// 导出配置（复制到剪贴板）
  Future<void> _exportConfig() async {
    try {
      final config = ref.read(configProvider);
      final configJson = jsonEncode(config.toJson());

      // 复制到剪贴板
      await Clipboard.setData(ClipboardData(text: configJson));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配置已复制到剪贴板')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  /// 导入配置（从剪贴板粘贴）
  Future<void> _importConfig() async {
    try {
      // 从剪贴板读取
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData == null || clipboardData.text == null || clipboardData.text!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('剪贴板为空')),
          );
        }
        return;
      }

      final configJson = clipboardData.text!;
      final json = jsonDecode(configJson) as Map<String, dynamic>;
      final config = AppConfig.fromJson(json);

      // 确认导入
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认导入'),
          content: Text(
            '导入配置将覆盖当前配置：\n\n'
            'GitHub: ${config.github.owner}/${config.github.repo}\n'
            'OSS 配置: ${config.ossList.length} 个\n\n'
            '确定要导入吗？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确定'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await ref.read(configProvider.notifier).saveConfig(config);

        // 更新控制器
        _githubOwnerController.text = config.github.owner;
        _githubRepoController.text = config.github.repo;
        _githubTokenController.text = config.github.token;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('配置已导入')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }

  /// 加载应用版本信息
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (e) {
      print('Error loading app version: $e');
    }
  }

  /// 检查更新
  Future<void> _checkForUpdate() async {
    if (_isCheckingUpdate) return;

    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      final versionService = VersionService();
      final updateInfo = await versionService.checkForUpdate(_appVersion);

      setState(() {
        _isCheckingUpdate = false;
      });

      if (!mounted) return;

      if (updateInfo['hasUpdate'] == true) {
        _showUpdateDialog(updateInfo);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前已是最新版本')),
        );
      }
    } catch (e) {
      setState(() {
        _isCheckingUpdate = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查更新失败: $e')),
        );
      }
    }
  }

  /// 显示更新对话框
  void _showUpdateDialog(Map<String, dynamic> updateInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Color(0xFFEC4141)),
            const SizedBox(width: 8),
            const Text('发现新版本'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('当前版本: '),
                  Text(
                    'v$_appVersion',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('最新版本: '),
                  Text(
                    updateInfo['latestVersion'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEC4141),
                    ),
                  ),
                ],
              ),
              if (updateInfo['releaseNotes'] != null &&
                  updateInfo['releaseNotes'].toString().isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  '更新内容:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  updateInfo['releaseNotes'],
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后提醒'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final url = updateInfo['downloadUrl'] as String;
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEC4141),
              foregroundColor: Colors.white,
            ),
            child: const Text('立即下载'),
          ),
        ],
      ),
    );
  }

  /// 构建关于区域
  Widget _buildAboutSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '关于我们',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            // 应用图标
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFEC4141),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.article,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'GitHub Issue Editor',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            if (_appVersion.isNotEmpty)
              Text(
                'v$_appVersion',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              '用朋友圈的方式管理你的博客',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            // 检查更新按钮
            OutlinedButton.icon(
              onPressed: _isCheckingUpdate ? null : _checkForUpdate,
              icon: _isCheckingUpdate
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.system_update, size: 18),
              label: Text(_isCheckingUpdate ? '检查中...' : '检查更新'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEC4141),
                side: const BorderSide(color: Color(0xFFEC4141)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            // 作者信息
            Row(
              children: [
                const Icon(Icons.person_outline, size: 20, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '作者',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'leoonliang',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 邮箱信息
            InkWell(
              onTap: () async {
                final uri = Uri.parse('mailto:dsleoon@gmail.com');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              child: Row(
                children: [
                  const Icon(Icons.email_outlined, size: 20, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '联系方式',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'dsleoon@gmail.com',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFEC4141),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // GitHub仓库
            InkWell(
              onTap: () async {
                final uri = Uri.parse('https://github.com/leoonliang/github-issue-editor');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Row(
                children: [
                  const Icon(Icons.code, size: 20, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'GitHub',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'leoonliang/github-issue-editor',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFEC4141),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '© 2024 leoonliang. All rights reserved.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
