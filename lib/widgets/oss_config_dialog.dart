import 'package:flutter/material.dart';
import '../models/app_config.dart';
import '../theme/app_colors.dart';

/// OSS配置编辑对话框（S3兼容）- 底部抽屉风格
class OSSConfigDialog extends StatefulWidget {
  final OSSConfig? config; // null表示新建

  const OSSConfigDialog({Key? key, this.config}) : super(key: key);

  @override
  State<OSSConfigDialog> createState() => _OSSConfigDialogState();
}

class _OSSConfigDialogState extends State<OSSConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _endpointController;
  late TextEditingController _regionController;
  late TextEditingController _accessKeyIdController;
  late TextEditingController _secretAccessKeyController;
  late TextEditingController _bucketController;
  late TextEditingController _publicDomainController;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final config = widget.config;

    _nameController = TextEditingController(text: config?.name ?? '');
    _endpointController = TextEditingController(text: config?.endpoint ?? '');
    _regionController = TextEditingController(text: config?.region ?? '');
    _accessKeyIdController = TextEditingController(text: config?.accessKeyId ?? '');
    _secretAccessKeyController = TextEditingController(text: config?.secretAccessKey ?? '');
    _bucketController = TextEditingController(text: config?.bucket ?? '');
    _publicDomainController = TextEditingController(text: config?.publicDomain ?? '');
    _enabled = config?.enabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _endpointController.dispose();
    _regionController.dispose();
    _accessKeyIdController.dispose();
    _secretAccessKeyController.dispose();
    _bucketController.dispose();
    _publicDomainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.92,
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

          // 大标题 + 关闭按钮
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 16, 16),
            child: Row(
              children: [
                Text(
                  widget.config == null ? '添加 OSS 配置' : '编辑 OSS 配置',
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

          // 表单内容
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      labelText: '配置名称*',
                      hintText: '例如：七牛云、Bitiful、AWS S3',
                      icon: Icons.label,
                      isDark: isDark,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入配置名称';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      controller: _endpointController,
                      labelText: 'Endpoint*',
                      hintText: 's3.amazonaws.com',
                      icon: Icons.dns,
                      isDark: isDark,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入 Endpoint';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      controller: _regionController,
                      labelText: 'Region*',
                      hintText: 'us-east-1',
                      icon: Icons.public,
                      isDark: isDark,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入 Region';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      controller: _accessKeyIdController,
                      labelText: 'Access Key ID*',
                      hintText: '',
                      icon: Icons.vpn_key,
                      isDark: isDark,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入 Access Key ID';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      controller: _secretAccessKeyController,
                      labelText: 'Secret Access Key*',
                      hintText: '',
                      icon: Icons.lock,
                      isDark: isDark,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入 Secret Access Key';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      controller: _bucketController,
                      labelText: 'Bucket*',
                      hintText: 'my-bucket',
                      icon: Icons.storage,
                      isDark: isDark,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入 Bucket 名称';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      controller: _publicDomainController,
                      labelText: '公网访问域名（可选）',
                      hintText: 'https://cdn.example.com',
                      icon: Icons.link,
                      isDark: isDark,
                    ),
                    SizedBox(height: 20),
                    // 启用开关
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
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '启用此配置',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '上传时会使用此OSS',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white.withOpacity(0.6)
                                        : Colors.black.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _enabled,
                            activeColor: AppColors.primary,
                            onChanged: (value) {
                              setState(() {
                                _enabled = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          // 底部按钮
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
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
                    onPressed: _save,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    required bool isDark,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(
        fontSize: 16,
        color: isDark ? Colors.white : Colors.black,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(
          icon,
          color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5),
        ),
        hintStyle: TextStyle(
          color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.error,
            width: 2,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final config = OSSConfig(
      id: widget.config?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      endpoint: _endpointController.text.trim(),
      region: _regionController.text.trim(),
      accessKeyId: _accessKeyIdController.text.trim(),
      secretAccessKey: _secretAccessKeyController.text.trim(),
      bucket: _bucketController.text.trim(),
      publicDomain: _publicDomainController.text.trim(),
      enabled: _enabled,
    );

    Navigator.pop(context, config);
  }
}
