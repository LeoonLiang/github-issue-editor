import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// 版本更新服务
class VersionService {
  static const String githubRepo = 'LeoonLiang/github-issue-editor';

  /// 检查是否有新版本
  /// 返回: {hasUpdate: bool, latestVersion: string, downloadUrl: string, releaseNotes: string}
  Future<Map<String, dynamic>> checkForUpdate(String currentVersion) async {
    try {
      // 从GitHub Releases API获取最新版本
      final url = 'https://api.github.com/repos/$githubRepo/releases/latest';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch latest release');
      }

      final data = json.decode(response.body);
      final latestVersion = data['tag_name'] as String;
      final releaseNotes = data['body'] as String? ?? '';

      // 获取APK下载链接
      String? downloadUrl;
      final assets = data['assets'] as List<dynamic>?;
      if (assets != null && assets.isNotEmpty) {
        for (var asset in assets) {
          final name = asset['name'] as String;
          if (name.endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'] as String;
            break;
          }
        }
      }

      // 比较版本号
      final hasUpdate = _compareVersions(currentVersion, latestVersion);

      return {
        'hasUpdate': hasUpdate,
        'latestVersion': latestVersion,
        'downloadUrl': downloadUrl ?? 'https://github.com/$githubRepo/releases/latest',
        'releaseNotes': releaseNotes,
      };
    } catch (e) {
      print('Error checking for update: $e');
      // 返回错误信息，而不是假装没有更新
      return {
        'hasUpdate': false,
        'hasError': true,
        'errorMessage': e.toString(),
        'latestVersion': currentVersion,
        'downloadUrl': 'https://github.com/$githubRepo/releases/latest',
        'releaseNotes': '',
      };
    }
  }

  /// 比较版本号
  /// 如果latestVersion > currentVersion，返回true
  bool _compareVersions(String current, String latest) {
    // 移除可能的 'v' 前缀
    current = current.replaceFirst('v', '');
    latest = latest.replaceFirst('v', '');

    final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // 补齐长度
    while (currentParts.length < 3) currentParts.add(0);
    while (latestParts.length < 3) latestParts.add(0);

    // 逐位比较
    for (int i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) {
        return true;
      } else if (latestParts[i] < currentParts[i]) {
        return false;
      }
    }

    return false;
  }

  /// 生成加速下载链接
  static String getAcceleratedUrl(String originalUrl) {
    return 'https://down.npee.cn/?$originalUrl';
  }

  /// 下载 APK 文件（带进度回调）
  /// 返回下载后的本地文件路径
  Future<String> downloadApk(
    String url,
    void Function(int received, int total) onProgress,
  ) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('下载失败 (${response.statusCode})');
      }

      final total = response.contentLength ?? -1;
      int received = 0;

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/update.apk';
      final file = File(filePath);
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }

      await sink.close();
      return filePath;
    } finally {
      client.close();
    }
  }
}
