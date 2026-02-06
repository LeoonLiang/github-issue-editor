import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/app_config.dart';

/// GitHub 图床服务
class GitHubImageService {
  /// 上传文件到 GitHub 仓库
  /// 返回文件的 download_url
  Future<String> uploadToGitHub(
    String filePath,
    String fileName,
    GitHubImageConfig config,
  ) async {
    print('---------- GitHub 图床上传开始 ----------');
    print('仓库: ${config.owner}/${config.repo}');
    print('分支: ${config.branch}');
    print('文件路径: $fileName');

    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('文件不存在: $filePath');
    }

    // 读取文件并 Base64 编码
    final fileBytes = file.readAsBytesSync();
    final base64Content = base64Encode(fileBytes);

    // 直接使用 fileName（已包含 img/ 或 video/ 路径）
    final url = 'https://api.github.com/repos/${config.owner}/${config.repo}/contents/$fileName';

    print('API URL: $url');

    // 构建请求体
    final body = jsonEncode({
      'message': 'Upload image: $fileName',
      'content': base64Content,
      'branch': config.branch,
    });

    // 发送请求
    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Authorization': 'token ${config.token}',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      final downloadUrl = responseData['content']['download_url'] as String;
      print('✓ GitHub 上传成功: $downloadUrl');
      print('---------- GitHub 图床上传完成 ----------');
      return downloadUrl;
    } else {
      final error = 'GitHub 上传失败 (${response.statusCode}): ${response.body}';
      print('!!! $error');
      print('---------- GitHub 图床上传失败 ----------');
      throw Exception(error);
    }
  }
}
