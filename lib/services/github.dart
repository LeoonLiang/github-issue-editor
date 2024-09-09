import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GitHubService {
  final String token = 'YOUR_GITHUB_TOKEN_HERE';
  final String owner = 'LeoonLiang';
  final String picRepo = 'pic';
  final String issueRepo = 'vercel-nuxt-blog';

  Future<void> uploadImageToGitHub(String filePath, String fileName) async {
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
  }

  Future<void> createGitHubIssue(String title, String body) async {
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
        'label': ['notes'],
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to create issue: ${response.body}');
    }
  }
}
