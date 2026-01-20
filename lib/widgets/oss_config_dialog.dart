import 'package:flutter/material.dart';
import '../models/app_config.dart';

/// OSS配置编辑对话框（S3兼容）
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
    return AlertDialog(
      title: Text(widget.config == null ? '添加 OSS 配置' : '编辑 OSS 配置'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '配置名称*',
                  hintText: '例如：七牛云、Bitiful、AWS S3',
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入配置名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _endpointController,
                decoration: const InputDecoration(
                  labelText: 'Endpoint*',
                  hintText: 's3.amazonaws.com',
                  prefixIcon: Icon(Icons.dns),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入 Endpoint';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _regionController,
                decoration: const InputDecoration(
                  labelText: 'Region*',
                  hintText: 'us-east-1',
                  prefixIcon: Icon(Icons.public),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入 Region';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _accessKeyIdController,
                decoration: const InputDecoration(
                  labelText: 'Access Key ID*',
                  prefixIcon: Icon(Icons.vpn_key),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入 Access Key ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _secretAccessKeyController,
                decoration: const InputDecoration(
                  labelText: 'Secret Access Key*',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入 Secret Access Key';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bucketController,
                decoration: const InputDecoration(
                  labelText: 'Bucket*',
                  hintText: 'my-bucket',
                  prefixIcon: Icon(Icons.storage),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入 Bucket 名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _publicDomainController,
                decoration: const InputDecoration(
                  labelText: '公网访问域名（可选）',
                  hintText: 'https://cdn.example.com',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('启用此配置'),
                subtitle: const Text('上传时会使用此OSS'),
                value: _enabled,
                onChanged: (value) {
                  setState(() {
                    _enabled = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
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
