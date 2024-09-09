import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GitHubService {
  final String token = 'YOUR_GITHUB_TOKEN_HERE';
  final String owner = 'LeoonLiang';
  final String picRepo = 'pic';
  final String issueRepo = 'vercel-nuxt-blog';

  Future<String> uploadImageToGitHub(String filePath, String fileName) async {
    final fileContent = base64Encode(await File(filePath).readAsBytes());
    final url =
        'https://api.github.com/repos/$owner/$picRepo/contents/$fileName';

    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Authorization': 'token $token',
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

  Future<void> createGitHubIssue(String title, String body, String selectedLabel) async {
    final url = 'https://api.github.com/repos/$owner/$issueRepo/issues';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'token $token',
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
  }

  Future<List<String>> fetchGitHubLabels() async {
    final url = 'https://api.github.com/repos/$owner/$issueRepo/labels';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'token $token',
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
