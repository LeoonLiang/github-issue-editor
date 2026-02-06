import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../providers/config_provider.dart';
import '../providers/theme_provider.dart';
import '../models/app_config.dart';
import '../services/version_service.dart';
import '../theme/app_colors.dart';
import '../widgets/oss_config_dialog.dart';

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
        title: const Text('设置', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // GitHub 配置 分组
          _buildSectionTitle('GitHub 配置', isDark),
          _buildSettingsCard(
            isDark: isDark,
            children: [
              _buildSettingItem(
                icon: Icons.key,
                iconColor: AppColors.primary,
                title: 'GitHub 令牌',
                subtitle: '管理您的个人访问令牌',
                onTap: () => _showGitHubConfigDialog(),
                isDark: isDark,
              ),
              _buildDivider(isDark),
              _buildSettingItem(
                icon: Icons.storage,
                iconColor: AppColors.primary,
                title: '仓库',
                subtitle: () {
                  final config = ref.watch(configProvider);
                  return config.github.isValid
                      ? '${config.github.owner}/${config.github.repo}'
                      : '选择 Issue 存储仓库';
                }(),
                onTap: () => _showGitHubConfigDialog(),
                isDark: isDark,
              ),
              _buildDivider(isDark),
              _buildSettingItem(
                icon: Icons.image_search,
                iconColor: AppColors.primary,
                title: '图片回显域名',
                subtitle: () {
                  final config = ref.watch(configProvider);
                  return config.displayDomain.isNotEmpty
                      ? config.displayDomain
                      : '配置图片回显域名';
                }(),
                onTap: () => _showDisplayDomainDialog(),
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 媒体存储 分组
          _buildSectionTitle('媒体存储', isDark),
          _buildSettingsCard(
            isDark: isDark,
            children: [
              _buildSettingItem(
                icon: Icons.cloud_upload,
                iconColor: AppColors.primary,
                title: '对象存储配置',
                subtitle: () {
                  final ossList = ref.watch(configProvider).ossList;
                  final enabledCount = ossList.where((oss) => oss.enabled).length;
                  return '${ossList.length}个配置, $enabledCount个已启用';
                }(),
                onTap: () => _showOSSConfigDialog(),
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 外观 分组
          _buildSectionTitle('外观', isDark),
          _buildSettingsCard(
            isDark: isDark,
            children: [
              _buildSettingItem(
                icon: Icons.palette,
                iconColor: AppColors.primary,
                title: '主题',
                subtitle: () {
                  final themeMode = ref.watch(themeModeProvider).themeMode;
                  switch (themeMode) {
                    case ThemeMode.light:
                      return '浅色';
                    case ThemeMode.dark:
                      return '深色';
                    case ThemeMode.system:
                    default:
                      return '跟随系统';
                  }
                }(),
                onTap: () => _showThemeDialog(),
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 维护 分组
          _buildSectionTitle('维护', isDark),
          _buildSettingsCard(
            isDark: isDark,
            children: [
              _buildSettingItem(
                icon: Icons.download,
                iconColor: AppColors.primary,
                title: '备份与恢复',
                subtitle: '导出或导入本地配置',
                onTap: () => _showBackupRestoreDialog(),
                isDark: isDark,
              ),
              _buildDivider(isDark),
              _buildSettingItem(
                icon: Icons.update,
                iconColor: AppColors.primary,
                title: '检查更新',
                subtitle: '当前版本: v$_appVersion',
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

          // 关于 分组
          _buildSectionTitle('关于', isDark),
          _buildSettingsCard(
            isDark: isDark,
            children: [
              _buildSettingItem(
                icon: Icons.info_outline,
                iconColor: AppColors.primary,
                title: 'GitHub Issue Editor',
                subtitle: '版本 $_appVersion • 作者 leoonliang',
                isDark: isDark,
                showArrow: false,
              ),
              _buildDivider(isDark),
              _buildSettingItem(
                icon: Icons.open_in_browser,
                iconColor: AppColors.primary,
                title: '源代码',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GitHubConfigBottomSheet(
        initialOwner: config.github.owner,
        initialRepo: config.github.repo,
        initialToken: config.github.token,
        isDark: isDark,
        onSave: (owner, repo, token) {
          final newConfig = config.copyWith(
            github: GitHubConfig(
              owner: owner,
              repo: repo,
              token: token,
            ),
          );
          ref.read(configProvider.notifier).saveConfig(newConfig);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('配置已保存'),
              backgroundColor: AppColors.success,
            ),
          );
        },
      ),
    );
  }

  /// 显示显示域名配置对话框
  void _showDisplayDomainDialog() {
    final config = ref.read(configProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DisplayDomainBottomSheet(
        initialDomain: config.displayDomain,
        isDark: isDark,
        onSave: (domain) {
          final newConfig = config.copyWith(displayDomain: domain);
          ref.read(configProvider.notifier).saveConfig(newConfig);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('配置已保存'),
              backgroundColor: AppColors.success,
            ),
          );
        },
      ),
    );
  }

  /// 显示 OSS 配置对话框
  void _showOSSConfigDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // 使用 Consumer 来确保对话框内的列表能够响应状态变化
        return Consumer(builder: (context, ref, child) {
          final ossList = ref.watch(configProvider).ossList;
          final screenHeight = MediaQuery.of(context).size.height;

          return Container(
            height: screenHeight * 0.75,
            decoration: BoxDecoration(
              color: isDark ? Color(0xFF101622).withOpacity(0.95) : Colors.white.withOpacity(0.95),
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

                // 大标题 + 添加按钮
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 16, 16),
                  child: Row(
                    children: [
                      Text(
                        '对象存储 (OSS)',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Spacer(),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          onPressed: () async {
                            final result = await showModalBottomSheet<OSSConfig>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => const OSSConfigDialog(),
                            );
                            if (result != null) {
                              ref.read(configProvider.notifier).addOSSConfig(result);
                            }
                          },
                          icon: Icon(Icons.add, size: 24),
                          padding: EdgeInsets.zero,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                // OSS 列表
                Expanded(
                  child: ossList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_off,
                                size: 64,
                                color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
                              ),
                              SizedBox(height: 16),
                              Text(
                                '暂无配置',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          itemCount: ossList.length,
                          itemBuilder: (context, index) {
                            final oss = ossList[index];
                            return _buildOSSItem(oss);
                          },
                        ),
                ),

                // 底部按钮
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        '完成',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  /// 构建单个OSS配置项
  Widget _buildOSSItem(OSSConfig oss) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // 左侧内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    oss.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    oss.bucket,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6),
                    ),
                  ),
                  SizedBox(height: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: oss.enabled
                          ? AppColors.success.withOpacity(0.15)
                          : Colors.grey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      oss.enabled ? '已启用' : '已禁用',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: oss.enabled ? AppColors.success : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(width: 12),

            // 右侧操作按钮
            Column(
              children: [
                // 开关
                Switch(
                  value: oss.enabled,
                  activeColor: AppColors.primary,
                  onChanged: (value) {
                    ref.read(configProvider.notifier).toggleOSSEnabled(oss.id);
                  },
                ),
                SizedBox(height: 8),
                // 更多操作
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editOSSConfig(oss);
                    } else if (value == 'delete') {
                      _deleteOSSConfig(oss);
                    }
                  },
                  icon: Icon(
                    Icons.more_horiz,
                    color: isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 12),
                          Text('编辑'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 12),
                          Text('删除', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 编辑OSS配置
  Future<void> _editOSSConfig(OSSConfig oss) async {
    final result = await showModalBottomSheet<OSSConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OSSConfigDialog(config: oss),
    );

    if (result != null) {
      await ref.read(configProvider.notifier).updateOSSConfig(oss.id, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('OSS 配置已更新'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  /// 删除OSS配置
  void _deleteOSSConfig(OSSConfig oss) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: isDark ? Color(0xFF101622).withOpacity(0.95) : Colors.white.withOpacity(0.95),
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

            // 标题
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                '删除确认',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),

            // 内容
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Text(
                '确定要删除 "${oss.name}" 吗？',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // 按钮
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        ref.read(configProvider.notifier).deleteOSSConfig(oss.id);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('已删除'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        '删除',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示备份恢复对话框
  void _showBackupRestoreDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: isDark ? Color(0xFF101622).withOpacity(0.95) : Colors.white.withOpacity(0.95),
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

            // 大标题 + 关闭按钮
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 16, 16),
              child: Row(
                children: [
                  Text(
                    '备份与恢复',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : Colors.black,
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
                      padding: EdgeInsets.zero,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            // 操作选项
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildActionOption(
                    isDark: isDark,
                    title: '复制模板',
                    subtitle: '复制配置模板到剪贴板',
                    icon: Icons.content_copy,
                    onTap: () {
                      Navigator.pop(context);
                      _copyTemplate();
                    },
                  ),
                  SizedBox(height: 12),
                  _buildActionOption(
                    isDark: isDark,
                    title: '导入配置',
                    subtitle: '从剪贴板导入配置（会覆盖当前配置）',
                    icon: Icons.download,
                    onTap: () {
                      Navigator.pop(context);
                      _importConfig();
                    },
                  ),
                  SizedBox(height: 12),
                  _buildActionOption(
                    isDark: isDark,
                    title: '导出配置',
                    subtitle: '导出配置到剪贴板',
                    icon: Icons.upload,
                    iconColor: AppColors.primary,
                    onTap: () {
                      Navigator.pop(context);
                      _exportConfig();
                    },
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// 构建操作选项
  Widget _buildActionOption({
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (iconColor ?? (isDark ? Colors.white : Colors.black)).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor ?? (isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7)),
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  /// 导入配置
  Future<void> _importConfig() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ImportConfigBottomSheet(isDark: isDark),
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

  /// 复制配置模板
  Future<void> _copyTemplate() async {
    const template = '''
{
    "github": {
        "owner": "your-github-username",
        "repo": "your-repo-name",
        "token": "ghp_your_github_personal_access_token_here"
    },
    "ossList": [
        {
            "name": "bitiful",
            "endpoint": "https://s3.bitiful.net",
            "region": "cn-east-1",
            "accessKeyId": "your_bitiful_access_key_id",
            "secretAccessKey": "your_bitiful_secret_access_key",
            "bucket": "your-bucket-name",
            "publicDomain": "",
            "enabled": true
        },
        {
            "name": "qiniu",
            "endpoint": "https://s3.cn-south-1.qiniucs.com",
            "region": "cn-south-1",
            "accessKeyId": "your_qiniu_access_key_id",
            "secretAccessKey": "your_qiniu_secret_access_key",
            "bucket": "your-bucket-name",
            "publicDomain": "",
            "enabled": true
        }
    ],
    "displayDomain": "https://your-domain.com"
}''';

    await Clipboard.setData(ClipboardData(text: template));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('配置模板已复制到剪贴板'),
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
        final isDark = Theme.of(context).brightness == Brightness.dark;

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: isDark ? Color(0xFF101622).withOpacity(0.95) : Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 25,
                  offset: Offset(0, -10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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

                  // 大标题 + 关闭按钮
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 16, 16),
                    child: Row(
                      children: [
                        Text(
                          '发现新版本 $newVersion',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : Colors.black,
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
                            padding: EdgeInsets.zero,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 内容
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '当前版本: $_appVersion',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7),
                          ),
                        ),
                        if (releaseNotes.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text(
                            '更新内容:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              releaseNotes,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // 底部按钮
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.black.withOpacity(0.05),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              '取消',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              final uri = Uri.parse(downloadUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              '下载更新',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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

  /// 显示主题选择对话框
  void _showThemeDialog() {
    final currentThemeMode = ref.read(themeModeProvider).themeMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: isDark ? Color(0xFF101622).withOpacity(0.95) : Colors.white.withOpacity(0.95),
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

            // 大标题 + 关闭按钮
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 16, 16),
              child: Row(
                children: [
                  Text(
                    '选择主题',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : Colors.black,
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
                      padding: EdgeInsets.zero,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            // 主题选项
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildThemeOption(
                    isDark: isDark,
                    title: '浅色',
                    icon: Icons.light_mode,
                    value: ThemeMode.light,
                    currentValue: currentThemeMode,
                    onTap: () {
                      ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
                      Navigator.pop(context);
                    },
                  ),
                  SizedBox(height: 12),
                  _buildThemeOption(
                    isDark: isDark,
                    title: '深色',
                    icon: Icons.dark_mode,
                    value: ThemeMode.dark,
                    currentValue: currentThemeMode,
                    onTap: () {
                      ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
                      Navigator.pop(context);
                    },
                  ),
                  SizedBox(height: 12),
                  _buildThemeOption(
                    isDark: isDark,
                    title: '跟随系统',
                    icon: Icons.brightness_auto,
                    value: ThemeMode.system,
                    currentValue: currentThemeMode,
                    onTap: () {
                      ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// 构建主题选项
  Widget _buildThemeOption({
    required bool isDark,
    required String title,
    required IconData icon,
    required ThemeMode value,
    required ThemeMode currentValue,
    required VoidCallback onTap,
  }) {
    final isSelected = value == currentValue;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.15)
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7)),
              size: 24,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? Colors.white : Colors.black),
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

/// GitHub 配置底部抽屉
class _GitHubConfigBottomSheet extends StatefulWidget {
  final String initialOwner;
  final String initialRepo;
  final String initialToken;
  final bool isDark;
  final Function(String, String, String) onSave;

  const _GitHubConfigBottomSheet({
    required this.initialOwner,
    required this.initialRepo,
    required this.initialToken,
    required this.isDark,
    required this.onSave,
  });

  @override
  State<_GitHubConfigBottomSheet> createState() => _GitHubConfigBottomSheetState();
}

class _GitHubConfigBottomSheetState extends State<_GitHubConfigBottomSheet> {
  late TextEditingController _ownerController;
  late TextEditingController _repoController;
  late TextEditingController _tokenController;

  @override
  void initState() {
    super.initState();
    _ownerController = TextEditingController(text: widget.initialOwner);
    _repoController = TextEditingController(text: widget.initialRepo);
    _tokenController = TextEditingController(text: widget.initialToken);
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _repoController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: widget.isDark ? Color(0xFF101622).withOpacity(0.95) : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 25,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: SingleChildScrollView(
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

            // 大标题 + 关闭按钮
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 16, 24),
              child: Row(
                children: [
                  Text(
                    'GitHub 配置',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: widget.isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Spacer(),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, size: 18),
                      padding: EdgeInsets.zero,
                      color: widget.isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            // 输入框
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // 仓库所有者
                  TextField(
                    controller: _ownerController,
                    style: TextStyle(
                      fontSize: 16,
                      color: widget.isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      labelText: '仓库所有者',
                      hintText: '例如: leoonliang',
                      hintStyle: TextStyle(
                        color: widget.isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
                      ),
                      filled: true,
                      fillColor: widget.isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: widget.isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),

                  SizedBox(height: 16),

                  // 仓库名称
                  TextField(
                    controller: _repoController,
                    style: TextStyle(
                      fontSize: 16,
                      color: widget.isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      labelText: '仓库名称',
                      hintText: '例如: blog',
                      hintStyle: TextStyle(
                        color: widget.isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
                      ),
                      filled: true,
                      fillColor: widget.isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: widget.isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),

                  SizedBox(height: 16),

                  // GitHub Token
                  TextField(
                    controller: _tokenController,
                    obscureText: true,
                    style: TextStyle(
                      fontSize: 16,
                      color: widget.isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      labelText: 'GitHub Token',
                      hintText: 'ghp_xxxxxxxxxxxx',
                      hintStyle: TextStyle(
                        color: widget.isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
                      ),
                      filled: true,
                      fillColor: widget.isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: widget.isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // 底部按钮
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: widget.isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onSave(
                          _ownerController.text.trim(),
                          _repoController.text.trim(),
                          _tokenController.text.trim(),
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        '保存',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 导入配置底部抽屉
class _ImportConfigBottomSheet extends StatefulWidget {
  final bool isDark;

  const _ImportConfigBottomSheet({required this.isDark});

  @override
  State<_ImportConfigBottomSheet> createState() => _ImportConfigBottomSheetState();
}

class _ImportConfigBottomSheetState extends State<_ImportConfigBottomSheet> {
  late TextEditingController _configController;

  @override
  void initState() {
    super.initState();
    _configController = TextEditingController();
  }

  @override
  void dispose() {
    _configController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: widget.isDark ? Color(0xFF101622).withOpacity(0.95) : Colors.white.withOpacity(0.95),
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

          // 大标题 + 关闭按钮
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 16, 16),
            child: Row(
              children: [
                Text(
                  '导入配置',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: widget.isDark ? Colors.white : Colors.black,
                  ),
                ),
                Spacer(),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, size: 18),
                    padding: EdgeInsets.zero,
                    color: widget.isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),

          // 提示文本
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '粘贴配置 JSON：',
                style: TextStyle(
                  fontSize: 14,
                  color: widget.isDark ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6),
                ),
              ),
            ),
          ),

          SizedBox(height: 12),

          // 输入框
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _configController,
              maxLines: 8,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                color: widget.isDark ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: '{"github": {...}, ...}',
                hintStyle: TextStyle(
                  color: widget.isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
                ),
                filled: true,
                fillColor: widget.isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: widget.isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),

          SizedBox(height: 24),

          // 底部按钮
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: widget.isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '取消',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _configController.text),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '导入',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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

/// 显示域名底部抽屉
class _DisplayDomainBottomSheet extends StatefulWidget {
  final String initialDomain;
  final bool isDark;
  final Function(String) onSave;

  const _DisplayDomainBottomSheet({
    required this.initialDomain,
    required this.isDark,
    required this.onSave,
  });

  @override
  State<_DisplayDomainBottomSheet> createState() => _DisplayDomainBottomSheetState();
}

class _DisplayDomainBottomSheetState extends State<_DisplayDomainBottomSheet> {
  late TextEditingController _domainController;

  @override
  void initState() {
    super.initState();
    _domainController = TextEditingController(text: widget.initialDomain);
  }

  @override
  void dispose() {
    _domainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: widget.isDark ? Color(0xFF101622).withOpacity(0.95) : Colors.white.withOpacity(0.95),
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

          // 大标题 + 关闭按钮
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 16, 24),
            child: Row(
              children: [
                Text(
                  '图片回显域名',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: widget.isDark ? Colors.white : Colors.black,
                  ),
                ),
                Spacer(),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, size: 18),
                    padding: EdgeInsets.zero,
                    color: widget.isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),

          // 输入框
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _domainController,
              style: TextStyle(
                fontSize: 16,
                color: widget.isDark ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                labelText: '域名',
                hintText: '例如: https://example.com',
                hintStyle: TextStyle(
                  color: widget.isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
                ),
                filled: true,
                fillColor: widget.isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: widget.isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),

          SizedBox(height: 24),

          // 底部按钮
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: widget.isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '取消',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onSave(_domainController.text.trim());
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '保存',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
