import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/app_config.dart';

/// GitHub Issue 数据模型
class GitHubIssue {
  final int number;
  final String title;
  final String body;
  final String state;
  final List<String> labels;
  final String createdAt;
  final String? updatedAt;
  final String htmlUrl;

  GitHubIssue({
    required this.number,
    required this.title,
    required this.body,
    required this.state,
    required this.labels,
    required this.createdAt,
    this.updatedAt,
    required this.htmlUrl,
  });

  factory GitHubIssue.fromJson(Map<String, dynamic> json) {
    final labelsList = (json['labels'] as List<dynamic>)
        .map((label) => label['name'] as String)
        .toList();

    return GitHubIssue(
      number: json['number'],
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      state: json['state'] ?? 'open',
      labels: labelsList,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'],
      htmlUrl: json['html_url'] ?? '',
    );
  }
}

class GitHubService {
  final GitHubConfig config;

  GitHubService(this.config);

  Future<String> uploadImageToGitHub(String filePath, String fileName) async {
    final fileContent = base64Encode(await File(filePath).readAsBytes());
    final url =
        'https://api.github.com/repos/${config.owner}/${config.repo}/contents/$fileName';

    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Authorization': 'token ${config.token}',
        'Accept': 'application/vnd.github.v3+json',
      },
      body: json.encode({
        'message': 'Upload $fileName via Flutter',
        'content': fileContent,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to upload image: ${response.body}');
    }
    // 解析响应 JSON 获取图片的下载 URL
    final jsonResponse = json.decode(response.body);
    final downloadUrl = jsonResponse['content']['download_url'] as String;
    print(jsonResponse);
    print(downloadUrl);
    return downloadUrl;
  }

  /// 创建 Issue
  Future<GitHubIssue> createGitHubIssue(String title, String body, String selectedLabel) async {
    final url = 'https://api.github.com/repos/${config.owner}/${config.repo}/issues';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'token ${config.token}',
        'Accept': 'application/vnd.github.v3+json',
      },
      body: json.encode({
        'title': title,
        'body': body,
        'labels': [selectedLabel],
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to create issue: ${response.body}');
    }

    return GitHubIssue.fromJson(json.decode(response.body));
  }

  /// 获取 Issues 列表
  Future<List<GitHubIssue>> fetchGitHubIssues({
    String? label,
    String state = 'open',
    int page = 1,
    int perPage = 30,
  }) async {
    var url = 'https://api.github.com/repos/${config.owner}/${config.repo}/issues?state=$state&page=$page&per_page=$perPage';

    if (label != null && label != 'all') {
      url += '&labels=$label';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'token ${config.token}',
        'Accept': 'application/vnd.github.v3+json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch issues: ${response.body}');
    }

    final List<dynamic> issuesJson = json.decode(response.body);
    return issuesJson.map((json) => GitHubIssue.fromJson(json)).toList();
  }

  /// 获取单个 Issue
  Future<GitHubIssue> fetchGitHubIssue(int issueNumber) async {
    final url = 'https://api.github.com/repos/${config.owner}/${config.repo}/issues/$issueNumber';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'token ${config.token}',
        'Accept': 'application/vnd.github.v3+json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch issue: ${response.body}');
    }

    return GitHubIssue.fromJson(json.decode(response.body));
  }

  /// 更新 Issue
  Future<GitHubIssue> updateGitHubIssue(
    int issueNumber,
    String title,
    String body,
    List<String> labels,
  ) async {
    final url = 'https://api.github.com/repos/${config.owner}/${config.repo}/issues/$issueNumber';

    final response = await http.patch(
      Uri.parse(url),
      headers: {
        'Authorization': 'token ${config.token}',
        'Accept': 'application/vnd.github.v3+json',
      },
      body: json.encode({
        'title': title,
        'body': body,
        'labels': labels,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update issue: ${response.body}');
    }

    return GitHubIssue.fromJson(json.decode(response.body));
  }

  /// 关闭 Issue
  Future<void> closeGitHubIssue(int issueNumber) async {
    final url = 'https://api.github.com/repos/${config.owner}/${config.repo}/issues/$issueNumber';

    final response = await http.patch(
      Uri.parse(url),
      headers: {
        'Authorization': 'token ${config.token}',
        'Accept': 'application/vnd.github.v3+json',
      },
      body: json.encode({
        'state': 'closed',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to close issue: ${response.body}');
    }
  }

  /// 获取标签列表
  Future<List<String>> fetchGitHubLabels() async {
    final url = 'https://api.github.com/repos/${config.owner}/${config.repo}/labels';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'token ${config.token}',
        'Accept': 'application/vnd.github.v3+json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch labels: ${response.body}');
    }

    final List<dynamic> labels = json.decode(response.body);
    return labels.map((label) => label['name'] as String).toList();
  }
}
